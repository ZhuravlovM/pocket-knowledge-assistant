"""
app/status.py — prints project and system status.

Usage:
    python -m app.status
"""

from __future__ import annotations

import shlex
import subprocess
from pathlib import Path

from app.config import cfg


def _run(cmd: str) -> str:
    """Returns the stripped stdout of a shell command, or "" if it fails."""
    try:
        return subprocess.check_output(
            cmd, shell=True, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except subprocess.CalledProcessError:
        return ""


def _ollama_running() -> bool:
    """Returns True if the Ollama daemon answers a model listing."""
    return bool(_run("ollama list"))


def _index_ready() -> bool:
    """Returns True if the configured index directory exists and is non-empty."""
    p = Path(cfg.paths.index)
    return p.exists() and any(p.iterdir())


def _doc_files() -> list[Path]:
    """Returns every file under the configured documents directory."""
    p = Path(cfg.paths.documents)
    if not p.exists():
        return []
    return [f for f in p.rglob("*") if f.is_file()]


def print_status() -> None:
    """Prints Python, Ollama, document, index and config status as a report."""
    ok = "\033[32m✓\033[0m"
    fail = "\033[31m✗\033[0m"
    warn = "\033[33m⚠\033[0m"

    print()
    # Python
    pyver = _run("python3 --version")
    print(f"  {ok} {pyver}")

    # Ollama
    if _ollama_running():
        print(f"  {ok} Ollama is running")
        loaded = _run("ollama ps 2>/dev/null | tail -n +2")
        available = _run("ollama list 2>/dev/null | tail -n +2")
        if loaded:
            print("  → Loaded models:")
            for line in loaded.splitlines():
                print(f"      {line}")
        if available:
            print("  → Available models:")
            for line in available.splitlines():
                print(f"      {line}")
    else:
        print(f"  {fail} Ollama is not responding")

    print()

    # Documents
    files = _doc_files()
    if files:
        print(f"  {ok} Documents: {len(files)} file(s) in {cfg.paths.documents}/")
        for f in files[:5]:
            print(f"      {f}")
        if len(files) > 5:
            print("      ...")
    else:
        print(f"  {warn} No documents found in {cfg.paths.documents}/")

    print()

    # Index
    if _index_ready():
        size = _run(f"du -sh {shlex.quote(cfg.paths.index)} 2>/dev/null | cut -f1")
        print(f"  {ok} Index ready ({cfg.paths.index}/ — {size})")
    else:
        print(f"  {warn} Index not built")

    print()

    # Config
    print(f"  → LLM model:   {cfg.models.llm}")
    print(f"  → Embed model: {cfg.models.embed}")
    print(f"  → top_k:       {cfg.rag.top_k}")
    print()


def main() -> None:
    print_status()


if __name__ == "__main__":
    main()
