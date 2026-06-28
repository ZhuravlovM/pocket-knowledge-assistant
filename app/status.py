"""
app/status.py — prints project and system status.

Usage:
    python -m app.status
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from app.config import cfg


def _run(cmd: str) -> str:
    try:
        return subprocess.check_output(
            cmd, shell=True, text=True, stderr=subprocess.DEVNULL
        ).strip()
    except subprocess.CalledProcessError:
        return ""


def _ollama_running() -> bool:
    return bool(_run("ollama list"))


def _index_ready() -> bool:
    p = Path(cfg.paths.index)
    return p.exists() and any(p.iterdir())


def _doc_count() -> int:
    p = Path(cfg.paths.documents)
    if not p.exists():
        return 0
    return sum(1 for _ in p.rglob("*") if _.is_file())


def print_status() -> None:
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
    count = _doc_count()
    if count:
        print(f"  {ok} Documents: {count} file(s) in {cfg.paths.documents}/")
        files = list(Path(cfg.paths.documents).rglob("*"))
        files = [f for f in files if f.is_file()]
        for f in files[:5]:
            print(f"      {f}")
        if len(files) > 5:
            print("      ...")
    else:
        print(f"  {warn} No documents found in {cfg.paths.documents}/")

    print()

    # Index
    if _index_ready():
        size = _run(f"du -sh {cfg.paths.index} 2>/dev/null | cut -f1")
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
