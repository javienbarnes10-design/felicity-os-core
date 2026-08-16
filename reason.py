#!/usr/bin/env python3
"""
reason.py - Theory-of-mind reasoning pass.

Called once per user command as:
    python3 reason.py "<user command>"

Sends the command to the local Ollama model with a prompt focused purely on
INTERPRETING INTENT (not acting), and prints a short reasoning summary to
stdout. main.rs captures that stdout and injects it into the main prompt
under ### THEORY_OF_MIND (REASONING_LAYER).

Deliberately kept separate from the actuation model call: this one has no
tools, no whitelist, no EXECUTE syntax available to it — it can only reason
in prose. If it fails for any reason, it prints a safe fallback string and
exits 0, so a hiccup here never blocks the outer loop.
"""

import sys
import json
import urllib.request

OLLAMA_URL = "http://127.0.0.1:11434/api/generate"
MODEL = "amelia-14b:latest"
TIMEOUT_SECONDS = 30

FALLBACK = "NO_REASONING_AVAILABLE"


def main() -> None:
    if len(sys.argv) < 2:
        print(FALLBACK)
        return

    user_command = sys.argv[1]

    prompt = (
        "You are a reasoning-only module. You cannot execute commands. "
        "Given the user's request below, in 2-4 short sentences: "
        "(1) state what the user most likely wants to accomplish, "
        "(2) note any ambiguity or risk worth flagging, "
        "(3) suggest the simplest first step. "
        "Do not use [EXECUTE] blocks or any command syntax — prose only.\n\n"
        f"USER_COMMAND: {user_command}"
    )

    payload = json.dumps({
        "model": MODEL,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": 0.4,
            "num_predict": 256,
        },
    }).encode("utf-8")

    req = urllib.request.Request(
        OLLAMA_URL,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            body = json.loads(resp.read().decode("utf-8"))
            text = body.get("response", "").strip()
            print(text if text else FALLBACK)
    except Exception as e:
        # Never let a reasoning-layer failure break the outer actuation loop.
        print(f"{FALLBACK} ({e})")


if __name__ == "__main__":
    main()

