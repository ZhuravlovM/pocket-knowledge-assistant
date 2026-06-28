"""
app/config.py — loads and exposes project configuration from config/config.yaml.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import yaml

_CONFIG_PATH = Path(__file__).parent.parent / "config" / "config.yaml"


@dataclass(frozen=True)
class PathsConfig:
    documents: str
    index: str
    prompts: str
    database: str
    cache: str
    logs: str


@dataclass(frozen=True)
class ModelsConfig:
    llm: str
    embed: str
    timeout: float


@dataclass(frozen=True)
class OllamaConfig:
    num_ctx: int
    num_batch: int
    num_thread: int
    temperature: float


@dataclass(frozen=True)
class RagConfig:
    top_k: int
    response_mode: str


@dataclass(frozen=True)
class AppConfig:
    paths: PathsConfig
    models: ModelsConfig
    ollama: OllamaConfig
    rag: RagConfig


def load_config(path: Path = _CONFIG_PATH) -> AppConfig:
    """Loads config.yaml and returns a typed AppConfig."""
    with open(path, encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    return AppConfig(
        paths=PathsConfig(**raw["paths"]),
        models=ModelsConfig(**raw["models"]),
        ollama=OllamaConfig(**raw["ollama"]),
        rag=RagConfig(**raw["rag"]),
    )


# Module-level singleton — import this everywhere
cfg: AppConfig = load_config()
