"""
CLI equivalent of decision_log.ps1.
Appends an Architecture Decision Record to Obsidian Decision Log.

Usage:
    python decision_log.py --decision "Use SQLite" --reason "Zero setup, embedded" --context "Money-Engine"
    python decision_log.py --decision "Drop nodriver" --reason "Unstable API" --alternatives "camoufox, playwright" --status rejected
"""

import argparse
from pathlib import Path

from _config import VAULT, tz_now, write_log, sync_vault


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Append an Architecture Decision Record to Obsidian Decision Log."
    )
    parser.add_argument("--decision", required=True, help="The decision made")
    parser.add_argument("--reason", required=True, help="Reason for the decision")
    parser.add_argument("--context", default="", help="Context in which the decision was made")
    parser.add_argument("--alternatives", default="", help="Alternatives that were considered")
    parser.add_argument("--status", default="accepted",
                        help="Decision status: accepted | rejected | superseded | deprecated")
    parser.add_argument("--no-sync", action="store_true",
                        help="Skip git sync after saving")
    args = parser.parse_args()

    now = tz_now()
    month_str = now.strftime("%Y-%m")
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H:%M")

    decision_dir = Path(VAULT) / "Decision Log"
    decision_dir.mkdir(parents=True, exist_ok=True)

    out_path = decision_dir / f"{month_str}.md"

    context_line = f"\n\n**Context:** {args.context}" if args.context else ""
    alt_line = f"\n\n**Alternatives considered:** {args.alternatives}" if args.alternatives else ""

    entry = (
        f"\n\n"
        f"---\n"
        f"\n"
        f"## {date_str} {time_str} — {args.decision}\n"
        f"\n"
        f"**Status:** {args.status}\n"
        f"**Reason:** {args.reason}"
        f"{context_line}"
        f"{alt_line}\n"
    )

    if not out_path.exists():
        out_path.write_text(f"# Decision Log — {month_str}\n", encoding="utf-8")

    with out_path.open("a", encoding="utf-8") as f:
        f.write(entry)

    print(f"Logged: {out_path}")

    if not args.no_sync:
        sync_vault(["Decision Log/"], f"decision: {args.decision}")


if __name__ == "__main__":
    main()
