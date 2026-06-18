#!/usr/bin/env python3
import os
import json
import requests
import sys
import argparse
import subprocess

WALLDIR = os.path.expanduser("~/Pictures/Wallpapers")
COLLECTIONDIR = os.path.join(WALLDIR, "Online")
THUMBDIR = os.path.expanduser("~/.cache/wallpaper-thumbs")
API_KEY_FILE = os.path.join(os.path.dirname(__file__), ".wallhaven_api_key")
API_KEY = ""
if os.path.exists(API_KEY_FILE):
    with open(API_KEY_FILE, "r") as f:
        API_KEY = f.read().strip()
WALLHAVEN_URL = "https://wallhaven.cc/api/v1/search"

def get_walls_from_dir(directory, source_name):
    if not os.path.exists(THUMBDIR):
        os.makedirs(THUMBDIR)

    walls = []
    if not os.path.exists(directory):
        return walls
    
    for f in os.listdir(directory):
        if f.lower().endswith(('.png', '.jpg', '.jpeg')):
            path = os.path.join(directory, f)
            if os.path.isdir(path): continue # Skip subdirs

            thumb_path = os.path.join(THUMBDIR, f)
            
            if not os.path.exists(thumb_path) or os.path.getmtime(path) > os.path.getmtime(thumb_path):
                try:
                    subprocess.run([
                        "magick", path, "-resize", "300x200^", "-gravity", "center", 
                        "-extent", "300x200", "-quality", "85", thumb_path
                    ], check=True, capture_output=True)
                except Exception as e:
                    thumb_path = path

            walls.append({
                "name": f,
                "path": path,
                "thumb": "file://" + thumb_path,
                "source": source_name,
                "full": path
            })
    return sorted(walls, key=lambda x: x["name"])

def get_local_wallpapers():
    return get_walls_from_dir(WALLDIR, "local")

def get_collection_wallpapers():
    return get_walls_from_dir(COLLECTIONDIR, "collection")

def get_wallhaven_wallpapers(query="", page=1):
    params = {
        "q": query,
        "categories": "110",
        "purity": "100",
        "atleast": "1920x1200",
        "ratios": "landscape",
        "sorting": "relevance",
        "order": "desc",
        "page": page,
        "apikey": API_KEY
    }

    try:
        r = requests.get(WALLHAVEN_URL, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()
        
        walls = []
        for item in data.get("data", []):
            walls.append({
                "name": f"wallhaven-{item['id']}",
                "path": item["path"],
                "thumb": item["thumbs"]["large"],
                "source": "wallhaven",
                "full": item["path"],
                "id": item["id"]
            })
        return walls
    except Exception as e:
        return []

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--local-only", action="store_true")
    parser.add_argument("--online-only", action="store_true")
    parser.add_argument("--collection-only", action="store_true")
    parser.add_argument("--query", type=str, default="")
    parser.add_argument("--page", type=int, default=1)
    args = parser.parse_args()

    if args.local_only:
        print(json.dumps(get_local_wallpapers()))
    elif args.collection_only:
        print(json.dumps(get_collection_wallpapers()))
    elif args.online_only:
        print(json.dumps(get_wallhaven_wallpapers(args.query, args.page)))
    else:
        # Default behavior: combine all
        local_walls = get_local_wallpapers()
        coll_walls = get_collection_wallpapers()
        remote_walls = get_wallhaven_wallpapers(args.query, args.page)
        print(json.dumps(local_walls + coll_walls + remote_walls))
    
    sys.stdout.flush()
