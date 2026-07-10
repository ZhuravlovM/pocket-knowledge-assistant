"""
app/rag_chat.py — interactive RAG documentation chatbot.

Usage:
    python -m app.rag_chat [--index data/index] [--top-k 10]
"""

from __future__ import annotations

import argparse
import readline  # noqa: F401 — enables arrow keys / history for input()
import shutil
import textwrap
from pathlib import Path

from app.config import cfg
from app.prompts import load_prompts
from app.rag import configure_settings, get_query_engine, load_index
from app.utils import Spinner, get_logger

log = get_logger(__name__)

HISTORY_FILE = Path(cfg.paths.cache) / "query_history"

MAX_LINE_WIDTH = 100


def _wrap_width() -> int:
    terminal_width = shutil.get_terminal_size(fallback=(100, 20)).columns
    return max(min(terminal_width - 2, MAX_LINE_WIDTH), 20)


# ── Output ─────────────────────────────────────────────────────────────────────


def print_response(response) -> None:
    width = _wrap_width()
    paragraphs = response.response.split("\n\n")
    wrapped = "\n\n".join(textwrap.fill(p, width=width) for p in paragraphs)
    print(f"\n{wrapped}\n")

    if not response.source_nodes:
        return

    print("Sources:")
    seen = set()
    for node in response.source_nodes:
        file_name = node.metadata.get("file_name", "unknown")
        if file_name in seen:
            continue
        seen.add(file_name)
        print(f"📄 {file_name}")
    print()


# ── Chat loop ──────────────────────────────────────────────────────────────────


def run_chat(query_engine, query_template: str) -> None:
    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    if HISTORY_FILE.exists():
        readline.read_history_file(HISTORY_FILE)

    print(f"\n{'═' * 75}")
    print("  Documentation Assistant  |  'exit' to quit  |  Ctrl+C to cancel a query ")
    print(f"{'═' * 75}\n")

    while True:
        try:
            raw = input("🧙 Ask a question > ")
            question = raw.encode("utf-8", errors="ignore").decode("utf-8").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

        if not question:
            continue
        if question.lower() in ("exit", "q", "quit"):
            break

        readline.write_history_file(HISTORY_FILE)

        try:
            with Spinner("Thinking"):
                response = query_engine.query(query_template.format(question=question))
        except KeyboardInterrupt:
            print("\n  ⚠ Query cancelled.\n")
            continue

        print_response(response)


# ── CLI ────────────────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="RAG chat for local documentation")
    parser.add_argument("--index", default=cfg.paths.index)
    parser.add_argument("--top-k", type=int, default=cfg.rag.top_k)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    configure_settings()
    prompts = load_prompts()
    index = load_index(args.index)
    engine = get_query_engine(index, args.top_k)
    run_chat(engine, prompts.query)


if __name__ == "__main__":
    main()
