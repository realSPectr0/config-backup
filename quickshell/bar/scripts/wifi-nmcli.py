#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
from collections import defaultdict


def nmcli(args, timeout=20):
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    try:
        return subprocess.run(
            ["nmcli", *args],
            capture_output=True,
            text=True,
            timeout=timeout,
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


def emit(data):
    print(json.dumps(data, ensure_ascii=False))


def split_terse(line):
    fields = []
    buf = []
    escaped = False

    for ch in line.rstrip("\n"):
        if escaped:
            buf.append(ch)
            escaped = False
        elif ch == "\\":
            escaped = True
        elif ch == ":":
            fields.append("".join(buf))
            buf = []
        else:
            buf.append(ch)

    if escaped:
        buf.append("\\")

    fields.append("".join(buf))
    return fields


def first_line(result):
    if result and result.returncode == 0:
        for line in result.stdout.splitlines():
            if line.strip():
                return line.strip()
    return ""


def wifi_radio_enabled():
    line = first_line(nmcli(["-t", "-f", "WIFI", "general"], timeout=5))
    if line == "enabled":
        return True
    if line == "disabled":
        return False
    return None


def wifi_devices():
    result = nmcli(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"], timeout=8)
    devices = []
    if not result or result.returncode != 0:
        return devices

    for line in result.stdout.splitlines():
        parts = split_terse(line)
        if len(parts) < 4 or parts[1] != "wifi":
            continue
        devices.append(
            {
                "device": parts[0],
                "state": parts[2],
                "connection": parts[3],
            }
        )
    return devices


def active_device(devices):
    for dev in devices:
        if dev["state"] == "connected":
            return dev
    return devices[0] if devices else {}


def saved_profiles():
    profiles = defaultdict(list)
    result = nmcli(
        ["-t", "-f", "NAME,TYPE,802-11-wireless.ssid", "connection", "show"],
        timeout=10,
    )

    if not result or result.returncode != 0:
        result = nmcli(["-t", "-f", "NAME,TYPE", "connection", "show"], timeout=10)

    if not result or result.returncode != 0:
        return profiles

    for line in result.stdout.splitlines():
        parts = split_terse(line)
        if len(parts) < 2 or parts[1] != "802-11-wireless":
            continue

        name = parts[0]
        ssid = parts[2] if len(parts) > 2 and parts[2] else name
        profiles[ssid].append(name)

    return profiles


def ipv4_for(device):
    if not device:
        return ""
    try:
        result = subprocess.run(
            ["ip", "-o", "-4", "addr", "show", "dev", device],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    match = re.search(r"\binet\s+([0-9.]+/\d+)", result.stdout)
    return match.group(1) if match else ""


def default_route():
    try:
        result = subprocess.run(
            ["ip", "route", "show", "default"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.splitlines()[0] if result.stdout.strip() else ""


def status_base():
    enabled = wifi_radio_enabled()
    devices = wifi_devices()
    device = active_device(devices)
    active_connection = device.get("connection", "") if device.get("state") == "connected" else ""

    return {
        "wifi_enabled": enabled,
        "device": device.get("device", ""),
        "device_state": device.get("state", ""),
        "active_connection": active_connection,
        "ipv4": ipv4_for(device.get("device", "")),
        "default_route": default_route(),
    }


def scan():
    data = status_base()
    profiles = saved_profiles()
    networks = {}
    error = ""

    if data["wifi_enabled"] is False:
        data.update(
            {
                "summary": "Wi-Fi disabled",
                "networks": [],
                "error": "",
                "saved_count": sum(len(v) for v in profiles.values()),
            }
        )
        emit(data)
        return

    if not data["device"]:
        data.update(
            {
                "summary": "No Wi-Fi adapter",
                "networks": [],
                "error": "No Wi-Fi device found",
                "saved_count": sum(len(v) for v in profiles.values()),
            }
        )
        emit(data)
        return

    nmcli(["device", "wifi", "rescan", "ifname", data["device"]], timeout=12)
    result = nmcli(
        [
            "-t",
            "-f",
            "IN-USE,SSID,BSSID,SIGNAL,BARS,SECURITY",
            "device",
            "wifi",
            "list",
            "ifname",
            data["device"],
        ],
        timeout=15,
    )

    if not result:
        error = "nmcli is not installed"
    elif result.returncode != 0:
        error = (result.stderr or result.stdout).strip()
    else:
        for line in result.stdout.splitlines():
            parts = split_terse(line)
            if len(parts) < 6:
                continue

            in_use, ssid, bssid, signal, bars, security = parts[:6]
            hidden = ssid == ""
            key = ssid if ssid else f"hidden:{bssid}"
            try:
                signal_value = int(signal)
            except ValueError:
                signal_value = 0

            current = networks.get(key)
            if current and current["signal"] > signal_value and in_use != "*":
                continue

            security = security.strip()
            active = in_use == "*"
            networks[key] = {
                "ssid": ssid,
                "display": ssid if ssid else "Hidden network",
                "bssid": bssid,
                "signal": signal_value,
                "bars": bars,
                "security": security,
                "locked": bool(security and security != "--"),
                "saved": ssid in profiles,
                "active": active,
                "hidden": hidden,
            }

    network_list = sorted(
        networks.values(),
        key=lambda item: (
            not item["active"],
            -item["signal"],
            item["display"].lower(),
        ),
    )

    active = next((item for item in network_list if item["active"]), None)
    active_ssid = active["ssid"] if active else data["active_connection"]
    if data["wifi_enabled"] is None:
        summary = "Wi-Fi status unknown"
    elif active_ssid:
        summary = f"Connected to {active_ssid}"
    else:
        summary = "Wi-Fi enabled"

    data.update(
        {
            "summary": summary,
            "active_ssid": active_ssid,
            "networks": network_list,
            "error": error,
            "saved_count": sum(len(v) for v in profiles.values()),
        }
    )
    emit(data)


def bar_status():
    base = status_base()

    if base["wifi_enabled"] is False:
        print("Wi-Fi off")
        return

    if not base["device"]:
        if base["default_route"]:
            parts = base["default_route"].split()
            if "dev" in parts:
                idx = parts.index("dev")
                if idx + 1 < len(parts):
                    print(parts[idx + 1])
                    return
        print("offline")
        return

    result = nmcli(
        [
            "-t",
            "-f",
            "IN-USE,SSID,SIGNAL",
            "device",
            "wifi",
            "list",
            "ifname",
            base["device"],
        ],
        timeout=8,
    )
    if result and result.returncode == 0:
        for line in result.stdout.splitlines():
            parts = split_terse(line)
            if len(parts) >= 3 and parts[0] == "*":
                ssid = parts[1] or base["active_connection"] or "Wi-Fi"
                signal = parts[2]
                print(f"{ssid} {signal}%")
                return

    if base["active_connection"]:
        print(base["active_connection"])
    else:
        print("Wi-Fi ready")


def action_result(ok, message="", **extra):
    emit({"ok": ok, "message": message, **extra})


def toggle_wifi():
    enabled = wifi_radio_enabled()
    target = "off" if enabled else "on"
    result = nmcli(["radio", "wifi", target], timeout=10)
    if not result:
        action_result(False, "nmcli is not installed")
    else:
        action_result(result.returncode == 0, (result.stderr or result.stdout).strip())


def restart_networking():
    off = nmcli(["networking", "off"], timeout=10)
    on = nmcli(["networking", "on"], timeout=12)
    if not off or not on:
        action_result(False, "nmcli is not installed")
        return
    ok = off.returncode == 0 and on.returncode == 0
    action_result(ok, (on.stderr or off.stderr or on.stdout or off.stdout).strip())


def connect(ssid, password=""):
    if not ssid:
        action_result(False, "Choose a visible network first")
        return

    base = status_base()
    if base["wifi_enabled"] is False:
        nmcli(["radio", "wifi", "on"], timeout=10)

    args = ["device", "wifi", "connect", ssid]
    if password:
        args.extend(["password", password])
    if base["device"]:
        args.extend(["ifname", base["device"]])

    result = nmcli(args, timeout=45)
    if not result:
        action_result(False, "nmcli is not installed")
        return

    output = (result.stderr or result.stdout).strip()
    need_password = any(
        phrase in output.lower()
        for phrase in ["secrets were required", "password", "no secrets"]
    )
    action_result(result.returncode == 0, output, require_password=need_password)


def disconnect():
    base = status_base()
    if not base["device"]:
        action_result(False, "No Wi-Fi device found")
        return

    result = nmcli(["device", "disconnect", base["device"]], timeout=15)
    if not result:
        action_result(False, "nmcli is not installed")
    else:
        action_result(result.returncode == 0, (result.stderr or result.stdout).strip())


def forget(ssid):
    profiles = saved_profiles()
    names = profiles.get(ssid, [])
    if not names:
        action_result(False, f"No saved profile for {ssid}")
        return

    messages = []
    ok = True
    for name in names:
        result = nmcli(["connection", "delete", "id", name], timeout=12)
        if not result or result.returncode != 0:
            ok = False
        if result:
            messages.append((result.stderr or result.stdout).strip())

    action_result(ok, "\n".join(m for m in messages if m))


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"

    if action == "scan":
        scan()
    elif action == "bar":
        bar_status()
    elif action == "toggle":
        toggle_wifi()
    elif action == "restart":
        restart_networking()
    elif action == "connect":
        connect(sys.argv[2] if len(sys.argv) > 2 else "", sys.argv[3] if len(sys.argv) > 3 else "")
    elif action == "disconnect":
        disconnect()
    elif action == "forget":
        forget(sys.argv[2] if len(sys.argv) > 2 else "")
    else:
        action_result(False, f"Unknown action: {action}")


if __name__ == "__main__":
    main()
