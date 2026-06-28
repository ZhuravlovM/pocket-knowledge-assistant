"""
app/embeddings.py — initializes and returns the Ollama embedding model.
"""

from __future__ import annotations

from llama_index.embeddings.ollama import OllamaEmbedding

from app.config import cfg


def get_embed_model() -> OllamaEmbedding:
    """Returns a configured OllamaEmbedding instance."""
    return OllamaEmbedding(model_name=cfg.models.embed)
