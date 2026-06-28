"""
app/build_index.py — builds and persists the vector index from local documents.

Usage:
    python -m app.build_index [--docs data/documents] [--index data/index]
"""

from __future__ import annotations

import argparse

from app.config import cfg
from app.rag import build_index, configure_settings, load_documents


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build RAG vector index")
    parser.add_argument("--docs", default=cfg.paths.documents)
    parser.add_argument("--index", default=cfg.paths.index)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    configure_settings()
    documents = load_documents(args.docs)
    build_index(documents, args.index)


if __name__ == "__main__":
    main()
