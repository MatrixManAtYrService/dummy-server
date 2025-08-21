"""Structured logging configuration using structlog."""

import logging
import sys

import structlog


def setup_logging() -> None:
    """Configure structlog with custom formatting."""
    # Configure structlog
    structlog.configure(
        processors=[
            # Add timestamp
            structlog.processors.TimeStamper(fmt="%H:%M:%S", utc=False),
            # Add log level
            structlog.processors.add_log_level,
            # Render as key-value pairs for console
            structlog.dev.ConsoleRenderer(colors=True),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        logger_factory=structlog.WriteLoggerFactory(file=sys.stdout),
        cache_logger_on_first_use=True,
    )

    # Also configure standard logging to use structlog
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=logging.INFO,
    )

    # Intercept uvicorn logs
    uvicorn_access = logging.getLogger("uvicorn.access")
    uvicorn_access.handlers = []
    uvicorn_access.propagate = True


def get_logger(name: str) -> structlog.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)
