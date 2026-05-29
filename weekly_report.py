from _config import *
import urllib.request
import urllib.error
import json
import subprocess

WEEKLY_DIR = VAULT / "Weekly Reports"
WEEKLY_DIR.mkdir(parents=True, exist_ok=True)

now = tz_now()
week_start = (now - __import__("datetime").timedelta(days=6)).date()
week_end = now.date()
week_num = now.strftime("%Y-W%V")
out_path = WEEKLY_DIR / f"{week_num}.md"

write_log(f"Generating weekly report {week_num} ...", "weekly-report")

token_result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
if token_result.returncode != 0 or not token_result.stdout.strip():
    write_log("gh auth token failed — aborting", "weekly-report")
    exit(1)
token = token_result.stdout.strip()
headers = {"Authorization": f"token {token}", "User-Agent": "obsidian-automations/1.0"}

all_events = []
for page in range(1, 6):
    url = f"https://api.github.com/users/{GH_USER}/events?per_page=100&page={page}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            parsed = json.loads(resp.read())
        if not parsed:
            break
        all_events.extend(parsed)
    except Exception as e:
        write_log(f"Page {page} fetch failed: {e}", "weekly-report")
        break

week_events = [
    ev for ev in all_events
    if week_start <= to_tz(ev["created_at"]).date() <= week_end
]

push_count = commit_count = pr_count = issue_count = release_count = 0
repo_set = set()
highlights = []

for ev in week_events:
    repo_set.add(ev["repo"]["name"])
    t = ev["type"]
    payload = ev.get("payload", {})
    if t == "PushEvent":
        push_count += 1
        commit_count += len(payload.get("commits") or [])
    elif t == "PullRequestEvent":
        action = payload.get("action", "")
        if action in ("opened", "merged"):
            pr_count += 1
            pr = payload.get("pull_request", {})
            highlights.append(f"- **PR {action}**: [{pr.get('title')}]({pr.get('html_url')})")
    elif t == "IssuesEvent":
        if payload.get("action") == "opened":
            issue_count += 1
            issue = payload.get("issue", {})
            highlights.append(f"- **Issue opened**: [{issue.get('title')}]({issue.get('html_url')})")
    elif t == "ReleaseEvent":
        if payload.get("action") == "published":
            release_count += 1
            rel = payload.get("release", {})
            highlights.append(f"- **Release**: [{rel.get('tag_name')}]({rel.get('html_url')}) in `{ev['repo']['name']}`")

repo_list = "\n".join(f"- `{r}`" for r in sorted(repo_set)) if repo_set else "_No activity._"
highlight_text = "\n".join(highlights) if highlights else "_No notable events._"

report = f"""# Weekly Report — {week_num}

> Period: {week_start} ~ {week_end}
> Generated: {now.strftime('%Y-%m-%d %H:%M')} (UTC+{TZ_OFFSET})

## Stats

| Metric | Count |
|--------|-------|
| Pushes | {push_count} |
| Commits | {commit_count} |
| PRs opened/merged | {pr_count} |
| Issues opened | {issue_count} |
| Releases | {release_count} |
| Repos touched | {len(repo_set)} |

## Repos Active This Week

{repo_list}

## Highlights

{highlight_text}

## Reflection

<!-- What went well? What was hard? What to focus on next week? -->
"""

out_path.write_text(report, encoding="utf-8")
write_log(f"Written: {out_path}", "weekly-report")

sync_vault(["Weekly Reports/"], f"chore: weekly report {week_num}")
write_log("Done.", "weekly-report")
