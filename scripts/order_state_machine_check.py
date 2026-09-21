#!/usr/bin/env python3
"""Fast local checks for order status transition rules."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.services.order_status import ALLOWED_TRANSITIONS, ensure_transition


VALID_CASES = [
    ("WAITING_COURIER", "PREPARING"),
    ("WAITING_COURIER", "ACCEPTED"),
    ("PREPARING", "READY"),
    ("READY", "ACCEPTED"),
    ("ACCEPTED", "ON_THE_WAY"),
    ("ON_THE_WAY", "COMPLETED"),
]

INVALID_CASES = [
    ("COMPLETED", "WAITING_COURIER"),
    ("CANCELLED", "ACCEPTED"),
    ("WAITING_COURIER", "COMPLETED"),
]


def main() -> int:
    for current, new in VALID_CASES:
        ensure_transition(current, new)

    for current, new in INVALID_CASES:
        try:
            ensure_transition(current, new)
        except Exception:
            continue
        raise AssertionError(f"Invalid transition passed: {current} -> {new}")

    print("OK order state machine")
    print(ALLOWED_TRANSITIONS)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
