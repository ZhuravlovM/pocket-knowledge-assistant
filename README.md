# Pocket Knowledge Assistant
 
A local AI assistant that answers questions about your documents.
Runs entirely offline using [Ollama](https://ollama.com) and [LlamaIndex](https://www.llamaindex.ai).

## Requirements

- Python 3.11+
- [Ollama](https://ollama.com) installed and running

## Quick start

```bash
# 1. Install dependencies and pull models
./scripts/setup.sh

# 2. Add your documents
cp /your/docs/* data/documents/

# 3. Launch
./run.sh
```

## Project structure

```
├── run.sh                  # Main menu
│
├── config/
│   ├── config.yaml         # All settings (models, paths, RAG parameters)
│   └── prompts.yaml        # System and query prompts
│
├── app/
│   ├── config.py           # Loads config.yaml → typed AppConfig
│   ├── llm.py              # Ollama LLM factory
│   ├── embeddings.py       # Ollama embedding factory
│   ├── rag.py              # Index build / load / query engine
│   ├── prompts.py          # Loads prompts.yaml
│   ├── utils.py            # Logger, helpers
│   ├── build_index.py      # CLI: build vector index
│   ├── rag_chat.py         # CLI: interactive chat
│   ├── benchmark.py        # Optuna parameter tuning
│   └── status.py           # System and project status
│
├── scripts/
│   ├── lib/                # Shared shell libraries
│   │   ├── common.sh       # Single entry point — sources the rest
│   │   ├── ui.sh           # Colors, logging, ok/fail/info/warn, spinner
│   │   ├── config.sh       # Reads config/config.yaml into bash
│   │   ├── python.sh       # Python version check, venv management
│   │   └── system.sh       # Ollama & dependency checks
│   ├── setup.sh            # Install dependencies, pull models, create dirs
│   ├── uninstall.sh        # Remove models, index, venv, data
│   └── check_system.sh     # Pre-flight dependency check
│
├── data/
│   ├── documents/          # Your source documents (PDF, TXT, MD, DOCX…)
│   ├── index/              # Vector index (auto-generated)
│   └── cache/              # Cache, incl. chat history
│
├── logs/
│ 
└── tests/
```

## Menu options

| # | Action | Description |
|---|--------|-------------|
| 1 | Build index | Indexes documents in `data/documents/` |
| 2 | Start chat | Interactive Q&A against the index |
| 3 | Status | Shows models, doc count, index state |
| 4 | Benchmark | Tunes Ollama parameters via Optuna |
| 5 | Setup | Runs `setup.sh` |
| 6 | Uninstall | Removes models, index, venv, data |

## Configuration

All settings live in `config/config.yaml`:

```yaml
models:
  llm: qwen2.5:3b-instruct   # change to any Ollama model
  embed: bge-m3

ollama:
  num_ctx: 2048
  num_batch: 256
  num_thread: 5
  temperature: 0.3

rag:
  top_k: 10
  response_mode: compact
```

After editing, rebuild the index if you changed the embedding model.

## Supported document formats

PDF, TXT, MD, DOCX, HTML, CSV, EPUB and more via LlamaIndex readers.

## Running components directly

```bash
# Build index
python -m app.build_index --docs data/documents --index data/index

# Chat
python -m app.rag_chat --index data/index --top-k 10

# Status
python -m app.status

# Benchmark
python -m app.benchmark --trials 20
```

## Tuning

Run **Benchmark** (menu option 4) to find optimal `num_ctx`, `num_batch`,
`num_thread`, and `temperature` for your hardware. Results are saved to
`data/benchmark_results.json`. Apply the best values to `config/config.yaml`.

## Uninstall

```bash
./scripts/uninstall.sh
```

Options: remove index only, remove specific Ollama models, remove `.venv`,
remove all data, or full uninstall.

## Notes

- SQLite memory (`data/assistant.db`) is reserved for a future update.
- Documents in `data/documents/` are never deleted by `uninstall.sh`.
