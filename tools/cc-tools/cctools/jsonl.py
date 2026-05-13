"""Shared JSONL session reader for Claude Code transcripts."""
from __future__ import annotations

import json
import os
from collections.abc import Iterator
from pathlib import Path

DEFAULT_ROOT = Path.home() / ".claude" / "projects"


def session_files(root: Path | None = None) -> Iterator[Path]:
    base = root or DEFAULT_ROOT
    if not base.exists():
        return
    yield from base.rglob("*.jsonl")


def iter_events(path: Path) -> Iterator[dict]:
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def extract_usage(event: dict) -> dict | None:
    msg = event.get("message")
    if not isinstance(msg, dict):
        return None
    usage = msg.get("usage")
    if not isinstance(usage, dict):
        return None
    return {
        "model": msg.get("model"),
        "input": usage.get("input_tokens", 0) or 0,
        "output": usage.get("output_tokens", 0) or 0,
        "cache_read": usage.get("cache_read_input_tokens", 0) or 0,
        "cache_create": usage.get("cache_creation_input_tokens", 0) or 0,
        "timestamp": event.get("timestamp"),
        "session": event.get("sessionId"),
        "is_sidechain": event.get("isSidechain", False),
    }


# Anthropic public pricing (USD per 1M tokens) — approximate, May 2026
PRICING = {
    "opus": {"input": 15.0, "output": 75.0, "cache_read": 1.50, "cache_create": 18.75},
    "sonnet": {"input": 3.0, "output": 15.0, "cache_read": 0.30, "cache_create": 3.75},
    "haiku": {"input": 1.0, "output": 5.0, "cache_read": 0.10, "cache_create": 1.25},
}


def model_family(model: str | None) -> str:
    if not model:
        return "sonnet"
    m = model.lower()
    if "opus" in m:
        return "opus"
    if "haiku" in m:
        return "haiku"
    return "sonnet"


def cost_usd(usage: dict) -> float:
    p = PRICING[model_family(usage.get("model"))]
    return (
        usage["input"] * p["input"]
        + usage["output"] * p["output"]
        + usage["cache_read"] * p["cache_read"]
        + usage["cache_create"] * p["cache_create"]
    ) / 1_000_000


def extract_tool_uses(event: dict) -> list[str]:
    msg = event.get("message")
    if not isinstance(msg, dict):
        return []
    content = msg.get("content")
    if not isinstance(content, list):
        return []
    names = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "tool_use":
            name = block.get("name")
            if name:
                names.append(name)
    return names
