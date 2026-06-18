#!/usr/bin/env python3
"""
Calendar events manager for the Luminary bar.
Usage:
  events_manager.py          (no args = read)
  events_manager.py read
  events_manager.py add  DATE TITLE...
  events_manager.py remove DATE INDEX
"""
import json, sys
from pathlib import Path

EVENTS_FILE = Path.home() / ".local/share/qs-calendar/events.json"

def load():
    try: return json.loads(EVENTS_FILE.read_text())
    except: return {}

def save(data):
    EVENTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    EVENTS_FILE.write_text(json.dumps(data, indent=2))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "read"
    data = load()

    if cmd == "add" and len(sys.argv) >= 4:
        date  = sys.argv[2]
        title = " ".join(sys.argv[3:]).strip()
        if title:
            data.setdefault(date, []).append(title)
            save(data)
    elif cmd == "remove" and len(sys.argv) >= 4:
        date = sys.argv[2]
        idx  = int(sys.argv[3])
        if date in data and 0 <= idx < len(data[date]):
            data[date].pop(idx)
            if not data[date]:
                del data[date]
            save(data)

    print(json.dumps(data))

if __name__ == "__main__":
    main()
