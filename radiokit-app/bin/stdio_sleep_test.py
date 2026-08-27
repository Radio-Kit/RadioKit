#!/usr/bin/env python3
"""Test: sleep 4s like the real bridge, then read stdin and echo back."""
import json
import sys
import os
import time

# Signal something immediately
os.write(1, b'{"type":"log","msg":"Sleeping 4s..."}\n')

# Sleep like the real bridge does
time.sleep(4)

# Signal ready
os.write(1, b'{"type":"ready"}\n')
os.write(1, b'{"type":"log","msg":"Bridge started, waiting for stdin..."}\n')

# Read line by line from stdin, echo each line back
try:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        os.write(1, json.dumps({"type": "echo", "line": line}).encode() + b"\n")
        # Also flush to ensure it's sent immediately
except EOFError:
    pass
