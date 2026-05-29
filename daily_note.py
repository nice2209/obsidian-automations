from _config import *

DAILY_DIR = VAULT / "daily"
DAILY_DIR.mkdir(parents=True, exist_ok=True)

now = tz_now()
date_str = now.strftime("%Y-%m-%d")
day_name = now.strftime("%A")
out_path = DAILY_DIR / f"{date_str}.md"

if out_path.exists():
    write_log(f"Daily note already exists: {out_path}", "daily-note")
    exit(0)

write_log(f"Creating daily note for {date_str} ...", "daily-note")

github_summary = ""
github_daily = VAULT / "GitHub Activity" / "Daily" / f"{date_str}.md"
if github_daily.exists():
    lines = [
        ln for ln in github_daily.read_text(encoding="utf-8").splitlines()
        if ln.startswith("- ")
    ][:5]
    if lines:
        github_summary = "\n" + "\n".join(lines)

github_section = github_summary if github_summary else "\n_No activity yet._"

note = f"""---
date: {date_str}
day: {day_name}
---

# {date_str} ({day_name})

## Goals

- [ ]

## GitHub Today
{github_section}

## Notes



## Reflection

> What went well?

> What was hard?

> What carries over to tomorrow?
"""

out_path.write_text(note, encoding="utf-8")
write_log(f"Created: {out_path}", "daily-note")

sync_vault(["daily/"], f"chore: daily note {date_str}")
write_log("Done.", "daily-note")
