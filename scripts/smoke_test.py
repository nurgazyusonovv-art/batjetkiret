#!/usr/bin/env python3
"""Minimal production smoke checks for deploy verification."""
from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.error
import urllib.request


BASE_URL = os.environ.get("SMOKE_BASE_URL", "https://batjetkiret-production.up.railway.app").rstrip("/")
VERIFY_SSL = os.environ.get("SMOKE_VERIFY_SSL", "false").lower() in {"1", "true", "yes"}


CHECKS = [
    ("health", "/health", lambda data: data.get("status") == "ok"),
    ("public settings", "/admin/public-settings", lambda data: "delivery_base_price" in data),
    ("active enterprises", "/enterprises/active", lambda data: isinstance(data, list)),
]


def fetch_json(path: str) -> object:
    context = None if VERIFY_SSL else ssl._create_unverified_context()
    with urllib.request.urlopen(f"{BASE_URL}{path}", timeout=15, context=context) as response:
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}")
        return json.loads(response.read().decode("utf-8"))


def main() -> int:
    failed = 0
    for name, path, validator in CHECKS:
        try:
            data = fetch_json(path)
            ok = validator(data)
        except (urllib.error.URLError, TimeoutError, RuntimeError, json.JSONDecodeError) as exc:
            ok = False
            data = str(exc)

        print(f"{'OK' if ok else 'FAIL'} {name}: {path}")
        if not ok:
            print(f"  response: {data}")
            failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
