#!/usr/bin/env python3
"""Run Meowa CLI commands behind an explicit per-job credit approval gate."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Sequence


ROOT = Path(__file__).resolve().parent.parent
LEDGER_PATH = ROOT / "art" / "source_archive" / "meowa" / "api_spend_ledger.jsonl"

EXPLICIT_FREE_COMMANDS = {
    "credits-balance",
    "map-reference-search",
    "map-reference-download",
    "texture-reference-search",
    "texture-reference-download",
    "video-prompt-list",
    "custom-workflow-list",
    "one-click-upgrade-prompts",
}

BLOCKED_COMMANDS = {
    "spine-run": "Spine has no approved Godot runtime or stable public pricing contract.",
    "custom-workflow-run": "Custom workflow pricing and output bounds are account-specific.",
    "game-design-run": "Realtime token charging cannot be capped reliably by this gate.",
}

MINIMUM_ESTIMATED_CREDITS = {
    # A 2026-08-21 production run charged 15 credits. Keep both submission surfaces at
    # that observed floor so the older 10-credit documentation cannot authorize a job.
    "tileset-gen-run": Decimal("15"),
    "tileset-gen-submit": Decimal("15"),
}

SENSITIVE_OPTION_PARTS = ("api-key", "apikey", "authorization", "secret", "token")


def _decimal_argument(value: str) -> Decimal:
    try:
        parsed = Decimal(value)
    except InvalidOperation as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if not parsed.is_finite() or parsed < 0:
        raise argparse.ArgumentTypeError("must be a finite non-negative number")
    return parsed


def _classify(command: str) -> str:
    if command in BLOCKED_COMMANDS:
        return "blocked"
    if command.endswith(("-run", "-submit")):
        return "billable"
    if command in EXPLICIT_FREE_COMMANDS:
        return "free"
    if command.endswith(("-poll", "-history", "-download", "-cancel", "-template-info")):
        return "free"
    return "unknown"


def _resolve_runner() -> Path:
    candidates = (
        ROOT / ".agents" / "skills" / "game-assets" / "meowart_api.py",
        Path.home() / ".codex" / "skills" / "game-assets" / "meowart_api.py",
        Path.home() / ".agents" / "skills" / "game-assets" / "meowart_api.py",
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    searched = "\n".join(f"- {path}" for path in candidates)
    raise FileNotFoundError(f"Meowa game-assets Skill runner is not installed. Searched:\n{searched}")


def _validate_local_secret_file() -> None:
    env_path = ROOT / ".env"
    if not env_path.exists():
        return
    mode = env_path.stat().st_mode & 0o777
    if mode & 0o077:
        raise ValueError(
            f".env permissions are {mode:03o}; run `chmod 600 .env` before using Meowa"
        )
    ignored = subprocess.run(
        ["git", "check-ignore", "-q", ".env"],
        cwd=ROOT,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if ignored.returncode != 0:
        raise ValueError(".env is not ignored by Git; refuse to expose MEOWART_API_KEY")


def _reject_sensitive_args(arguments: Sequence[str]) -> None:
    for argument in arguments:
        normalized = argument.lower().lstrip("-")
        if any(part in normalized for part in SENSITIVE_OPTION_PARTS):
            raise ValueError(
                "API keys and tokens must come from MEOWART_API_KEY/.env, not command arguments"
            )


def _sanitize_args(arguments: Sequence[str]) -> list[str]:
    sanitized: list[str] = []
    redact_next = False
    for argument in arguments:
        if redact_next:
            sanitized.append("<redacted>")
            redact_next = False
            continue
        normalized = argument.lower().lstrip("-")
        if any(part in normalized for part in SENSITIVE_OPTION_PARTS):
            if "=" in argument:
                sanitized.append(f"{argument.split('=', 1)[0]}=<redacted>")
            else:
                sanitized.append(argument)
                redact_next = True
            continue
        sanitized.append(argument)
    return sanitized


def _append_ledger(payload: dict[str, object]) -> None:
    LEDGER_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Guard Meowa calls with explicit per-command credit approval.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Validate without running Meowa")
    parser.add_argument("--estimated-credits", type=_decimal_argument)
    parser.add_argument("--approved-max-credits", type=_decimal_argument)
    parser.add_argument("--approval-reference", default="")
    parser.add_argument("command", help="Meowa CLI command, for example credits-balance")
    parser.add_argument("command_args", nargs=argparse.REMAINDER)
    return parser


def _validate_approval(args: argparse.Namespace, classification: str) -> None:
    if classification == "blocked":
        raise ValueError(BLOCKED_COMMANDS[args.command])
    if classification == "unknown":
        raise ValueError(
            "Unknown Meowa command. Add an explicit reviewed classification before using it."
        )
    if classification == "free":
        return

    if args.estimated_credits is None or args.estimated_credits <= 0:
        raise ValueError("Billable commands require --estimated-credits greater than zero")
    minimum_estimate = MINIMUM_ESTIMATED_CREDITS.get(args.command)
    if minimum_estimate is not None and args.estimated_credits < minimum_estimate:
        raise ValueError(
            f"{args.command} requires an estimate of at least {minimum_estimate} credits"
        )
    if args.approved_max_credits is None:
        raise ValueError("Billable commands require --approved-max-credits")
    if args.estimated_credits > args.approved_max_credits:
        raise ValueError("Estimated credits exceed the user-approved maximum")
    if len(args.approval_reference.strip()) < 8:
        raise ValueError("Billable commands require a traceable --approval-reference")


def main(argv: Sequence[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    classification = _classify(args.command)

    try:
        _reject_sensitive_args(args.command_args)
        _validate_approval(args, classification)
    except ValueError as exc:
        parser.error(str(exc))

    plan = {
        "classification": classification,
        "command": args.command,
        "arguments": _sanitize_args(args.command_args),
        "estimated_credits": str(args.estimated_credits) if args.estimated_credits is not None else None,
        "approved_max_credits": (
            str(args.approved_max_credits) if args.approved_max_credits is not None else None
        ),
        "approval_reference": args.approval_reference.strip() or None,
        "dry_run": bool(args.dry_run),
    }
    if args.dry_run:
        print(json.dumps(plan, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    try:
        _validate_local_secret_file()
        runner = _resolve_runner()
    except (FileNotFoundError, ValueError) as exc:
        parser.error(str(exc))

    invocation = [sys.executable, str(runner), args.command, *args.command_args]
    if classification == "billable":
        _append_ledger({"event": "started", "timestamp": _timestamp(), **plan})

    completed = subprocess.run(invocation, cwd=ROOT, env=os.environ.copy(), check=False)

    if classification == "billable":
        _append_ledger(
            {
                "event": "finished",
                "timestamp": _timestamp(),
                "command": args.command,
                "estimated_credits": str(args.estimated_credits),
                "approved_max_credits": str(args.approved_max_credits),
                "exit_code": completed.returncode,
            }
        )
    return int(completed.returncode)


if __name__ == "__main__":
    raise SystemExit(main())
