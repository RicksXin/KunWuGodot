#!/usr/bin/env python3
"""Development launcher; credentials stay out of command arguments and output."""
import argparse
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--headless-smoke", action="store_true")
parser.add_argument("--headless-full", action="store_true")
args = parser.parse_args()
admin = Path(os.environ.get("KUNWU_ADMIN_ROOT", root.parent / "KunWuAdmin"))
credentials = Path(os.environ.get("KUNWU_RESOURCE_CREDENTIALS", admin / ".local/resource-development.json"))
if not credentials.exists():
    raise SystemExit("请先在 KunWuAdmin 执行 resources:setup 初始化独立测试身份。")
with credentials.open() as handle:
    local = json.load(handle)
environment = os.environ.copy()
environment["KUNWU_RESOURCE_API_URL"] = environment.get("KUNWU_RESOURCE_API_URL", "http://127.0.0.1:3100")
environment["KUNWU_RESOURCE_TOKEN"] = local["playerToken"]
godot = environment.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
headless = args.headless_smoke or args.headless_full
scene = "res://tools/validate_resource_online.tscn" if headless else "res://scenes/resource_online_test.tscn"
command = [godot, "--path", str(root)]
if headless:
    command.append("--headless")
command += [scene, "--", "--no-profile-write", "--ignore-config-cache", "--resource-online-test"]
if headless:
    command.append("--resource-test-no-cache")
if args.headless_full:
    command.append("--resource-full-validation")
raise SystemExit(subprocess.call(command, env=environment))
