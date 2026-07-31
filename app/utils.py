"""
app/utils.py — shared utility functions.
"""

from __future__ import annotations

import itertools
import logging
import logging.handlers
import sys
import threading
from pathlib import Path

from app.config import cfg

# ── Logging ────────────────────────────────────────────────────────────────────

_LOGGER_ROOT = "app"
_LOG_MAX_BYTES = 1_000_000
_LOG_BACKUP_COUNT = 3


class _ConsoleFilter(logging.Filter):
    """Drops records marked file_only — used by die(), which prints its own text."""

    def filter(self, record: logging.LogRecord) -> bool:
        return not getattr(record, "file_only", False)


def _configure_logging() -> None:
    """Attaches the rotating file and console handlers to the 'app' logger once.

    Handlers live only on this parent logger; per-module loggers propagate to it
    and keep no handlers of their own.
    """
    parent = logging.getLogger(_LOGGER_ROOT)
    if parent.handlers:
        return

    log_path = Path(cfg.paths.logs)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    parent.setLevel(logging.INFO)
    # Handlers are attached here, so don't hand records to the root logger too —
    # anything calling logging.basicConfig() would otherwise duplicate every line.
    parent.propagate = False

    fh = logging.handlers.RotatingFileHandler(
        log_path,
        maxBytes=_LOG_MAX_BYTES,
        backupCount=_LOG_BACKUP_COUNT,
        encoding="utf-8",
    )
    fh.setFormatter(
        logging.Formatter("%(asctime)s  %(levelname)-8s  %(name)s — %(message)s")
    )
    parent.addHandler(fh)

    # Terse, and on stderr so stdout stays clean for CLI/REPL output.
    ch = logging.StreamHandler(sys.stderr)
    ch.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
    ch.addFilter(_ConsoleFilter())
    parent.addHandler(ch)

    # Chatty on every Ollama request if anything ever configures the root logger.
    logging.getLogger("httpx").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """Returns a logger under the 'app' namespace, configuring logging on first use."""
    _configure_logging()

    if name == "__main__":
        # `python -m app.rag_chat` reports __name__ as "__main__" — recover the
        # module name so records stay inside the 'app' namespace.
        name = Path(sys.argv[0]).stem or "main"
    if name != _LOGGER_ROOT and not name.startswith(f"{_LOGGER_ROOT}."):
        name = f"{_LOGGER_ROOT}.{name}"

    return logging.getLogger(name)


def die(message: str, code: int = 1) -> None:
    """Records the error in the log file, prints it to stderr, and exits."""
    get_logger(__name__).error(message, extra={"file_only": True})
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
