#!/usr/bin/env python3
"""Minimal stdio echo test — Dart → Python stdin communication test."""
import json
import sys
import os

# Signal ready immediately
os.write(1, b'{"type":"ready"}\n')
os.write(1, b'{"type":"log","msg":"Bridge started, waiting for stdin..."}\n')

# Read line by line from stdin, echo each line back as a log event
try:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        os.write(1, json.dumps({"type": "echo", "line": line}).encode() + b"\n")
except EOFError:
    pass
