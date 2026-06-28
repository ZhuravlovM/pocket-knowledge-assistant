"""
app/prompts.py — loads system and query prompts from config/prompts.yaml.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

from app.config import cfg


@dataclass(frozen=True)
class Prompts:
    system: str
    query: str


def load_prompts(path: str | None = None) -> Prompts:
    """Loads prompts from prompts.yaml (path from config by default)."""
    prompts_path = Path(path or cfg.paths.prompts)
    if not prompts_path.exists():
        raise FileNotFoundError(f"Prompts file not found: {prompts_path}")

    with open(prompts_path, encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    return Prompts(
        system=raw["system"].strip(),
        query=raw["query"].strip(),
    )
