"""
CLI equivalent of llm_wiki.ps1.
Saves a Claude/LLM session learning to Obsidian LLM Wiki.

Usage:
    python llm_wiki.py --title "nodriver vs camoufox" --tags "scraping,python" --content "..."
    python llm_wiki.py --title "My learning" --from-clipboard
    python llm_wiki.py --title "My learning" --from-clipboard --project "Money-Engine"
"""

import argparse
import re
import sys
from pathlib import Path

from _config import VAULT, tz_now, write_log, sync_vault


def get_clipboard() -> str:
    try:
        import pyperclip
        return pyperclip.paste()
    except ImportError:
        pass

    import subprocess
    import platform
    system = platform.system()
    if system == "Darwin":
        result = subprocess.run(["pbpaste"], capture_output=True, text=True)
        return result.stdout
    else:
        result = subprocess.run(
            ["powershell", "-Command", "Get-Clipboard"],
            capture_output=True, text=True
        )
        return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Save a Claude/LLM session learning to Obsidian LLM Wiki."
    )
    parser.add_argument("--title", required=True, help="Wiki entry title")
    parser.add_argument("--tags", default="", help="Comma-separated tags")
    parser.add_argument("--content", default="", help="Entry content")
    parser.add_argument("--project", default="", help="Associated project name")
    parser.add_argument("--from-clipboard", action="store_true",
                        help="Read content from clipboard")
    parser.add_argument("--no-sync", action="store_true",
                        help="Skip git sync after saving")
    args = parser.parse_args()

    content = args.content
    if args.from_clipboard:
        content = get_clipboard()

    if not content or not content.strip():
        print("Error: Content is empty. Use --content '...' or --from-clipboard.", file=sys.stderr)
        sys.exit(1)

    now = tz_now()
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H:%M")

    safe_name = re.sub(r'[/\\:*?"<>|]', "-", args.title)

    wiki_dir = Path(VAULT) / "LLM Wiki"
    wiki_dir.mkdir(parents=True, exist_ok=True)

    out_path = wiki_dir / f"{date_str} - {safe_name}.md"

    if args.tags:
        tag_list = [f'"{t.strip()}"' for t in args.tags.split(",") if t.strip()]
        tag_yaml = "[" + ", ".join(tag_list) + "]"
    else:
        tag_yaml = "[]"

    project_yaml = f'\nproject: "{args.project}"' if args.project else ""

    note = (
        f"---\n"
        f'title: "{args.title}"\n'
        f"date: {date_str}\n"
        f"tags: {tag_yaml}{project_yaml}\n"
        f"source: claude-session\n"
        f"---\n"
        f"\n"
        f"# {args.title}\n"
        f"\n"
        f"> Saved: {date_str} {time_str}\n"
        f"\n"
        f"{content.strip()}\n"
    )

    out_path.write_text(note, encoding="utf-8")
    print(f"Saved: {out_path}")

    if not args.no_sync:
        sync_vault(["LLM Wiki/"], f"wiki: {args.title}")


if __name__ == "__main__":
    main()
