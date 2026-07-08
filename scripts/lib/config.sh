#!/usr/bin/env bash
# scripts/lib/config.sh — reads project configuration (config/config.yaml via
# app.config.cfg) into bash, with sane fallbacks if Python/deps aren't ready yet.

# cfg_get "models.llm" "qwen2.5:3b-instruct"
cfg_get() {
    local attr="$1" default="$2"
    python3 -c "from app.config import cfg; print(cfg.${attr})" 2>/dev/null || echo "$default"
}

cfg_llm_model()   { cfg_get "models.llm" "qwen2.5:3b-instruct"; }
cfg_embed_model() { cfg_get "models.embed" "bge-m3"; }
cfg_docs_dir()    { cfg_get "paths.documents" "data/documents"; }
cfg_index_dir()   { cfg_get "paths.index" "data/index"; }
cfg_top_k()       { cfg_get "rag.top_k" "10"; }

# Prints llm model on line 1, embed model on line 2 — used where both are
# needed together (e.g. pulling/removing models).
cfg_models() {
    python3 -c "
from app.config import cfg
print(cfg.models.llm)
print(cfg.models.embed)
" 2>/dev/null || printf '%s\n%s\n' "qwen2.5:3b-instruct" "bge-m3"
}
