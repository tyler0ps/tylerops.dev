"""
Plane Graceful Shutdown Lambda

Handles ASG lifecycle hook termination events:
- Gracefully stops Plane services via SSM
- Completes ASG lifecycle action
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
ssm = boto3.client("ssm")
autoscaling = boto3.client("autoscaling")

# Environment variables
ASG_NAME = os.environ.get("ASG_NAME")

# Constants
GRACEFUL_SHUTDOWN_TIMEOUT = 30  # seconds


def graceful_shutdown(instance_id):
    """Execute graceful shutdown via SSM (stop Plane services)."""
    logger.info(f"Executing graceful shutdown on {instance_id}")

    try:
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

        # Wait for shutdown to complete
        time.sleep(GRACEFUL_SHUTDOWN_TIMEOUT)
        logger.info("Graceful shutdown completed")
        return True

    except ClientError as e:
        logger.warning(f"SSM command failed (continuing anyway): {e}")
        return False


def complete_lifecycle_action(lifecycle_hook_name, asg_name, instance_id, lifecycle_action_token, action_result="CONTINUE"):
    """Complete ASG lifecycle action to allow termination to proceed."""
    logger.info(f"Completing lifecycle action for {instance_id} with result: {action_result}")

    try:
        autoscaling.complete_lifecycle_action(
            LifecycleHookName=lifecycle_hook_name,
            AutoScalingGroupName=asg_name,
            InstanceId=instance_id,
            LifecycleActionToken=lifecycle_action_token,
            LifecycleActionResult=action_result,
        )
        logger.info(f"Lifecycle action completed: {action_result}")
        return True

    except ClientError as e:
        logger.error(f"Error completing lifecycle action: {e}")
        return False


def lambda_handler(event, context):
    """Main Lambda handler - processes ASG lifecycle hook termination events."""
    logger.info(f"Received event: {json.dumps(event)}")

    detail = event.get("detail", {})
    instance_id = detail.get("EC2InstanceId")
    lifecycle_hook_name = detail.get("LifecycleHookName")
    asg_name = detail.get("AutoScalingGroupName")
    lifecycle_action_token = detail.get("LifecycleActionToken")

    if not all([instance_id, lifecycle_hook_name, asg_name, lifecycle_action_token]):
        logger.error(f"Missing required fields in event detail: {detail}")
        return {"error": "Missing required lifecycle hook fields"}

    logger.info(f"Processing termination for instance {instance_id} in ASG {asg_name}")

    # Graceful shutdown
    graceful_shutdown(instance_id)

    # Complete lifecycle action to allow termination
    complete_lifecycle_action(
        lifecycle_hook_name=lifecycle_hook_name,
        asg_name=asg_name,
        instance_id=instance_id,
        lifecycle_action_token=lifecycle_action_token,
        action_result="CONTINUE",
    )

    return {
        "action": "lifecycle_terminating",
        "result": "completed",
        "instance_id": instance_id,
    }
