#!/usr/bin/env python3
import json
import os
import subprocess
import sys


def pactl(args, timeout=12):
    env = os.environ.copy()
    env["LC_ALL"] = "C"
    try:
        return subprocess.run(
            ["pactl", *args],
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


def pactl_json(args, fallback):
    result = pactl(["-f", "json", *args])
    if not result or result.returncode != 0:
        return fallback
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return fallback


def emit(data):
    print(json.dumps(data, ensure_ascii=False))


def volume_pct(item):
    volume = item.get("volume") or {}
    values = []
    for channel in volume.values():
        percent = str(channel.get("value_percent", "0%")).rstrip("%")
        try:
            values.append(int(round(float(percent))))
        except ValueError:
            continue
    return int(round(sum(values) / len(values))) if values else 0


def clean_name(value):
    value = value or ""
    for suffix in (" Analog Stereo", " Digital Stereo", " Pro Audio"):
        value = value.replace(suffix, "")
    return value.strip() or "Audio device"


def icon_for_device(item, is_input=False):
    props = item.get("properties") or {}
    icon = props.get("device.icon_name", "")
    bus = props.get("device.bus", "")
    form = props.get("device.form_factor", "")
    active_port = item.get("active_port", "")
    name = (item.get("description") or "").lower()

    if is_input:
        if "headset" in icon or "bluetooth" in bus or "headset" in form:
            return "󰋎"
        return "󰍬"

    if "bluetooth" in bus or "headset" in icon or "headset" in form:
        return "󰋋"
    if "headphone" in active_port or "headphone" in name:
        return "󰋋"
    if "speaker" in active_port or "speaker" in name:
        return "󰓃"
    return "󰕾"


def state_label(item):
    state = (item.get("state") or "unknown").lower()
    return state.capitalize()


def port_label(item):
    active = item.get("active_port", "")
    for port in item.get("ports") or []:
        if port.get("name") == active:
            return port.get("description") or active
    return active


def sink_item(item, default_name):
    name = item.get("name", "")
    return {
        "id": str(item.get("index", name)),
        "name": name,
        "label": clean_name(item.get("description")),
        "sublabel": " · ".join(v for v in [state_label(item), port_label(item)] if v),
        "volume": volume_pct(item),
        "muted": bool(item.get("mute", False)),
        "isDefault": name == default_name,
        "icon": icon_for_device(item),
        "state": item.get("state", ""),
    }


def source_item(item, default_name):
    name = item.get("name", "")
    props = item.get("properties") or {}
    if props.get("device.class") == "monitor" or name.endswith(".monitor"):
        return None
    return {
        "id": str(item.get("index", name)),
        "name": name,
        "label": clean_name(item.get("description")),
        "sublabel": " · ".join(v for v in [state_label(item), port_label(item)] if v),
        "volume": volume_pct(item),
        "muted": bool(item.get("mute", False)),
        "isDefault": name == default_name,
        "icon": icon_for_device(item, is_input=True),
        "state": item.get("state", ""),
    }


def stream_item(item, sinks_by_index, source_stream=False):
    props = item.get("properties") or {}
    app = props.get("application.name") or props.get("media.name") or props.get("application.process.binary")
    media = props.get("media.name", "")
    label = clean_name(app or "Audio stream")
    sink_index = item.get("sink") if not source_stream else item.get("source")
    device = sinks_by_index.get(str(sink_index), "")

    sublabel_parts = []
    if media and media != label:
        sublabel_parts.append(media)
    if device:
        sublabel_parts.append(device)
    if item.get("corked"):
        sublabel_parts.append("Paused")

    return {
        "id": str(item.get("index", "")),
        "label": label,
        "sublabel": " · ".join(sublabel_parts),
        "volume": volume_pct(item),
        "muted": bool(item.get("mute", False)),
        "isDefault": False,
        "icon": "󰎆" if source_stream else "󰝚",
        "state": "stream",
    }


def scan():
    info = pactl_json(["info"], {})
    sinks = pactl_json(["list", "sinks"], [])
    sources = pactl_json(["list", "sources"], [])
    sink_inputs = pactl_json(["list", "sink-inputs"], [])
    source_outputs = pactl_json(["list", "source-outputs"], [])

    default_sink_name = info.get("default_sink_name", "")
    default_source_name = info.get("default_source_name", "")
    out = [sink_item(item, default_sink_name) for item in sinks]
    inp = [item for item in (source_item(item, default_source_name) for item in sources) if item]

    sink_labels = {str(item.get("index", "")): clean_name(item.get("description")) for item in sinks}
    source_labels = {str(item.get("index", "")): clean_name(item.get("description")) for item in sources}
    streams = [stream_item(item, sink_labels, False) for item in sink_inputs]
    input_streams = [stream_item(item, source_labels, True) for item in source_outputs]

    default_sink = next((item for item in out if item["isDefault"]), out[0] if out else {})
    default_source = next((item for item in inp if item["isDefault"]), inp[0] if inp else {})
    summary = default_sink.get("label", "No output")
    if default_sink:
        summary = f"{summary} · {default_sink.get('volume', 0)}%"
        if default_sink.get("muted"):
            summary += " · muted"

    emit(
        {
            "ok": True,
            "summary": summary,
            "defaultSinkName": default_sink_name,
            "defaultSourceName": default_source_name,
            "defaultSink": default_sink,
            "defaultSource": default_source,
            "sinks": out,
            "sources": inp,
            "streams": streams,
            "inputStreams": input_streams,
        }
    )


def action_result(ok, message=""):
    emit({"ok": ok, "message": message})


def run_pactl(args):
    result = pactl(args, timeout=20)
    if not result:
        action_result(False, "pactl is not installed")
        return False
    action_result(result.returncode == 0, (result.stderr or result.stdout).strip())
    return result.returncode == 0


def set_volume(kind, target, value):
    try:
        pct = max(0, min(150, int(round(float(value)))))
    except ValueError:
        action_result(False, "Invalid volume")
        return

    command = {
        "sink": "set-sink-volume",
        "source": "set-source-volume",
        "stream": "set-sink-input-volume",
        "input-stream": "set-source-output-volume",
    }.get(kind)
    if not command:
        action_result(False, f"Unknown volume target: {kind}")
        return
    run_pactl([command, target, f"{pct}%"])


def toggle_mute(kind, target):
    command = {
        "sink": "set-sink-mute",
        "source": "set-source-mute",
        "stream": "set-sink-input-mute",
        "input-stream": "set-source-output-mute",
    }.get(kind)
    if not command:
        action_result(False, f"Unknown mute target: {kind}")
        return
    run_pactl([command, target, "toggle"])


def set_default(kind, name):
    if kind == "sink":
        ok = run_pactl(["set-default-sink", name])
        if ok:
            for stream in pactl_json(["list", "sink-inputs"], []):
                pactl(["move-sink-input", str(stream.get("index")), name], timeout=8)
    elif kind == "source":
        ok = run_pactl(["set-default-source", name])
        if ok:
            for stream in pactl_json(["list", "source-outputs"], []):
                pactl(["move-source-output", str(stream.get("index")), name], timeout=8)
    else:
        action_result(False, f"Unknown default target: {kind}")


def move_stream(stream_id, sink_name):
    run_pactl(["move-sink-input", stream_id, sink_name])


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "scan"
    if action == "scan":
        scan()
    elif action == "set-volume":
        set_volume(sys.argv[2], sys.argv[3], sys.argv[4])
    elif action == "toggle-mute":
        toggle_mute(sys.argv[2], sys.argv[3])
    elif action == "set-default":
        set_default(sys.argv[2], sys.argv[3])
    elif action == "move-stream":
        move_stream(sys.argv[2], sys.argv[3])
    else:
        action_result(False, f"Unknown action: {action}")


if __name__ == "__main__":
    main()
