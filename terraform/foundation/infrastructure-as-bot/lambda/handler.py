import json
import os
import boto3  # type: ignore
import urllib.request
import urllib.parse

WEBHOOK_SECRET = os.environ["WEBHOOK_SECRET"]
BOT_TOKEN_SSM_PATH = os.environ["BOT_TOKEN_SSM_PATH"]
AUTHENTIK_ASG = os.environ["AUTHENTIK_ASG_NAME"]
NAT_ASG = os.environ["NAT_ASG_NAME"]
ALLOWED_CHAT_ID = os.environ["ALLOWED_CHAT_ID"]

_ssm = boto3.client("ssm")
_asg = boto3.client("autoscaling")
_token_cache: dict = {}

HELP_TEXT = """Infrastructure Manager

Authentik (auth.tylerops.dev)
  /authentik_up   — start instance (t4g.small spot)
  /authentik_down — stop instance

NAT Instance (private subnet egress)
  /nat_up   — enable internet for private subnets
  /nat_down — disable NAT

Overview
  /status — current state of all services

Scheduled: scale-down 22:00 ICT | scale-up 06:00 ICT"""


def get_bot_token() -> str:
    if "token" not in _token_cache:
        resp = _ssm.get_parameter(Name=BOT_TOKEN_SSM_PATH, WithDecryption=True)
        _token_cache["token"] = resp["Parameter"]["Value"]
    return _token_cache["token"]


def send_message(chat_id: str, text: str) -> None:
    url = f"https://api.telegram.org/bot{get_bot_token()}/sendMessage"
    data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=8):
        pass


def scale(asg_name: str, desired: int) -> bool:
    """Scale ASG to desired capacity. Returns True if changed, False if already at desired."""
    resp = _asg.describe_auto_scaling_groups(AutoScalingGroupNames=[asg_name])
    current = resp["AutoScalingGroups"][0]["DesiredCapacity"]
    if current == desired:
        return False
    _asg.update_auto_scaling_group(
        AutoScalingGroupName=asg_name,
        MinSize=desired,
        DesiredCapacity=desired,
    )
    return True


def get_status() -> str:
    resp = _asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[AUTHENTIK_ASG, NAT_ASG]
    )
    labels = {
        AUTHENTIK_ASG: "Authentik (auth.tylerops.dev)",
        NAT_ASG: "NAT (private subnet egress)",
    }
    lines = ["Service Status\n"]
    for group in resp["AutoScalingGroups"]:
        name = group["AutoScalingGroupName"]
        desired = group["DesiredCapacity"]
        running = sum(
            1 for i in group["Instances"] if i["LifecycleState"] == "InService"
        )
        if desired == 0:
            state = "stopped"
        elif running == desired:
            state = "running"
        else:
            state = f"starting ({running}/{desired} ready)"
        label = labels.get(name, name)
        lines.append(f"{label}\n  desired={desired} | {state}")
    return "\n\n".join(lines)


def handler(event, _context):
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    if headers.get("x-telegram-bot-api-secret-token") != WEBHOOK_SECRET:
        return {"statusCode": 403, "body": "Forbidden"}

    body = json.loads(event.get("body") or "{}")
    message = body.get("message") or body.get("edited_message") or {}
    if not message:
        return {"statusCode": 200, "body": "ok"}

    chat_id = str(message.get("chat", {}).get("id", ""))
    text = (message.get("text") or "").strip()

    if chat_id != ALLOWED_CHAT_ID or not text:
        return {"statusCode": 200, "body": "ok"}

    try:
        # Normalize "/nat_down" and "/nat down" → "nat_down"
        cmd = text.lower().strip().lstrip("/").split("@")[0].replace(" ", "_")

        if cmd == "authentik_up":
            changed = scale(AUTHENTIK_ASG, 1)
            if changed:
                send_message(chat_id, "Authentik: starting...\nReady in ~1-2 min at auth.tylerops.dev")
            else:
                send_message(chat_id, "Authentik: already running")
        elif cmd == "authentik_down":
            changed = scale(AUTHENTIK_ASG, 0)
            if changed:
                send_message(chat_id, "Authentik: stopping...\nauth.tylerops.dev will be unavailable")
            else:
                send_message(chat_id, "Authentik: already stopped")
        elif cmd == "nat_up":
            changed = scale(NAT_ASG, 1)
            if changed:
                send_message(chat_id, "NAT: starting...\nPrivate subnet egress available in ~1 min")
            else:
                send_message(chat_id, "NAT: already running")
        elif cmd == "nat_down":
            changed = scale(NAT_ASG, 0)
            if changed:
                send_message(chat_id, "NAT: stopping...\nPrivate subnet internet access disabled")
            else:
                send_message(chat_id, "NAT: already stopped")
        elif cmd == "status":
            send_message(chat_id, get_status())
        elif cmd in ("help", "start"):
            send_message(chat_id, HELP_TEXT)
        else:
            send_message(chat_id, f"Unknown command.\n\n{HELP_TEXT}")

    except Exception as e:
        send_message(chat_id, f"Error: {e}")

    return {"statusCode": 200, "body": "ok"}
