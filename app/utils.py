"""
app/utils.py — shared utility functions.
"""

from __future__ import annotations

import itertools
import logging
import sys
import threading
import time
from pathlib import Path

from app.config import cfg


def get_logger(name: str) -> logging.Logger:
    """Returns a logger writing to both stdout and the log file."""
    log_path = Path(cfg.paths.logs)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger(name)
    if logger.handlers:
        return logger  # already configured

    logger.setLevel(logging.INFO)
    fmt = logging.Formatter("%(asctime)s  %(levelname)-8s  %(name)s — %(message)s")

    # Console handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(fmt)
    logger.addHandler(ch)

    # File handler
    fh = logging.FileHandler(log_path, encoding="utf-8")
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    return logger


def die(message: str, code: int = 1) -> None:
    """Prints an error and exits."""
    print(f"[Error] {message}", file=sys.stderr)
    sys.exit(code)


class Spinner:
    """Animated status line for long-running calls (e.g. 'Thinking...').

    Usage:
        with Spinner("Thinking"):
            response = query_engine.query(question)
    """

    FRAMES = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

    def __init__(self, message: str = "Thinking", interval: float = 0.1) -> None:
        self.message = message
        self.interval = interval
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._spin, daemon=True)

    def _spin(self) -> None:
        for frame in itertools.cycle(self.FRAMES):
            if self._stop.is_set():
                break
            print(f"\r  {frame} {self.message}...", end="", flush=True)
            if self._stop.wait(self.interval):
                break
        # Clear the line on stop
        print("\r" + " " * (len(self.message) + 10) + "\r", end="", flush=True)

    def __enter__(self) -> "Spinner":
        self._thread.start()
        return self

    def __exit__(self, *exc_info) -> None:
        self._stop.set()
        self._thread.join()
