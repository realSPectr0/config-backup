#!/usr/bin/env python3
"""
stats-bridge.py
───────────────
Exposes real CPU, RAM, and CPU temperature over HTTP on localhost:7070

The startpage fetches GET http://localhost:7070/stats every 3 seconds.

Requirements:
  pip install psutil            (or: pip install psutil --break-system-packages)

Run on startup (add to hyprland.conf):
  exec-once = python3 ~/startpage/scripts/stats-bridge.py
"""

import json
import psutil
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 7070


def get_stats():
    cpu = psutil.cpu_percent(interval=0.5)
    ram = psutil.virtual_memory()

    # CPU temperature — tries common sensor names
    temp = None
    try:
        sensors = psutil.sensors_temperatures()
        for key in ("coretemp", "k10temp", "zenpower", "acpitz", "cpu_thermal"):
            if key in sensors and sensors[key]:
                temp = sensors[key][0].current
                break
    except AttributeError:
        pass  # sensors_temperatures not available on all platforms

    return {
        "cpu":      round(cpu, 1),
        "ramUsed":  round(ram.used  / 1024**3, 2),
        "ramTotal": round(ram.total / 1024**3, 1),
        "temp":     round(temp) if temp is not None else None,
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass  # suppress request logs

    def do_GET(self):
        if self.path != "/stats":
            self.send_response(404)
            self.end_headers()
            return

        data = json.dumps(get_stats()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    print(f"[stats] Starting HTTP server on http://localhost:{PORT}/stats")
    HTTPServer(("localhost", PORT), Handler).serve_forever()
