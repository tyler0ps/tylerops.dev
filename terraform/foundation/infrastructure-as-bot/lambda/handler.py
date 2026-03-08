import json
import os
import boto3  # type: ignore
import urllib.request
import urllib.parse
from datetime import datetime, timezone, timedelta

WEBHOOK_SECRET = os.environ["WEBHOOK_SECRET"]
BOT_TOKEN_SSM_PATH = os.environ["BOT_TOKEN_SSM_PATH"]
AUTHENTIK_ASG = os.environ["AUTHENTIK_ASG_NAME"]
NAT_ASG = os.environ["NAT_ASG_NAME"]
CADDY_ASG = os.environ["CADDY_ASG_NAME"]
ATLANTIS_ASG = os.environ["ATLANTIS_ASG_NAME"]
PLANE_ASG = os.environ["PLANE_ASG_NAME"]
ALLOWED_CHAT_ID = os.environ["ALLOWED_CHAT_ID"]

_ssm = boto3.client("ssm")
_asg = boto3.client("autoscaling")
_ec2 = boto3.client("ec2")
_token_cache: dict = {}

ICT = timezone(timedelta(hours=7))

HELP_TEXT = """🏗 Infrastructure Manager

🔐 Authentik (auth.tylerops.dev)
  /authentik_up      — start instance
  /authentik_down    — stop instance
  /authentik_refresh — replace instance

🌐 NAT Instance (private subnet egress)
  /nat_up      — enable internet for private subnets
  /nat_down    — disable NAT
  /nat_refresh — replace NAT instance

🔀 Caddy (reverse proxy)
  /caddy_up      — start Caddy
  /caddy_down    — stop Caddy
  /caddy_refresh — replace Caddy instance

🤖 Atlantis (CI/CD)
  /atlantis_up      — start Atlantis
  /atlantis_down    — stop Atlantis
  /atlantis_refresh — replace Atlantis instance

✈️ Plane (capitalplace.tylerops.dev)
  /plane_up      — start Plane
  /plane_down    — stop Plane
  /plane_refresh — replace Plane instance

🌍 All Services
  /all_up   — start all services
  /all_down — stop all services

📊 Overview
  /status — current state of all services

⏰ Scheduled: scale-down 22:00 ICT | scale-up 06:00 ICT"""

HELP_KEYBOARD = {
    "inline_keyboard": [
        [
            {"text": "🔐 Authentik ⬆️", "callback_data": "authentik_up"},
            {"text": "🔐 Authentik ⬇️", "callback_data": "authentik_down"},
            {"text": "🔐 🔄", "callback_data": "authentik_refresh"},
        ],
        [
            {"text": "🌐 NAT ⬆️", "callback_data": "nat_up"},
            {"text": "🌐 NAT ⬇️", "callback_data": "nat_down"},
            {"text": "🌐 🔄", "callback_data": "nat_refresh"},
        ],
        [
            {"text": "🔀 Caddy ⬆️", "callback_data": "caddy_up"},
            {"text": "🔀 Caddy ⬇️", "callback_data": "caddy_down"},
            {"text": "🔀 🔄", "callback_data": "caddy_refresh"},
        ],
        [
            {"text": "🤖 Atlantis ⬆️", "callback_data": "atlantis_up"},
            {"text": "🤖 Atlantis ⬇️", "callback_data": "atlantis_down"},
            {"text": "🤖 🔄", "callback_data": "atlantis_refresh"},
        ],
        [
            {"text": "✈️ Plane ⬆️", "callback_data": "plane_up"},
            {"text": "✈️ Plane ⬇️", "callback_data": "plane_down"},
            {"text": "✈️ 🔄", "callback_data": "plane_refresh"},
        ],
        [
            {"text": "🟢 All ON", "callback_data": "all_up"},
            {"text": "🔴 All OFF", "callback_data": "all_down"},
        ],
        [{"text": "📊 Status", "callback_data": "status"}],
    ]
}

_ASG_ORDER = [AUTHENTIK_ASG, NAT_ASG, CADDY_ASG, ATLANTIS_ASG, PLANE_ASG]
_ASG_SHORT = {
    AUTHENTIK_ASG: "🔐 Authentik",
    NAT_ASG: "🌐 NAT",
    CADDY_ASG: "🔀 Caddy",
    ATLANTIS_ASG: "🤖 Atlantis",
    PLANE_ASG: "✈️ Plane",
}
_ASG_CMD = {
    AUTHENTIK_ASG: "authentik",
    NAT_ASG: "nat",
    CADDY_ASG: "caddy",
    ATLANTIS_ASG: "atlantis",
    PLANE_ASG: "plane",
}


def get_bot_token() -> str:
    if "token" not in _token_cache:
        resp = _ssm.get_parameter(Name=BOT_TOKEN_SSM_PATH, WithDecryption=True)
        _token_cache["token"] = resp["Parameter"]["Value"]
    return _token_cache["token"]


def send_message(chat_id: str, text: str, reply_markup: dict | None = None) -> None:
    url = f"https://api.telegram.org/bot{get_bot_token()}/sendMessage"
    payload: dict = {"chat_id": chat_id, "text": text}
    if reply_markup:
        payload["reply_markup"] = json.dumps(reply_markup)
    data = urllib.parse.urlencode(payload).encode()
    req = urllib.request.Request(url, data=data, method="POST")
    with urllib.request.urlopen(req, timeout=8):
        pass


def answer_callback_query(callback_query_id: str) -> None:
    url = f"https://api.telegram.org/bot{get_bot_token()}/answerCallbackQuery"
    data = urllib.parse.urlencode({"callback_query_id": callback_query_id}).encode()
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


def refresh(asg_name: str) -> None:
    """Trigger an instance refresh (rolling replacement) on the ASG."""
    _asg.start_instance_refresh(
        AutoScalingGroupName=asg_name,
        Strategy="Rolling",
        Preferences={"MinHealthyPercentage": 0},
    )


def _format_uptime(launch_time: datetime) -> str:
    delta = datetime.now(tz=timezone.utc) - launch_time
    h, rem = divmod(int(delta.total_seconds()), 3600)
    m = rem // 60
    if h:
        return f"{h}h {m}m"
    return f"{m}m"


def get_status() -> tuple[str, dict]:
    resp = _asg.describe_auto_scaling_groups(
        AutoScalingGroupNames=[AUTHENTIK_ASG, NAT_ASG, CADDY_ASG, ATLANTIS_ASG, PLANE_ASG]
    )
    labels = {
        AUTHENTIK_ASG: "🔐 Authentik (auth.tylerops.dev)",
        NAT_ASG: "🌐 NAT (private subnet egress)",
        CADDY_ASG: "🔀 Caddy (reverse proxy)",
        ATLANTIS_ASG: "🤖 Atlantis (CI/CD)",
        PLANE_ASG: "✈️ Plane (capitalplace.tylerops.dev)",
    }

    all_instance_ids = [
        i["InstanceId"]
        for g in resp["AutoScalingGroups"]
        for i in g["Instances"]
        if i["LifecycleState"] == "InService"
    ]

    ec2_info: dict[str, dict] = {}
    if all_instance_ids:
        ec2_resp = _ec2.describe_instances(InstanceIds=all_instance_ids)
        for reservation in ec2_resp["Reservations"]:
            for inst in reservation["Instances"]:
                ec2_info[inst["InstanceId"]] = inst

    lines = ["📊 Service Status\n"]
    group_states: dict[str, str] = {}

    for group in resp["AutoScalingGroups"]:
        name = group["AutoScalingGroupName"]
        desired = group["DesiredCapacity"]
        in_service = [i for i in group["Instances"] if i["LifecycleState"] == "InService"]
        running = len(in_service)

        if desired == 0:
            state = "stopped"
            state_icon = "🔴 stopped"
        elif running == desired:
            state = "running"
            state_icon = "🟢 running"
        else:
            state = "starting"
            state_icon = f"🟡 starting ({running}/{desired} ready)"

        group_states[name] = state
        label = labels.get(name, name)
        block = f"{label}\n  {state_icon}"

        if in_service:
            inst_id = in_service[0]["InstanceId"]
            instance_type = in_service[0].get("InstanceType", "?")
            ec2 = ec2_info.get(inst_id, {})
            launch_time = ec2.get("LaunchTime")
            if launch_time:
                launched_ict = launch_time.astimezone(ICT).strftime("%m-%d %H:%M ICT")
                block += f"\n  {instance_type} · up {_format_uptime(launch_time)} (since {launched_ict})"

        lines.append(block)

    # Build dynamic keyboard: stopped → show ⬆️, running/starting → show ⬇️ + 🔄
    keyboard_rows = []
    for asg in _ASG_ORDER:
        short = _ASG_SHORT[asg]
        cmd = _ASG_CMD[asg]
        state = group_states.get(asg, "unknown")
        if state == "stopped":
            keyboard_rows.append([{"text": f"{short} ⬆️ Start", "callback_data": f"{cmd}_up"}])
        else:
            keyboard_rows.append([
                {"text": f"{short} ⬇️ Stop", "callback_data": f"{cmd}_down"},
                {"text": "🔄 Refresh", "callback_data": f"{cmd}_refresh"},
            ])

    keyboard_rows.append([
        {"text": "🟢 All ON", "callback_data": "all_up"},
        {"text": "🔴 All OFF", "callback_data": "all_down"},
    ])
    keyboard_rows.append([{"text": "📊 Refresh Status", "callback_data": "status"}])

    return "\n\n".join(lines), {"inline_keyboard": keyboard_rows}


def _up_keyboard(cmd_prefix: str, label: str) -> dict:
    return {"inline_keyboard": [[{"text": f"⬇️ Stop {label}", "callback_data": f"{cmd_prefix}_down"}]]}


def _down_keyboard(cmd_prefix: str, label: str) -> dict:
    return {"inline_keyboard": [[{"text": f"⬆️ Start {label}", "callback_data": f"{cmd_prefix}_up"}]]}


def process_command(chat_id: str, cmd: str) -> None:
    # --- Authentik ---
    if cmd == "authentik_up":
        changed = scale(AUTHENTIK_ASG, 1)
        msg = "🔐 Authentik: starting...\nReady in ~1-2 min at auth.tylerops.dev" if changed else "🔐 Authentik: already running"
        send_message(chat_id, msg, _up_keyboard("authentik", "Authentik"))
    elif cmd == "authentik_down":
        changed = scale(AUTHENTIK_ASG, 0)
        msg = "🔐 Authentik: stopping...\nauth.tylerops.dev will be unavailable" if changed else "🔐 Authentik: already stopped"
        send_message(chat_id, msg, _down_keyboard("authentik", "Authentik"))
    elif cmd == "authentik_refresh":
        refresh(AUTHENTIK_ASG)
        send_message(chat_id, "🔐 Authentik: replacing instance...\nNew instance will be ready in ~2 min", _up_keyboard("authentik", "Authentik"))

    # --- NAT ---
    elif cmd == "nat_up":
        changed = scale(NAT_ASG, 1)
        msg = "🌐 NAT: starting...\nPrivate subnet egress available in ~1 min" if changed else "🌐 NAT: already running"
        send_message(chat_id, msg, _up_keyboard("nat", "NAT"))
    elif cmd == "nat_down":
        changed = scale(NAT_ASG, 0)
        msg = "🌐 NAT: stopping...\nPrivate subnet internet access disabled" if changed else "🌐 NAT: already stopped"
        send_message(chat_id, msg, _down_keyboard("nat", "NAT"))
    elif cmd == "nat_refresh":
        refresh(NAT_ASG)
        send_message(chat_id, "🌐 NAT: replacing instance...", _up_keyboard("nat", "NAT"))

    # --- Caddy ---
    elif cmd == "caddy_up":
        changed = scale(CADDY_ASG, 1)
        msg = "🔀 Caddy: starting...\nProxy available in ~1 min" if changed else "🔀 Caddy: already running"
        send_message(chat_id, msg, _up_keyboard("caddy", "Caddy"))
    elif cmd == "caddy_down":
        changed = scale(CADDY_ASG, 0)
        msg = "🔀 Caddy: stopping...\nAll proxied domains will be unreachable" if changed else "🔀 Caddy: already stopped"
        send_message(chat_id, msg, _down_keyboard("caddy", "Caddy"))
    elif cmd == "caddy_refresh":
        refresh(CADDY_ASG)
        send_message(chat_id, "🔀 Caddy: replacing instance...", _up_keyboard("caddy", "Caddy"))

    # --- Atlantis ---
    elif cmd == "atlantis_up":
        changed = scale(ATLANTIS_ASG, 1)
        msg = "🤖 Atlantis: starting...\nReady in ~1-2 min" if changed else "🤖 Atlantis: already running"
        send_message(chat_id, msg, _up_keyboard("atlantis", "Atlantis"))
    elif cmd == "atlantis_down":
        changed = scale(ATLANTIS_ASG, 0)
        msg = "🤖 Atlantis: stopping..." if changed else "🤖 Atlantis: already stopped"
        send_message(chat_id, msg, _down_keyboard("atlantis", "Atlantis"))
    elif cmd == "atlantis_refresh":
        refresh(ATLANTIS_ASG)
        send_message(chat_id, "🤖 Atlantis: replacing instance...", _up_keyboard("atlantis", "Atlantis"))

    # --- Plane ---
    elif cmd == "plane_up":
        changed = scale(PLANE_ASG, 1)
        msg = "✈️ Plane: starting...\nReady in ~2-3 min at capitalplace.tylerops.dev" if changed else "✈️ Plane: already running"
        send_message(chat_id, msg, _up_keyboard("plane", "Plane"))
    elif cmd == "plane_down":
        changed = scale(PLANE_ASG, 0)
        msg = "✈️ Plane: stopping...\ncapitalplace.tylerops.dev will be unavailable" if changed else "✈️ Plane: already stopped"
        send_message(chat_id, msg, _down_keyboard("plane", "Plane"))
    elif cmd == "plane_refresh":
        refresh(PLANE_ASG)
        send_message(chat_id, "✈️ Plane: replacing instance...\nReady in ~2-3 min", _up_keyboard("plane", "Plane"))

    # --- All ON / All OFF ---
    elif cmd == "all_up":
        asgs = [AUTHENTIK_ASG, NAT_ASG, CADDY_ASG, ATLANTIS_ASG, PLANE_ASG]
        started = [_ASG_SHORT[a] for a in asgs if scale(a, 1)]
        if started:
            send_message(chat_id, "🟢 Starting all services:\n" + "\n".join(f"  {s}" for s in started))
        else:
            send_message(chat_id, "🟢 All services already running")
    elif cmd == "all_down":
        asgs = [AUTHENTIK_ASG, NAT_ASG, CADDY_ASG, ATLANTIS_ASG, PLANE_ASG]
        stopped = [_ASG_SHORT[a] for a in asgs if scale(a, 0)]
        if stopped:
            send_message(chat_id, "🔴 Stopping all services:\n" + "\n".join(f"  {s}" for s in stopped))
        else:
            send_message(chat_id, "🔴 All services already stopped")

    # --- Status / Help ---
    elif cmd == "status":
        text, keyboard = get_status()
        send_message(chat_id, text, keyboard)
    elif cmd in ("help", "start"):
        send_message(chat_id, HELP_TEXT, HELP_KEYBOARD)
    else:
        send_message(chat_id, f"❓ Unknown command.\n\n{HELP_TEXT}", HELP_KEYBOARD)


def handler(event, _context):
    headers = {k.lower(): v for k, v in event.get("headers", {}).items()}
    if headers.get("x-telegram-bot-api-secret-token") != WEBHOOK_SECRET:
        return {"statusCode": 403, "body": "Forbidden"}

    body = json.loads(event.get("body") or "{}")

    # Handle inline keyboard button presses
    callback_query = body.get("callback_query")
    if callback_query:
        chat_id = str(callback_query.get("message", {}).get("chat", {}).get("id", ""))
        callback_query_id = callback_query.get("id", "")
        cmd = (callback_query.get("data") or "").strip().lower()
        if chat_id == ALLOWED_CHAT_ID and cmd:
            try:
                answer_callback_query(callback_query_id)
                process_command(chat_id, cmd)
            except Exception as e:
                send_message(chat_id, f"❌ Error: {e}")
        return {"statusCode": 200, "body": "ok"}

    # Handle regular text messages
    message = body.get("message") or body.get("edited_message") or {}
    if not message:
        return {"statusCode": 200, "body": "ok"}

    chat_id = str(message.get("chat", {}).get("id", ""))
    text = (message.get("text") or "").strip()

    if chat_id != ALLOWED_CHAT_ID or not text:
        return {"statusCode": 200, "body": "ok"}

    try:
        cmd = text.lower().strip().lstrip("/").split("@")[0].replace(" ", "_")
        process_command(chat_id, cmd)
    except Exception as e:
        send_message(chat_id, f"❌ Error: {e}")

    return {"statusCode": 200, "body": "ok"}
