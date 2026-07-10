# config/ — Settings Reference

Two files control all runtime behavior. Edit them directly; no code changes needed.

```
config/
├── config.yaml      # models, paths, RAG/Ollama parameters
└── prompts.yaml     # system + query prompt templates
```

Restart the app after any change. **Rebuild the index** (`run.sh` → 1) if you
change `models.embed` or any chunking-related setting — embeddings from a
different model are not compatible with an existing index.

---

## config.yaml

### `paths`

| Key | Purpose |
|---|---|
| `documents` | Source documents directory (input to indexing) |
| `index` | Where the vector index is persisted |
| `prompts` | Path to `prompts.yaml` |
| `database` | Reserved for future SQLite memory feature (not yet used) |
| `cache` | Chat history, misc runtime cache |
| `logs` | `assistant.log` location |

Rarely need to change these unless you're relocating data outside the repo
(e.g. a mounted drive for a large document set).

### `models`

```yaml
models:
  llm: qwen2.5:3b-instruct
  embed: bge-m3
  timeout: 300.0
```

| Key | Purpose | Tuning notes |
|---|---|---|
| `llm` | Ollama model tag used for answering | Bigger model = better reasoning/fewer hallucinations, but slower. `qwen2.5:3b-instruct` is a good CPU-friendly default; `qwen2.5:7b-instruct` or `llama3.1:8b` noticeably improve answer quality if you have the RAM/CPU (or a GPU) for it. Must be pulled via `ollama pull <tag>` first. |
| `embed` | Ollama model used to embed documents & queries | `bge-m3` is a strong general-purpose multilingual embedder. Changing this **requires a full index rebuild**. |
| `timeout` | Seconds before an Ollama request is aborted | Currently `300.0` — generous. With `response_mode: compact` you'll typically need far less than this since it makes fewer sequential LLM calls than `refine`; feel free to lower it (e.g. 60–120) if you want failures to surface quickly instead of hanging. |

### `ollama`

```yaml
ollama:
  num_ctx: 2048
  num_batch: 256
  num_thread: 5
  temperature: 0.2
```

| Key | Purpose | Tuning notes |
|---|---|---|
| `num_ctx` | Context window (tokens) available to the model | Must be large enough to hold: system prompt + retrieved chunks (`top_k` × chunk size) + question + answer. Currently `2048` with `top_k: 5` — this is on the tight side; if answers seem to ignore some retrieved chunks or get cut off, try `4096` first. Larger values use more RAM and are slower. |
| `num_batch` | Prompt tokens processed per batch | Higher can speed up prompt processing on capable hardware; too high can exhaust RAM. 256–512 is a reasonable range for CPU. |
| `num_thread` | CPU threads used for inference | Set to your physical core count (not hyperthreads) for best throughput. Leave 1–2 cores free if you're also running other work. |
| `temperature` | Randomness of generation (0.0–1.0+) | Currently `0.2` — good for a documentation assistant, since you want faithful, deterministic answers grounded in retrieved text rather than creative variation. Raise only if answers feel too terse/robotic; keep below ~0.4 to avoid drifting from the source material. |

Run **Benchmark** (`run.sh` → 4) to auto-tune `num_ctx`/`num_batch`/`num_thread`/`temperature`
for your specific hardware via Optuna, then copy the winning values here.

### `rag`

```yaml
rag:
  top_k: 5
  response_mode: compact
```

| Key | Purpose | Tuning notes |
|---|---|---|
| `top_k` | Number of document chunks retrieved per query | Currently `5`. Higher = more context/coverage but slower generation and higher chance of irrelevant chunks diluting the answer. Increase if answers are missing information you know is in the documents; decrease if answers ramble or mix unrelated topics. |
| `response_mode` | How retrieved chunks are turned into an answer | See below. |

**`response_mode` options** (LlamaIndex `ResponseMode` enum, `llama-index-core==0.14.23`):

| Mode | What it does | Best use case | Speed | Quality | Streams cleanly? |
|---|---|---|---|---|---|
| `refine` | One LLM call per chunk, each refining the previous answer | Detailed, nuanced answers where every chunk matters | Slowest (N calls for N chunks) | Highest — most thorough | **No (unreliable)** — the final chunk's call often returns the whole answer at once instead of true tokens; known LlamaIndex issue |
| `compact` *(current)* | Concatenates chunks to fill the context window first, then refines across fewer, larger calls | Same use case as `refine`, when you want less latency and reliable streaming | Faster than `refine` (fewer LLM calls) | Comparable to `refine` in most cases | Yes — this is the documented/tested streaming path |
| `tree_summarize` | Recursively summarizes chunks in a tree until one final answer remains | Broad "summarize everything" questions across many chunks | Slow — multiple LLM calls, tree depth grows with chunk count | High for broad synthesis, weaker for narrow factual lookups | Partial — internal calls don't map to one smooth stream |
| `simple_summarize` | Merges all chunks into one and makes a single LLM call; fails if it doesn't fit the context window | Small `top_k` / small documents where everything fits at once | Fastest (1 call) | Lower — no iteration, drops info that doesn't fit | Yes |
| `accumulate` | Synthesizes a separate response per chunk, then concatenates all of them | Rarely useful for Q&A — produces N separate mini-answers, not one coherent answer | Slow (N calls) | Low for Q&A — fragmented, not merged | No — multiple disjoint answers, not one stream |
| `compact_accumulate` | Same as `accumulate` but compacts chunks first to reduce calls | Same caveat as `accumulate` | Faster than `accumulate` | Same caveat as `accumulate` | No |
| `generation` | Ignores retrieved context entirely — just asks the LLM to generate a response | Not useful for a RAG assistant — effectively disables retrieval | Fastest | N/A — not grounded in your documents | Yes, but pointless here |
| `context_only` | Returns the raw retrieved chunks, no LLM synthesis at all | Debugging retrieval — inspect what got retrieved without spending a generation call | Instant (no LLM call) | N/A — no answer generated | N/A |
| `no_text` | Returns nodes only, no response text | Same debugging use case as `context_only` | Instant | N/A | N/A |

Use `context_only` temporarily if you want to check exactly which 5 chunks
are being retrieved for a question, without waiting on the LLM.

---

## prompts.yaml

Your current file:

| Key | Purpose |
|---|---|
| `system` | Sets the assistant's persona, tone, and hard rules. |
| `query` | Template wrapping each user question before it's sent to the query engine. Must contain `{question}` — it's filled in via `.format(question=...)` in `rag_chat.py`. |

### General tips

- **Keep the system prompt short and directive.** Long, meandering system prompts eat into `num_ctx` (currently `2048` — already tight once you add 5 retrieved chunks) and can dilute instruction-following on a 3B model.
- **Match tone to audience.** e.g. *"Answer concisely, in plain language, avoiding jargon"* vs. *"Provide detailed technical answers with exact configuration values"* — tune based on who's asking.
- **Iterate against real questions.** Change one line, ask the same 3–5 representative questions, compare. Small prompt wording changes can have an outsized effect on smaller local models like `qwen2.5:3b-instruct`.