"""
Plane Instance Manager Lambda

Manages Plane EC2 spot instance lifecycle:
- Schedule start/stop
- Spot interruption handling
- EBS volume attachment
- Elastic IP association
"""

import json
import logging
import os
import time

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
ec2 = boto3.client("ec2")
ssm = boto3.client("ssm")

# Environment variables (set by Terraform)
LAUNCH_TEMPLATE_ID = os.environ.get("LAUNCH_TEMPLATE_ID")
EBS_VOLUME_ID = os.environ.get("EBS_VOLUME_ID")
EIP_ALLOCATION_ID = os.environ.get("EIP_ALLOCATION_ID")
SUBNET_ID = os.environ.get("SUBNET_ID")

# Constants
MANAGED_BY_TAG = "plane-lambda"
INSTANCE_TAG_NAME = "plane"
GRACEFUL_SHUTDOWN_TIMEOUT = 30  # seconds


def get_managed_instance():
    """Find instance managed by this Lambda (by tag ManagedBy=plane-lambda)."""
    try:
        response = ec2.describe_instances(
            Filters=[
                {"Name": "tag:ManagedBy", "Values": [MANAGED_BY_TAG]},
                {
                    "Name": "instance-state-name",
                    "Values": ["pending", "running", "stopping", "stopped"],
                },
            ]
        )

        for reservation in response.get("Reservations", []):
            for instance in reservation.get("Instances", []):
                logger.info(
                    f"Found managed instance: {instance['InstanceId']} "
                    f"(state: {instance['State']['Name']})"
                )
                return instance

        logger.info("No managed instance found")
        return None

    except ClientError as e:
        logger.error(f"Error describing instances: {e}")
        raise


def wait_for_instance_state(instance_id, target_state, max_wait=300):
    """Wait for instance to reach target state."""
    logger.info(f"Waiting for instance {instance_id} to reach state: {target_state}")

    waiter_map = {
        "running": "instance_running",
        "stopped": "instance_stopped",
        "terminated": "instance_terminated",
    }

    if target_state in waiter_map:
        waiter = ec2.get_waiter(waiter_map[target_state])
        try:
            waiter.wait(
                InstanceIds=[instance_id],
                WaiterConfig={"Delay": 5, "MaxAttempts": max_wait // 5},
            )
            logger.info(f"Instance {instance_id} reached state: {target_state}")
            return True
        except Exception as e:
            logger.error(f"Timeout waiting for instance state: {e}")
            return False
    return False


def wait_for_volume_available(volume_id, max_wait=120):
    """Wait for EBS volume to be available (detached)."""
    logger.info(f"Waiting for volume {volume_id} to be available")

    for _ in range(max_wait // 5):
        try:
            response = ec2.describe_volumes(VolumeIds=[volume_id])
            state = response["Volumes"][0]["State"]
            if state == "available":
                logger.info(f"Volume {volume_id} is available")
                return True
            logger.info(f"Volume state: {state}, waiting...")
            time.sleep(5)
        except ClientError as e:
            logger.error(f"Error checking volume state: {e}")
            time.sleep(5)

    logger.error(f"Timeout waiting for volume {volume_id} to be available")
    return False


def graceful_shutdown(instance_id):
    """Execute graceful shutdown via SSM (stop Plane services)."""
    logger.info(f"Executing graceful shutdown on {instance_id}")

    try:
        # Send shutdown command via SSM
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={
                "commands": [
                    "cd /opt/plane-selfhost && echo '3' | ./setup.sh || true",
                    "sleep 10",
                ]
            },
            TimeoutSeconds=60,
        )
        command_id = response["Command"]["CommandId"]
        logger.info(f"SSM command sent: {command_id}")

        # Wait for command completion
        time.sleep(GRACEFUL_SHUTDOWN_TIMEOUT)
        logger.info("Graceful shutdown completed")
        return True

    except ClientError as e:
        # SSM might fail if instance is not reachable, continue anyway
        logger.warning(f"SSM command failed (continuing anyway): {e}")
        return False


def create_instance():
    """Create new spot instance from launch template."""
    logger.info("Creating new spot instance from launch template")

    try:
        response = ec2.run_instances(
            LaunchTemplate={"LaunchTemplateId": LAUNCH_TEMPLATE_ID},
            MinCount=1,
            MaxCount=1,
        )

        instance_id = response["Instances"][0]["InstanceId"]
        logger.info(f"Created instance: {instance_id}")

        # Wait for instance to be running
        if not wait_for_instance_state(instance_id, "running"):
            raise Exception(f"Instance {instance_id} failed to reach running state")

        # Attach EBS volume
        attach_ebs_volume(instance_id)

        # Associate Elastic IP
        associate_eip(instance_id)

        logger.info(f"Instance {instance_id} fully configured")
        return instance_id

    except ClientError as e:
        logger.error(f"Error creating instance: {e}")
        raise


def attach_ebs_volume(instance_id):
    """Attach EBS data volume to instance."""
    logger.info(f"Attaching volume {EBS_VOLUME_ID} to {instance_id}")

    # Wait for volume to be available if it was attached elsewhere
    if not wait_for_volume_available(EBS_VOLUME_ID):
        logger.warning("Volume not available, attempting attach anyway")

    try:
        ec2.attach_volume(
            Device="/dev/xvdf", InstanceId=instance_id, VolumeId=EBS_VOLUME_ID
        )
        logger.info(f"Volume {EBS_VOLUME_ID} attached to {instance_id}")

        # Wait for attachment
        time.sleep(10)
        return True

    except ClientError as e:
        if "already attached" in str(e).lower():
            logger.info("Volume already attached")
            return True
        logger.error(f"Error attaching volume: {e}")
        raise


def associate_eip(instance_id):
    """Associate Elastic IP with instance."""
    logger.info(f"Associating EIP {EIP_ALLOCATION_ID} to {instance_id}")

    try:
        ec2.associate_address(
            AllocationId=EIP_ALLOCATION_ID, InstanceId=instance_id, AllowReassociation=True
        )
        logger.info(f"EIP associated to {instance_id}")
        return True

    except ClientError as e:
        logger.error(f"Error associating EIP: {e}")
        raise


def terminate_instance(instance_id):
    """Terminate instance (graceful shutdown first)."""
    logger.info(f"Terminating instance: {instance_id}")

    # Graceful shutdown
    graceful_shutdown(instance_id)

    # Terminate
    try:
        ec2.terminate_instances(InstanceIds=[instance_id])
        logger.info(f"Instance {instance_id} termination initiated")

        # EBS will auto-detach, EIP will auto-disassociate
        return True

    except ClientError as e:
        logger.error(f"Error terminating instance: {e}")
        raise


def handle_schedule_start(event):
    """Handle scheduled start - create instance if none exists."""
    logger.info("Handling schedule_start event")

    instance = get_managed_instance()
    if instance:
        state = instance["State"]["Name"]
        if state in ["running", "pending"]:
            logger.info(f"Instance already running/pending: {instance['InstanceId']}")
            return {
                "action": "schedule_start",
                "result": "skipped",
                "reason": f"Instance {instance['InstanceId']} already {state}",
            }
        elif state == "stopped":
            # Start stopped instance
            instance_id = instance["InstanceId"]
            logger.info(f"Starting stopped instance: {instance_id}")
            ec2.start_instances(InstanceIds=[instance_id])
            wait_for_instance_state(instance_id, "running")
            return {
                "action": "schedule_start",
                "result": "started",
                "instance_id": instance_id,
            }

    # No instance, create new one
    instance_id = create_instance()
    return {
        "action": "schedule_start",
        "result": "created",
        "instance_id": instance_id,
    }


def handle_schedule_stop(event):
    """Handle scheduled stop - terminate instance if exists."""
    logger.info("Handling schedule_stop event")

    instance = get_managed_instance()
    if not instance:
        logger.info("No instance to stop")
        return {"action": "schedule_stop", "result": "skipped", "reason": "No instance found"}

    state = instance["State"]["Name"]
    if state in ["terminated", "shutting-down"]:
        logger.info(f"Instance already terminating: {instance['InstanceId']}")
        return {
            "action": "schedule_stop",
            "result": "skipped",
            "reason": f"Instance already {state}",
        }

    instance_id = instance["InstanceId"]
    terminate_instance(instance_id)
    return {"action": "schedule_stop", "result": "terminated", "instance_id": instance_id}


def handle_spot_interruption(event):
    """Handle spot interruption warning - graceful shutdown, then recreate."""
    logger.info("Handling spot_interruption event")
    logger.info(f"Event detail: {json.dumps(event.get('detail', {}))}")

    # Extract instance ID from event
    detail = event.get("detail", {})
    instance_id = detail.get("instance-id")

    if not instance_id:
        logger.error("No instance-id in spot interruption event")
        return {"action": "spot_interruption", "result": "error", "reason": "No instance ID"}

    # Verify this is our managed instance
    instance = get_managed_instance()
    if not instance or instance["InstanceId"] != instance_id:
        logger.info(f"Interrupted instance {instance_id} is not managed by us")
        return {
            "action": "spot_interruption",
            "result": "skipped",
            "reason": "Not our instance",
        }

    # Graceful shutdown (AWS will terminate in ~2 minutes)
    graceful_shutdown(instance_id)

    # Wait for instance to be terminated and volume to be available
    logger.info("Waiting for spot instance to be terminated by AWS...")
    wait_for_instance_state(instance_id, "terminated", max_wait=180)

    # Wait for EBS to be available
    wait_for_volume_available(EBS_VOLUME_ID)

    # Create new instance
    new_instance_id = create_instance()

    return {
        "action": "spot_interruption",
        "result": "recovered",
        "old_instance_id": instance_id,
        "new_instance_id": new_instance_id,
    }


def lambda_handler(event, context):
    """Main Lambda handler."""
    logger.info(f"Received event: {json.dumps(event)}")

    # Determine action from event
    action = None

    # Direct invocation with action parameter
    if "action" in event:
        action = event["action"]

    # EventBridge scheduled event
    elif "source" in event and event["source"] == "aws.events":
        rule_name = event.get("resources", [""])[0].split("/")[-1]
        if "start" in rule_name.lower():
            action = "schedule_start"
        elif "stop" in rule_name.lower():
            action = "schedule_stop"

    # EC2 Spot Interruption Warning
    elif event.get("source") == "aws.ec2" and event.get("detail-type") == "EC2 Spot Instance Interruption Warning":
        action = "spot_interruption"

    if not action:
        logger.error(f"Unknown event type: {event}")
        return {"error": "Unknown event type"}

    logger.info(f"Processing action: {action}")

    # Route to handler
    handlers = {
        "schedule_start": handle_schedule_start,
        "schedule_stop": handle_schedule_stop,
        "spot_interruption": handle_spot_interruption,
    }

    if action not in handlers:
        return {"error": f"Unknown action: {action}"}

    result = handlers[action](event)
    logger.info(f"Result: {json.dumps(result)}")
    return result
