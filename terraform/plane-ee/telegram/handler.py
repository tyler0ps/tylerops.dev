"""
Telegram Bot for Plane EE ASG Control

Commands:
  /up      - Scale ASG to 1 (start instance)
  /down    - Scale ASG to 0 (stop instance)
  /status  - Show current ASG state
  /ip      - Show Elastic IP address
  /refresh - Trigger instance refresh (redeploy)
  /logs    - Show recent bot logs
  /help    - List all commands
"""

import hmac
import json
import logging
import os
import urllib.request

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

autoscaling = boto3.client("autoscaling")
ssm = boto3.client("ssm")
logs = boto3.client("logs")

ASG_NAME = os.environ["ASG_NAME"]
SSM_BOT_TOKEN_PARAM = os.environ["SSM_BOT_TOKEN_PARAM"]
SSM_CHAT_ID_PARAM = os.environ["SSM_CHAT_ID_PARAM"]
SSM_WEBHOOK_SECRET_PARAM = os.environ["SSM_WEBHOOK_SECRET_PARAM"]
EIP_ADDRESS = os.environ["EIP_ADDRESS"]
LAMBDA_LOG_GROUP = os.environ["LAMBDA_LOG_GROUP"]

# Cached values (persist across warm invocations)
_bot_token = None
_allowed_chat_id = None
_webhook_secret = None


def get_bot_token():
    global _bot_token
    if not _bot_token:
        resp = ssm.get_parameter(Name=SSM_BOT_TOKEN_PARAM, WithDecryption=True)
        _bot_token = resp["Parameter"]["Value"]
    return _bot_token


def get_allowed_chat_id():
    global _allowed_chat_id
    if not _allowed_chat_id:
        resp = ssm.get_parameter(Name=SSM_CHAT_ID_PARAM)
        _allowed_chat_id = resp["Parameter"]["Value"]
    return _allowed_chat_id


def get_webhook_secret():
    global _webhook_secret
    if not _webhook_secret:
        resp = ssm.get_parameter(Name=SSM_WEBHOOK_SECRET_PARAM, WithDecryption=True)
        _webhook_secret = resp["Parameter"]["Value"]
    return _webhook_secret


def send_message(chat_id, text):
    token = get_bot_token()
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    payload = json.dumps({"chat_id": chat_id, "text": text, "parse_mode": "Markdown"}).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        logger.error(f"Failed to send message: {e}")


def handle_up(chat_id):
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=1,
    )
    send_message(chat_id, "⬆️ Scaling up to 1 instance...")


def handle_down(chat_id):
    autoscaling.set_desired_capacity(
        AutoScalingGroupName=ASG_NAME,
        DesiredCapacity=0,
    )
    send_message(chat_id, "⬇️ Scaling down to 0...")


def handle_status(chat_id):
    resp = autoscaling.describe_auto_scaling_groups(AutoScalingGroupNames=[ASG_NAME])
    asg = resp["AutoScalingGroups"][0]
    desired = asg["DesiredCapacity"]
    instances = asg.get("Instances", [])

    if instances:
        inst = instances[0]
        text = (
            f"*Plane EE ASG Status*\n"
            f"Desired: {desired}\n"
            f"Instance: `{inst['InstanceId']}`\n"
            f"State: {inst['LifecycleState']}\n"
            f"Health: {inst['HealthStatus']}\n"
            f"Type: {inst['InstanceType']}"
        )
    else:
        text = f"*Plane EE ASG Status*\nDesired: {desired}\nInstances: none"

    send_message(chat_id, text)


def handle_ip(chat_id):
    send_message(chat_id, f"🌐 Elastic IP: `{EIP_ADDRESS}`")


def handle_refresh(chat_id):
    autoscaling.start_instance_refresh(
        AutoScalingGroupName=ASG_NAME,
        Preferences={"MinHealthyPercentage": 0},
    )
    send_message(chat_id, "🔄 Instance refresh started (redeploy with latest AMI)...")


def handle_logs(chat_id):
    streams = logs.describe_log_streams(
        logGroupName=LAMBDA_LOG_GROUP,
        orderBy="LastEventTime",
        descending=True,
        limit=1,
    )
    if not streams.get("logStreams"):
        send_message(chat_id, "📋 No logs found")
        return

    stream_name = streams["logStreams"][0]["logStreamName"]
    events = logs.get_log_events(
        logGroupName=LAMBDA_LOG_GROUP,
        logStreamName=stream_name,
        limit=10,
        startFromHead=False,
    )

    lines = []
    for e in events.get("events", []):
        msg = e["message"].strip()
        if msg:
            lines.append(msg[:200])

    text = "\n".join(lines[-10:]) if lines else "No recent events"
    send_message(chat_id, f"📋 *Recent bot logs:*\n```\n{text}\n```")


def handle_help(chat_id):
    text = (
        "*Plane EE Bot Commands:*\n"
        "/up — Start instance (scale to 1)\n"
        "/down — Stop instance (scale to 0)\n"
        "/status — Show ASG state\n"
        "/ip — Show Elastic IP\n"
        "/refresh — Redeploy instance\n"
        "/logs — Recent bot logs\n"
        "/help — This message"
    )
    send_message(chat_id, text)


COMMANDS = {
    "/up": handle_up,
    "/down": handle_down,
    "/status": handle_status,
    "/ip": handle_ip,
    "/refresh": handle_refresh,
    "/logs": handle_logs,
    "/help": handle_help,
}


def lambda_handler(event, context):
    logger.info(f"Event: {json.dumps(event)}")

    # Verify Telegram secret token header
    headers = event.get("headers", {})
    incoming_secret = headers.get("x-telegram-bot-api-secret-token", "")
    if not hmac.compare_digest(incoming_secret, get_webhook_secret()):
        logger.warning("Invalid or missing webhook secret token")
        return {"statusCode": 403}

    try:
        body = json.loads(event.get("body", "{}"))
    except (json.JSONDecodeError, TypeError):
        return {"statusCode": 400}

    message = body.get("message", {})
    chat_id = str(message.get("chat", {}).get("id", ""))
    text = message.get("text", "").strip()

    if not chat_id or not text:
        return {"statusCode": 200}

    # Auth check
    if chat_id != get_allowed_chat_id():
        logger.warning(f"Unauthorized chat_id: {chat_id}")
        return {"statusCode": 403}

    # Strip bot username if present (e.g. /up@mybot)
    command = text.split("@")[0].lower()

    handler = COMMANDS.get(command)
    if handler:
        try:
            handler(chat_id)
        except ClientError as e:
            logger.error(f"AWS error: {e}")
            send_message(chat_id, f"❌ Error: {e}")
    else:
        send_message(chat_id, "Unknown command. Try /help")

    return {"statusCode": 200}
