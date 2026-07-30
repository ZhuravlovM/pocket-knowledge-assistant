"""
app/rag_chat.py — interactive RAG documentation chatbot.

Usage:
    python -m app.rag_chat [--index data/index] [--top-k 10]
"""

from __future__ import annotations

import argparse
import re
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
    return min(max(terminal_width - 2, 1), MAX_LINE_WIDTH)


# ── Output ─────────────────────────────────────────────────────────────────────


_BLOCKQUOTE_PREFIX = re.compile(r"^\s*(?:>\s?)+")
_LIST_PREFIX = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")


def _wrap_line(line: str, width: int) -> str:
    """Wrap a single prose line, keeping its Markdown prefix and hard break."""
    # Indented code, table rows and headings must not be re-flowed at all.
    if line.startswith(("    ", "\t")) or line.lstrip().startswith(("|", "#")):
        return line

    hard_break = line.endswith("  ") and line.strip()
    body = line.rstrip()

    match = _BLOCKQUOTE_PREFIX.match(body) or _LIST_PREFIX.match(body)
    if match:
        prefix = match.group(0)
        # A blockquote marker must repeat on every line; a list marker must not.
        subsequent = prefix if prefix.lstrip().startswith(">") else " " * len(prefix)
    else:
        prefix = subsequent = body[: len(body) - len(body.lstrip())]

    wrapped = textwrap.fill(
        body[len(prefix) :],
        width=width,
        initial_indent=prefix,
        subsequent_indent=subsequent,
        break_long_words=False,
        break_on_hyphens=False,
    )
    return f"{wrapped}  " if hard_break else wrapped


def _wrap_preserving_structure(text: str, width: int) -> str:
    lines = text.split("\n")
    out = []
    in_code_block = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_code_block = not in_code_block
            out.append(line)
        elif in_code_block or not line.strip() or len(line) <= width:
            out.append(line)
        else:
            out.append(_wrap_line(line, width))
    return "\n".join(out)


def print_response(response) -> None:
    width = _wrap_width()
    text = response.response or ""
    wrapped = _wrap_preserving_structure(text, width)
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
    try:
        HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
        if HISTORY_FILE.exists():
            readline.read_history_file(HISTORY_FILE)
    except OSError as e:
        log.warning("Query history unavailable, continuing without it: %s", e)

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

        try:
            readline.write_history_file(HISTORY_FILE)
        except OSError as e:
            log.warning("Could not persist query history: %s", e)

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
