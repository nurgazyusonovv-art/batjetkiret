import json
import logging
import sys
from datetime import datetime, timezone

# Request context attached via `extra=` by the request logging middleware.
_CONTEXT_FIELDS = (
    "service",
    "request_id",
    "method",
    "path",
    "status_code",
    "duration_ms",
    "client_ip",
)

# Loggers that configure handlers of their own.
_MANAGED_LOGGERS = (
    "uvicorn",
    "uvicorn.error",
    "uvicorn.access",
    "gunicorn.error",
    "gunicorn.access",
)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        for field in _CONTEXT_FIELDS:
            value = getattr(record, field, None)
            if value is not None:
                payload[field] = value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False)

class PlainFormatter(logging.Formatter):
    """Human-readable lines with the request context appended when present."""

    def format(self, record: logging.LogRecord) -> str:
        base = super().format(record)
        context = " ".join(
            f"{field}={getattr(record, field)}"
            for field in _CONTEXT_FIELDS
            if getattr(record, field, None) is not None
        )
        return f"{base} {context}" if context else base


def configure_logging(*, level: str = "INFO", json_logs: bool = True) -> None:
    """Send every log record to stdout through a single formatter.

    Without this the root logger has no handler at all, so `logger.info(...)`
    is dropped and warnings fall through to `logging.lastResort` as unformatted
    stderr text — which is how production ended up with no application logs.
    """
    root_logger = logging.getLogger()
    if getattr(root_logger, "_batken_express_configured", False):
        return

    try:
        root_logger.setLevel(level.upper())
    except ValueError:
        root_logger.setLevel(logging.INFO)

    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(
        JsonFormatter()
        if json_logs
        else PlainFormatter("%(asctime)s %(levelname)-8s %(name)s %(message)s")
    )

    # Exactly one handler for the process, so no line is printed twice.
    for existing in list(root_logger.handlers):
        root_logger.removeHandler(existing)
    root_logger.addHandler(handler)

    # uvicorn and gunicorn ship their own handlers; left alone they would print
    # a second, differently formatted copy of every line they emit.
    for name in _MANAGED_LOGGERS:
        managed = logging.getLogger(name)
        managed.handlers.clear()
        managed.propagate = True

    root_logger._batken_express_configured = True
