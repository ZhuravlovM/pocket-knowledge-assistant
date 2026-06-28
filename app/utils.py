"""
app/utils.py — shared utility functions.
"""

from __future__ import annotations

import logging
import sys
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
