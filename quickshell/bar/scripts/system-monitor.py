#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_PID = os.getpid()


def out(data):
    print(json.dumps(data, separators=(",", ":")), flush=True)


def read_text(path, default=""):
    try:
        return Path(path).read_text(errors="ignore").strip()
    except Exception:
        return default


def read_int(path, default=0):
    try:
        return int(read_text(path, str(default)))
    except Exception:
        return default


def first_power_supply(prefix):
    base = Path("/sys/class/power_supply")
    for item in sorted(base.glob(prefix)):
        if item.exists():
            return item
    return None


def fmt_hours(hours):
    if hours <= 0 or hours > 99:
        return "unknown"
    h = int(hours)
    m = int(round((hours - h) * 60))
    if h <= 0:
        return f"{m}m"
    return f"{h}h {m:02d}m"


def battery():
    bat = first_power_supply("BAT*")
    profile = "unknown"
    try:
        profile = subprocess.run(
            ["powerprofilesctl", "get"],
            capture_output=True,
            text=True,
            timeout=1,
        ).stdout.strip() or "unknown"
    except Exception:
        pass

    adapters = []
    for supply in sorted(Path("/sys/class/power_supply").glob("*")):
        typ = read_text(supply / "type")
        if typ == "Mains":
            adapters.append(read_int(supply / "online", 0) == 1)
    ac_online = any(adapters)

    if not bat:
        out({
            "present": False,
            "percent": 0,
            "status": "No battery",
            "profile": profile,
            "ac_online": ac_online,
        })
        return

    percent = read_int(bat / "capacity", 0)
    status = read_text(bat / "status", "Unknown")
    energy_now = read_int(bat / "energy_now", 0) / 1_000_000
    energy_full = read_int(bat / "energy_full", 0) / 1_000_000
    energy_design = read_int(bat / "energy_full_design", 0) / 1_000_000
    power_now = read_int(bat / "power_now", 0) / 1_000_000
    voltage = read_int(bat / "voltage_now", 0) / 1_000_000
    health = round((energy_full / energy_design) * 100) if energy_design > 0 else 0

    if power_now > 0.15 and energy_now > 0:
        if status.lower() == "discharging":
            time_left = fmt_hours(energy_now / power_now)
        elif status.lower() == "charging" and energy_full > energy_now:
            time_left = fmt_hours((energy_full - energy_now) / power_now)
        else:
            time_left = "plugged"
    else:
        time_left = "plugged" if ac_online else "unknown"

    out({
        "present": True,
        "percent": percent,
        "status": status,
        "profile": profile,
        "ac_online": ac_online,
        "energy_now_wh": round(energy_now, 1),
        "energy_full_wh": round(energy_full, 1),
        "energy_design_wh": round(energy_design, 1),
        "power_w": round(power_now, 1),
        "voltage_v": round(voltage, 1),
        "health": health,
        "cycle_count": read_int(bat / "cycle_count", -1),
        "threshold": read_int(bat / "charge_control_end_threshold", 0),
        "time_left": time_left,
        "model": read_text(bat / "model_name", ""),
        "manufacturer": read_text(bat / "manufacturer", ""),
    })


def cpu_times():
    parts = read_text("/proc/stat").splitlines()[0].split()[1:]
    nums = [int(x) for x in parts]
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    total = sum(nums)
    return idle, total


def cpu_percent():
    idle_a, total_a = cpu_times()
    time.sleep(0.16)
    idle_b, total_b = cpu_times()
    total = max(1, total_b - total_a)
    idle = max(0, idle_b - idle_a)
    return round((1 - idle / total) * 100)


def meminfo():
    values = {}
    for line in read_text("/proc/meminfo").splitlines():
        key, rest = line.split(":", 1)
        values[key] = int(rest.strip().split()[0])
    total = values.get("MemTotal", 1)
    available = values.get("MemAvailable", 0)
    used = max(0, total - available)
    swap_total = values.get("SwapTotal", 0)
    swap_free = values.get("SwapFree", 0)
    swap_used = max(0, swap_total - swap_free)
    return {
        "used_gb": round(used / 1024 / 1024, 1),
        "total_gb": round(total / 1024 / 1024, 1),
        "percent": round(used / total * 100),
        "swap_used_gb": round(swap_used / 1024 / 1024, 1),
        "swap_total_gb": round(swap_total / 1024 / 1024, 1),
        "swap_percent": round(swap_used / swap_total * 100) if swap_total else 0,
    }


def temp_from_millic(value):
    try:
        temp = int(value) / 1000
        if 0 < temp < 130:
            return round(temp)
    except Exception:
        pass
    return None


def collect_temps():
    temps = []

    for zone in sorted(Path("/sys/class/thermal").glob("thermal_zone*")):
        temp = temp_from_millic(read_text(zone / "temp"))
        label = read_text(zone / "type", zone.name)
        if temp is not None:
            temps.append({"label": label, "temp": temp, "source": "thermal"})

    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        name = read_text(hwmon / "name", hwmon.name)
        for item in sorted(hwmon.glob("temp*_input")):
            temp = temp_from_millic(read_text(item))
            if temp is None:
                continue
            index = item.name.replace("temp", "").replace("_input", "")
            label = read_text(hwmon / f"temp{index}_label", "")
            full_label = f"{name} {label}".strip()
            temps.append({"label": full_label, "temp": temp, "source": "hwmon"})

    seen = set()
    unique = []
    for item in temps:
        key = item["label"].lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)

    def rank(item):
        label = item["label"].lower()
        if any(x in label for x in ["package", "x86_pkg", "tcpu", "coretemp", "cpu"]):
            return 0
        if any(x in label for x in ["gpu", "nvidia", "amdgpu"]):
            return 1
        if any(x in label for x in ["mem", "spd"]):
            return 2
        if any(x in label for x in ["nvme", "composite"]):
            return 3
        if "wifi" in label or "iwlwifi" in label:
            return 4
        return 5

    return sorted(unique, key=lambda x: (rank(x), -x["temp"], x["label"]))[:12]


def collect_fans():
    fans = []
    for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        name = read_text(hwmon / "name", hwmon.name)
        for item in sorted(hwmon.glob("fan*_input")):
            rpm = read_int(item, 0)
            if rpm <= 0:
                continue
            index = item.name.replace("fan", "").replace("_input", "")
            label = read_text(hwmon / f"fan{index}_label", f"{name} fan{index}")
            fans.append({"label": label, "rpm": rpm})
    return fans[:6]


def nvidia_gpu():
    query = "name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit"
    try:
        result = subprocess.run(
            ["nvidia-smi", f"--query-gpu={query}", "--format=csv,noheader,nounits"],
            capture_output=True,
            text=True,
            timeout=1.2,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        parts = [p.strip() for p in result.stdout.splitlines()[0].split(",")]
        used = float(parts[3])
        total = float(parts[4])
        return {
            "available": True,
            "name": parts[0],
            "temp": round(float(parts[1])),
            "usage": round(float(parts[2])),
            "mem_used_mb": round(used),
            "mem_total_mb": round(total),
            "mem_percent": round(used / total * 100) if total else 0,
            "power_w": round(float(parts[5]), 1) if parts[5] != "[N/A]" else 0,
            "power_limit_w": round(float(parts[6]), 1) if parts[6] != "[N/A]" else 0,
        }
    except Exception:
        return {
            "available": False,
            "name": "GPU unavailable",
            "temp": 0,
            "usage": 0,
            "mem_used_mb": 0,
            "mem_total_mb": 0,
            "mem_percent": 0,
            "power_w": 0,
            "power_limit_w": 0,
        }


def cpu_frequency_ghz():
    freqs = []
    for item in Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq"):
        value = read_int(item, 0)
        if value > 0:
            freqs.append(value)
    if not freqs:
        return 0
    return round(sum(freqs) / len(freqs) / 1_000_000, 2)


def stats():
    temps = collect_temps()
    gpu = nvidia_gpu()
    mem = meminfo()
    labels = [(t["label"].lower(), t["temp"]) for t in temps]
    cpu_candidates = [temp for label, temp in labels if any(x in label for x in ["package", "x86_pkg", "tcpu", "coretemp", "cpu"])]
    gpu_candidates = [temp for label, temp in labels if any(x in label for x in ["gpu", "nvidia", "amdgpu"])]
    load_parts = read_text("/proc/loadavg", "0 0 0").split()

    out({
        "cpu": {
            "usage": cpu_percent(),
            "temp": max(cpu_candidates) if cpu_candidates else 0,
            "freq_ghz": cpu_frequency_ghz(),
            "load1": load_parts[0],
            "load5": load_parts[1] if len(load_parts) > 1 else "0",
        },
        "gpu": {
            **gpu,
            "temp": gpu["temp"] or (max(gpu_candidates) if gpu_candidates else 0),
        },
        "memory": mem,
        "temps": temps,
        "fans": collect_fans(),
        "process_count": len([p for p in Path("/proc").iterdir() if p.name.isdigit()]),
        "updated": time.strftime("%H:%M:%S"),
    })


def processes(query=""):
    query = query.lower().strip()
    try:
        result = subprocess.run(
            ["ps", "-eo", "pid=,user=,pcpu=,pmem=,rss=,comm=,args=", "--sort=-pcpu"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        lines = result.stdout.splitlines()
    except Exception as exc:
        out({"processes": [], "error": str(exc)})
        return

    rows = []
    for line in lines:
        parts = line.strip().split(None, 6)
        if len(parts) < 6:
            continue
        if len(parts) == 6:
            pid, user, cpu, mem, rss, comm = parts
            args = comm
        else:
            pid, user, cpu, mem, rss, comm, args = parts
        if int(pid) == SCRIPT_PID:
            continue
        haystack = f"{pid} {user} {comm} {args}".lower()
        if query and query not in haystack:
            continue
        rows.append({
            "pid": int(pid),
            "user": user,
            "cpu": round(float(cpu), 1),
            "mem": round(float(mem), 1),
            "rss_mb": round(int(rss) / 1024),
            "name": comm,
            "command": args,
        })
        if len(rows) >= 32:
            break

    out({"processes": rows, "query": query})


def kill_process(pid_arg, mode):
    try:
        pid = int(pid_arg)
        if pid <= 1 or pid == SCRIPT_PID:
            raise ValueError("refusing to kill protected pid")
        sig = signal.SIGKILL if mode in ("kill", "force", "9") else signal.SIGTERM
        os.kill(pid, sig)
        out({"ok": True, "pid": pid, "signal": "KILL" if sig == signal.SIGKILL else "TERM"})
    except Exception as exc:
        out({"ok": False, "pid": pid_arg, "error": str(exc)})


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "stats"
    if action == "battery":
        battery()
    elif action == "stats":
        stats()
    elif action == "processes":
        processes(sys.argv[2] if len(sys.argv) > 2 else "")
    elif action == "kill":
        if len(sys.argv) < 3:
            out({"ok": False, "error": "missing pid"})
        else:
            kill_process(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "term")
    else:
        out({"ok": False, "error": f"unknown action: {action}"})


if __name__ == "__main__":
    main()
