"""
app/llm.py — initializes and returns the Ollama LLM instance.
"""

from __future__ import annotations

from llama_index.llms.ollama import Ollama

from app.config import cfg


def get_llm() -> Ollama:
    """Returns a configured Ollama LLM instance."""
    return Ollama(
        model=cfg.models.llm,
        request_timeout=cfg.models.timeout,
        additional_kwargs={
            "num_ctx": cfg.ollama.num_ctx,
            "num_batch": cfg.ollama.num_batch,
            "num_thread": cfg.ollama.num_thread,
            "temperature": cfg.ollama.temperature,
        },
    )
