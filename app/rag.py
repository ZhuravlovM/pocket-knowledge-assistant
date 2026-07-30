"""
app/rag.py — RAG index building, persistence, and query engine creation.
"""

from __future__ import annotations

import time
from pathlib import Path

from llama_index.core import (
    Settings,
    SimpleDirectoryReader,
    StorageContext,
    VectorStoreIndex,
    load_index_from_storage,
)

from app.config import cfg
from app.embeddings import get_embed_model
from app.llm import get_llm
from app.prompts import load_prompts
from app.utils import die, get_logger

log = get_logger(__name__)


def configure_settings() -> None:
    """Applies LLM and embedding model to global LlamaIndex Settings.

    The system prompt from config/prompts.yaml is attached to the LLM here; a
    missing or unreadable prompts file is logged and the LLM runs without it.
    """
    system_prompt = None
    try:
        system_prompt = load_prompts().system
    except (OSError, KeyError) as e:
        log.warning("System prompt unavailable, continuing without it: %s", e)

    Settings.llm = get_llm(system_prompt=system_prompt)
    Settings.embed_model = get_embed_model()


# ── Index ──────────────────────────────────────────────────────────────────────


def load_documents(docs_dir: str | None = None):
    """Reads every supported file under docs_dir recursively.

    Fatal (via die) if the directory is missing, empty, or yields no documents.
    """
    path = Path(docs_dir or cfg.paths.documents)
    if not path.exists():
        die(f"Documents directory not found: {path}")
    if not any(path.iterdir()):
        die(f"Documents directory is empty: {path}")

    log.info("Loading documents from '%s'...", path)
    documents = SimpleDirectoryReader(str(path), recursive=True).load_data()

    if not documents:
        die("No documents loaded. Check supported file formats.")

    log.info("Loaded %d document(s).", len(documents))
    return documents


def build_index(documents, index_dir: str | None = None) -> VectorStoreIndex:
    """Embeds documents into a vector index and persists it to index_dir.

    Requires configure_settings() to have run — embedding uses Settings.embed_model.
    """
    path = Path(index_dir or cfg.paths.index)
    path.mkdir(parents=True, exist_ok=True)

    log.info("Building index...")
    t0 = time.monotonic()
    index = VectorStoreIndex.from_documents(documents, show_progress=True)
    log.info("Index built in %.1f seconds.", time.monotonic() - t0)

    index.storage_context.persist(persist_dir=str(path))
    log.info("Index saved to '%s'.", path)
    return index


def load_index(index_dir: str | None = None) -> VectorStoreIndex:
    """Loads a previously persisted index; fatal (via die) if it does not exist.

    The stored embeddings only match the embedding model they were built with —
    changing models.embed in config.yaml requires a full rebuild.
    """
    path = Path(index_dir or cfg.paths.index)
    if not path.exists():
        die(f"Index directory not found: {path}. Run build_index first.")

    storage_context = StorageContext.from_defaults(persist_dir=str(path))
    return load_index_from_storage(storage_context)


def get_query_engine(index: VectorStoreIndex, top_k: int | None = None):
    """Returns a query engine retrieving top_k chunks, using cfg.rag.response_mode."""
    return index.as_query_engine(
        similarity_top_k=top_k or cfg.rag.top_k,
        response_mode=cfg.rag.response_mode,
    )
