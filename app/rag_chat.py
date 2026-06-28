"""
app/rag_chat.py — interactive RAG documentation chatbot.

Usage:
    python -m app.rag_chat [--index data/index] [--top-k 10]
"""

from __future__ import annotations

import argparse

from app.config import cfg
from app.prompts import load_prompts
from app.rag import configure_settings, get_query_engine, load_index
from app.utils import get_logger

log = get_logger(__name__)


# ── Output ─────────────────────────────────────────────────────────────────────


def print_response(response) -> None:
    print(f"\n{response.response}\n")

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
    print(f"\n{'═' * 60}")
    print("  Documentation Assistant  |  'exit' to quit")
    print(f"{'═' * 60}\n")

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

        response = query_engine.query(query_template.format(question=question))
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
