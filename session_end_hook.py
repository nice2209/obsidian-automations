#!/usr/bin/env python3
"""
Claude Code Stop hook — saves .omc/notepad.md to LLM Wiki if content exists.
Registered in ~/.claude/settings.json as a Stop hook (async).
Works on Mac and Linux.
"""
import os
import subprocess
import sys
from pathlib import Path

project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
notepad_path = project_dir / ".omc" / "notepad.md"

if not notepad_path.exists():
    sys.exit(0)

content = notepad_path.read_text(encoding="utf-8").strip()
if len(content) < 30:
    sys.exit(0)

project_name = project_dir.name
title = f"Session: {project_name}"
script_dir = Path(__file__).parent
wiki_script = script_dir / "llm_wiki.py"

if not wiki_script.exists():
    sys.exit(0)

try:
    subprocess.run(
        [
            sys.executable, str(wiki_script),
            "--title", title,
            "--content", content,
            "--tags", f"session,{project_name}",
            "--project", project_name,
            "--no-sync",
        ],
        timeout=10,
        capture_output=True,
    )
except Exception:
    pass  # Must never block Claude Code exit
