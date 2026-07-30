"""
app/benchmark.py — Ollama parameter optimization via Optuna.

Usage:
    python -m app.benchmark [--trials 20]
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

import optuna
import requests

from app.config import cfg
from app.utils import get_logger

optuna.logging.set_verbosity(optuna.logging.WARNING)
log = get_logger(__name__)

OLLAMA_URL = "http://localhost:11434/api/generate"
RESULTS_FILE = "data/benchmark_results.json"

BENCHMARK_PROMPT = (
    "Explain step by step how to configure a network monitoring agent. "
    "Include installation, configuration, and verification steps."
)


# ── Benchmark ─────────────────────────────────────────────────────────────────


def run_benchmark(model: str, params: dict) -> dict:
    """Runs one generation against Ollama's HTTP API and returns timing metrics.

    Bypasses LlamaIndex so that raw Ollama options can be varied per call.
    """
    payload = {
        "model": model,
        "prompt": BENCHMARK_PROMPT,
        "stream": False,
        "options": params,
    }

    t0 = time.monotonic()
    resp = requests.post(OLLAMA_URL, json=payload, timeout=300)
    resp.raise_for_status()
    data = resp.json()
    wall_time = time.monotonic() - t0

    eval_count = data.get("eval_count", 1)
    eval_duration = data.get("eval_duration", 1)
    load_duration = data.get("load_duration", 0)
    prompt_eval = data.get("prompt_eval_duration", 0)

    tokens_per_sec = eval_count / (eval_duration / 1e9) if eval_duration else 0
    first_token_ms = (load_duration + prompt_eval) / 1e6

    return {
        "tokens_per_sec": round(tokens_per_sec, 2),
        "first_token_ms": round(first_token_ms, 1),
        "wall_time_sec": round(wall_time, 1),
        "eval_count": eval_count,
    }


# ── Optuna ────────────────────────────────────────────────────────────────────


def make_objective(model: str):
    """Returns an Optuna objective that tunes Ollama options for the given model.

    The score favours throughput and penalises latency
    (tokens_per_sec - first_token_ms * 0.005); failed runs are pruned.
    """

    def objective(trial: optuna.Trial) -> float:
        params = {
            "num_ctx": trial.suggest_categorical("num_ctx", [2048, 4096]),
            "num_batch": trial.suggest_categorical("num_batch", [128, 256, 512]),
            "num_thread": trial.suggest_int("num_thread", 2, 8),
            "num_gpu": 0,
            "temperature": trial.suggest_float("temperature", 0.0, 0.8, step=0.1),
        }
        try:
            metrics = run_benchmark(model, params)
        except Exception as e:
            raise optuna.TrialPruned(f"Benchmark failed: {e}")

        for k, v in metrics.items():
            trial.set_user_attr(k, v)

        return metrics["tokens_per_sec"] - metrics["first_token_ms"] * 0.005

    return objective


# ── Results ───────────────────────────────────────────────────────────────────


def print_results(study: optuna.Study) -> None:
    """Prints the best trial's parameters and metrics as a table."""
    best = study.best_trial
    print("\n" + "─" * 55)
    print(f"  Best parameters (trial #{best.number}):")
    print("─" * 55)
    for k, v in best.params.items():
        print(f"  {k:<20} {v}")
    print("─" * 55)
    print(f"  tokens/sec   {best.user_attrs.get('tokens_per_sec', '?')}")
    print(f"  first token  {best.user_attrs.get('first_token_ms', '?')} ms")
    print(f"  wall time    {best.user_attrs.get('wall_time_sec', '?')} sec")
    print("─" * 55)


def save_results(study: optuna.Study, path: str) -> None:
    """Writes the best parameters plus every completed trial to path as JSON."""
    best = study.best_trial
    data = {
        "best_params": best.params,
        "best_score": best.value,
        "best_metrics": best.user_attrs,
        "all_trials": [
            {
                "number": t.number,
                "params": t.params,
                "value": t.value,
                "attrs": t.user_attrs,
            }
            for t in study.trials
            if t.state == optuna.trial.TrialState.COMPLETE
        ],
    }
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(data, indent=2), encoding="utf-8")
    log.info("Results saved to %s", path)


# ── CLI ────────────────────────────────────────────────────────────────────────


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Optimize Ollama parameters")
    parser.add_argument("--trials", type=int, default=20)
    parser.add_argument("--output", default=RESULTS_FILE)
    parser.add_argument("--db", default="sqlite:///data/benchmark.db")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model = cfg.models.llm

    print(f"\n  Model:   {model}")
    print(f"  Trials:  {args.trials}\n")

    study = optuna.create_study(
        direction="maximize",
        study_name="ollama_tune",
        storage=args.db,
        load_if_exists=True,
    )
    study.optimize(make_objective(model), n_trials=args.trials, show_progress_bar=True)
    print_results(study)
    save_results(study, args.output)

    print("\n  Apply best parameters in config/config.yaml (ollama section):")
    for k, v in study.best_params.items():
        print(f"    {k}: {v}")
    print()


if __name__ == "__main__":
    main()
