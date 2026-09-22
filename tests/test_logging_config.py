import json
import logging

import pytest

from app.core.custom_logging import configure_logging


@pytest.fixture
def fresh_root():
    """Undo configure_logging so each test starts from a clean root logger."""
    root = logging.getLogger()
    saved_handlers = list(root.handlers)
    saved_level = root.level
    saved_flag = getattr(root, "_batken_express_configured", False)
    managed = {
        name: (list(logging.getLogger(name).handlers),
               logging.getLogger(name).propagate)
        for name in ("uvicorn", "uvicorn.access")
    }

    root.handlers.clear()
    if hasattr(root, "_batken_express_configured"):
        del root._batken_express_configured

    yield root

    root.handlers[:] = saved_handlers
    root.setLevel(saved_level)
    if saved_flag:
        root._batken_express_configured = saved_flag
    elif hasattr(root, "_batken_express_configured"):
        del root._batken_express_configured
    for name, (handlers, propagate) in managed.items():
        logger = logging.getLogger(name)
        logger.handlers[:] = handlers
        logger.propagate = propagate


def test_info_records_reach_stdout_as_json(fresh_root, capsys):
    configure_logging(level="INFO", json_logs=True)

    logging.getLogger("app.request").info(
        "request_completed",
        extra={"request_id": "abc123", "path": "/orders", "status_code": 200},
    )

    payload = json.loads(capsys.readouterr().out.strip())
    assert payload["message"] == "request_completed"
    assert payload["level"] == "INFO"
    assert payload["request_id"] == "abc123"
    assert payload["path"] == "/orders"
    assert payload["status_code"] == 200


def test_plain_format_appends_request_context(fresh_root, capsys):
    configure_logging(level="INFO", json_logs=False)

    logging.getLogger("app.request").info(
        "request_completed", extra={"path": "/health", "status_code": 200}
    )

    line = capsys.readouterr().out.strip()
    assert "request_completed" in line
    assert "path=/health" in line
    assert "status_code=200" in line


def test_each_record_is_emitted_once(fresh_root, capsys):
    configure_logging(level="INFO", json_logs=True)
    # A second call must not attach another handler.
    configure_logging(level="INFO", json_logs=True)

    logging.getLogger("app.fcm").warning("push_failed")

    assert len(capsys.readouterr().out.strip().splitlines()) == 1


def test_uvicorn_logs_are_routed_through_the_single_handler(fresh_root, capsys):
    uvicorn_logger = logging.getLogger("uvicorn.access")
    uvicorn_logger.handlers.append(logging.StreamHandler())
    uvicorn_logger.propagate = False

    configure_logging(level="INFO", json_logs=True)
    uvicorn_logger.info("GET /health 200")

    lines = capsys.readouterr().out.strip().splitlines()
    assert len(lines) == 1
    assert json.loads(lines[0])["logger"] == "uvicorn.access"


def test_level_below_info_is_respected(fresh_root, capsys):
    configure_logging(level="WARNING", json_logs=True)

    logging.getLogger("app.request").info("chatty")
    logging.getLogger("app.request").warning("important")

    lines = capsys.readouterr().out.strip().splitlines()
    assert len(lines) == 1
    assert json.loads(lines[0])["message"] == "important"


def test_unknown_level_falls_back_to_info(fresh_root, capsys):
    configure_logging(level="verbose", json_logs=True)

    logging.getLogger("app.request").info("still logged")

    assert json.loads(capsys.readouterr().out.strip())["message"] == "still logged"
