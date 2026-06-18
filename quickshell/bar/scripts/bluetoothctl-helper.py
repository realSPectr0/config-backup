#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import traceback


MAC_RE = r"[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}"
ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def emit(data):
    print(json.dumps(data, ensure_ascii=False))


def scrub(text):
    return ANSI_RE.sub("", text or "").replace("\r", "")


def btctl(args, timeout=12, agent=False, cli_timeout=False):
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    command = ["bluetoothctl"]
    if agent:
        command.extend(["--agent", "KeyboardDisplay"])
    if cli_timeout and timeout:
        command.extend(["--timeout", str(timeout)])
    command.extend(args)

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout + 3 if timeout else 15,
            env=env,
        )
    except FileNotFoundError:
        return None
    except subprocess.TimeoutExpired as exc:
        class TimeoutResult:
            returncode = 124
            stdout = exc.stdout or ""
            stderr = "Timed out"

        return TimeoutResult()
    except Exception as exc:
        class ErrorResult:
            returncode = 1
            stdout = ""
            stderr = f"{type(exc).__name__}: {exc}"

        return ErrorResult()

    result.stdout = scrub(result.stdout)
    result.stderr = scrub(result.stderr)
    return result


def clean_output(result):
    if not result:
        return "bluetoothctl is not installed"

    lines = []
    for line in (result.stderr or result.stdout or "").splitlines():
        line = line.strip()
        if not line:
            continue
        if line in ["Agent registered", "Agent unregistered"]:
            continue
        if line.endswith("#"):
            continue
        lines.append(line)

    if lines:
        return "\n".join(lines)
    if result.returncode != 0:
        return f"bluetoothctl exited with code {result.returncode}"
    return ""


def parse_bool(value):
    return str(value).strip().lower() in ["yes", "true", "on"]


def parse_int(value):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return None


def parse_battery(value):
    if not value:
        return None
    match = re.search(r"\((\d+)\)", value)
    if match:
        return int(match.group(1))
    match = re.search(r"\b(\d{1,3})\b", value)
    return int(match.group(1)) if match else None


def parse_device_lines(text):
    devices = {}
    for line in scrub(text).splitlines():
        line = line.strip()
        match = re.search(
            rf"(?:\[[^\]]+\]\s+)?Device\s+({MAC_RE})(?:\s+\([^)]*\))?\s*(.*)$",
            line,
        )
        if not match:
            continue
        address = match.group(1).upper()
        name = match.group(2).strip() or address
        devices[address] = {"address": address, "name": name}
    return devices


def parse_properties(text):
    props = {}
    uuids = []
    for line in scrub(text).splitlines():
        line = line.strip()
        if line.startswith("UUID:"):
            uuids.append(line.split(":", 1)[1].strip())
            continue
        match = re.match(r"([^:]+):\s*(.*)$", line)
        if match:
            props[match.group(1).strip()] = match.group(2).strip()
    return props, uuids


def controller_info():
    result = btctl(["show"], timeout=8)
    if result is None:
        return {
            "available": False,
            "powered": False,
            "discovering": False,
            "discoverable": False,
            "pairable": False,
            "name": "",
            "address": "",
            "error": "bluetoothctl is not installed",
        }

    text = f"{result.stdout}\n{result.stderr}"
    ctrl_match = re.search(rf"Controller\s+({MAC_RE})(?:\s+\([^)]*\))?", text)
    props, _ = parse_properties(text)
    error = clean_output(result) if result.returncode != 0 else ""

    return {
        "available": ctrl_match is not None and result.returncode == 0,
        "powered": parse_bool(props.get("Powered")),
        "discovering": parse_bool(props.get("Discovering")),
        "discoverable": parse_bool(props.get("Discoverable")),
        "pairable": parse_bool(props.get("Pairable")),
        "name": props.get("Alias") or props.get("Name") or "",
        "address": ctrl_match.group(1).upper() if ctrl_match else "",
        "error": error,
    }


def icon_for(icon_name, name, uuids):
    haystack = " ".join([icon_name, name, *uuids]).lower()
    if any(word in haystack for word in ["headset", "headphones", "handsfree"]):
        return "󰋎"
    if any(word in haystack for word in ["audio", "speaker", "sink", "av remote"]):
        return "󰓃"
    if "keyboard" in haystack:
        return "󰌌"
    if "mouse" in haystack:
        return "󰍽"
    if any(word in haystack for word in ["phone", "smartphone"]):
        return "󰄜"
    if any(word in haystack for word in ["computer", "laptop"]):
        return "󰌢"
    if any(word in haystack for word in ["gamepad", "joystick", "controller"]):
        return "󰊴"
    return "󰂯"


def device_details(address, fallback):
    result = btctl(["info", address], timeout=8)
    props, uuids = parse_properties(result.stdout if result else "")

    name = (
        props.get("Alias")
        or props.get("Name")
        or fallback.get("name")
        or address
    )
    paired = parse_bool(props.get("Paired")) or fallback.get("paired", False)
    trusted = parse_bool(props.get("Trusted")) or fallback.get("trusted", False)
    connected = parse_bool(props.get("Connected")) or fallback.get("connected", False)
    blocked = parse_bool(props.get("Blocked"))
    rssi = parse_int(props.get("RSSI"))
    battery = parse_battery(props.get("Battery Percentage"))

    if blocked:
        status = "Blocked"
    elif connected:
        status = "Connected"
    elif paired:
        status = "Paired"
    elif trusted:
        status = "Trusted"
    else:
        status = "Available"

    detail_parts = [status]
    if battery is not None:
        detail_parts.append(f"{battery}%")
    if rssi is not None:
        detail_parts.append(f"RSSI {rssi}")
    if paired and trusted and status == "Paired":
        detail_parts.append("Trusted")

    return {
        "address": address,
        "name": name,
        "alias": props.get("Alias", ""),
        "icon": icon_for(props.get("Icon", ""), name, uuids),
        "iconName": props.get("Icon", ""),
        "paired": paired,
        "trusted": trusted,
        "connected": connected,
        "blocked": blocked,
        "rssi": rssi if rssi is not None else -999,
        "battery": battery if battery is not None else -1,
        "status": status,
        "sublabel": " · ".join(detail_parts),
    }


def collect_device_stubs():
    devices = {}
    error = ""
    filters = [
        ("", None),
        ("Paired", "paired"),
        ("Bonded", "paired"),
        ("Trusted", "trusted"),
        ("Connected", "connected"),
    ]

    for bt_filter, flag in filters:
        args = ["devices"] + ([bt_filter] if bt_filter else [])
        result = btctl(args, timeout=8)
        if result is None:
            return {}, "bluetoothctl is not installed"
        if result.returncode != 0 and not error:
            error = clean_output(result)

        for address, stub in parse_device_lines(result.stdout).items():
            devices.setdefault(address, stub)
            if flag:
                devices[address][flag] = True

    return devices, error


def collect_devices():
    stubs, error = collect_device_stubs()
    devices = [device_details(address, stub) for address, stub in stubs.items()]
    devices.sort(
        key=lambda item: (
            not item["connected"],
            not item["paired"],
            not item["trusted"],
            -item["rssi"],
            item["name"].lower(),
        )
    )
    return devices, error


def status_payload(discover=False):
    ctl = controller_info()

    if ctl["available"] and discover:
        if not ctl["powered"]:
            btctl(["power", "on"], timeout=10)
            ctl = controller_info()
        btctl(["scan", "on"], timeout=7, cli_timeout=True)
        btctl(["scan", "off"], timeout=5)
        ctl = controller_info()

    devices, device_error = collect_devices() if ctl["available"] else ([], "")
    connected = [device for device in devices if device["connected"]]
    paired_count = sum(1 for device in devices if device["paired"])

    if not ctl["available"]:
        summary = "No Bluetooth controller"
    elif not ctl["powered"]:
        summary = "Bluetooth off"
    elif connected:
        summary = (
            f"Connected to {connected[0]['name']}"
            if len(connected) == 1
            else f"{len(connected)} devices connected"
        )
    elif ctl["discovering"]:
        summary = "Scanning"
    else:
        summary = "Bluetooth ready"

    status_lines = []
    if ctl["available"]:
        status_lines.append(ctl["name"] or "Bluetooth controller")
        status_lines.append(f"Adapter  {ctl['address']}")
        status_lines.append(f"Power    {'on' if ctl['powered'] else 'off'}")
        status_lines.append(f"Visible  {'yes' if ctl['discoverable'] else 'no'}")
        status_lines.append(f"Pairable {'yes' if ctl['pairable'] else 'no'}")
        status_lines.append(f"Known    {len(devices)}")
        status_lines.append(f"Paired   {paired_count}")
        status_lines.append(f"Linked   {len(connected)}")
    else:
        status_lines.append(ctl["error"] or "No Bluetooth controller found")

    return {
        "ok": ctl["available"] and not bool(device_error),
        "summary": summary,
        "statusText": "\n".join(status_lines),
        "controller": ctl,
        "powered": ctl["powered"],
        "discovering": ctl["discovering"],
        "discoverable": ctl["discoverable"],
        "pairable": ctl["pairable"],
        "devices": devices,
        "connectedCount": len(connected),
        "pairedCount": paired_count,
        "error": device_error or ctl["error"],
    }


def bar_status():
    ctl = controller_info()
    if not ctl["available"]:
        print("none|0|")
        return
    if not ctl["powered"]:
        print("off|0|")
        return

    result = btctl(["devices", "Connected"], timeout=6)
    if result is None or result.returncode != 0:
        print("error|0|")
        return

    devices = parse_device_lines(result.stdout)
    names = [device["name"].replace("|", " ") for device in devices.values()]
    if names:
        print(f"connected|{len(names)}|{names[0]}")
    else:
        print("on|0|")


def action_result(ok, message="", **extra):
    emit({"ok": ok, "message": message, **extra})


def result_ok(result):
    if result is None:
        return False
    if result.returncode != 0:
        return False
    output = clean_output(result).lower()
    return "failed" not in output and "not available" not in output


def run_action(args, timeout=20, agent=False):
    result = btctl(args, timeout=timeout, agent=agent)
    action_result(result_ok(result), clean_output(result))


def require_address():
    if len(sys.argv) < 3 or not re.fullmatch(MAC_RE, sys.argv[2], re.IGNORECASE):
        action_result(False, "Choose a Bluetooth device first")
        return ""
    return sys.argv[2].upper()


def toggle_power():
    ctl = controller_info()
    if not ctl["available"]:
        action_result(False, ctl["error"] or "No Bluetooth controller")
        return
    run_action(["power", "off" if ctl["powered"] else "on"], timeout=12)


def toggle_flag(flag):
    ctl = controller_info()
    if not ctl["available"]:
        action_result(False, ctl["error"] or "No Bluetooth controller")
        return
    current = ctl["discoverable"] if flag == "discoverable" else ctl["pairable"]
    run_action([flag, "off" if current else "on"], timeout=12)


def connect_device(address):
    ctl = controller_info()
    if ctl["available"] and not ctl["powered"]:
        btctl(["power", "on"], timeout=10)
    run_action(["connect", address], timeout=35)


def pair_device(address):
    ctl = controller_info()
    if ctl["available"] and not ctl["powered"]:
        btctl(["power", "on"], timeout=10)
    if ctl["available"] and not ctl["pairable"]:
        btctl(["pairable", "on"], timeout=10)
    run_action(["pair", address], timeout=45, agent=True)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"

    if action == "scan":
        emit(status_payload(False))
    elif action == "discover":
        emit(status_payload(True))
    elif action == "bar":
        bar_status()
    elif action == "toggle-power":
        toggle_power()
    elif action == "toggle-discoverable":
        toggle_flag("discoverable")
    elif action == "toggle-pairable":
        toggle_flag("pairable")
    elif action == "connect":
        address = require_address()
        if address:
            connect_device(address)
    elif action == "disconnect":
        address = require_address()
        if address:
            run_action(["disconnect", address], timeout=20)
    elif action == "pair":
        address = require_address()
        if address:
            pair_device(address)
    elif action == "cancel-pairing":
        address = require_address()
        if address:
            run_action(["cancel-pairing", address], timeout=12)
    elif action == "trust":
        address = require_address()
        if address:
            run_action(["trust", address], timeout=12)
    elif action == "untrust":
        address = require_address()
        if address:
            run_action(["untrust", address], timeout=12)
    elif action == "block":
        address = require_address()
        if address:
            run_action(["block", address], timeout=12)
    elif action == "unblock":
        address = require_address()
        if address:
            run_action(["unblock", address], timeout=12)
    elif action == "remove":
        address = require_address()
        if address:
            run_action(["remove", address], timeout=15)
    else:
        action_result(False, f"Unknown action: {action}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        emit({
            "ok": False,
            "summary": "Bluetooth error",
            "statusText": f"{type(exc).__name__}: {exc}",
            "controller": {
                "available": False,
                "powered": False,
                "discovering": False,
                "discoverable": False,
                "pairable": False,
                "name": "",
                "address": "",
                "error": f"{type(exc).__name__}: {exc}",
            },
            "powered": False,
            "discovering": False,
            "discoverable": False,
            "pairable": False,
            "devices": [],
            "connectedCount": 0,
            "pairedCount": 0,
            "error": traceback.format_exc(limit=2).strip(),
        })
