import re
import subprocess
import sys
import urllib.request
import urllib.error
import json
from collections import defaultdict
from pathlib import Path

from _config import (
    VAULT, GH_USER, TZ_OFFSET,
    write_log, sync_vault, tz_now, to_tz,
)

ACTIVITY_DIR = VAULT / "GitHub Activity"
DAILY_DIR    = ACTIVITY_DIR / "Daily"
PROJECTS_DIR = ACTIVITY_DIR / "Projects"

LOG = "github-to-obsidian"

write_log(f"Fetching GitHub events for {GH_USER} ...", LOG)

token_result = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True)
if token_result.returncode != 0 or not token_result.stdout.strip():
    write_log("gh auth token failed — aborting", LOG)
    sys.exit(1)
token = token_result.stdout.strip()

headers = {
    "Authorization": f"token {token}",
    "User-Agent": "obsidian-automations/1.0",
}

all_events: list[dict] = []
for page in range(1, 4):
    url = f"https://api.github.com/users/{GH_USER}/events?per_page=100&page={page}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if not data:
            break
        all_events.extend(data)
    except urllib.error.URLError as e:
        write_log(f"Page {page} fetch failed: {e}", LOG)
        break

write_log(f"Total events fetched: {len(all_events)}", LOG)

DAILY_DIR.mkdir(parents=True, exist_ok=True)
PROJECTS_DIR.mkdir(parents=True, exist_ok=True)

by_date: dict[str, list[str]] = defaultdict(list)
by_repo: dict[str, list[str]] = defaultdict(list)


def add_entry(date: str, repo: str, line: str) -> None:
    by_date[date].append(line)
    by_repo[repo].append(f"[{date}] {line}")


for ev in all_events:
    kst  = to_tz(ev["created_at"])
    date = kst.strftime("%Y-%m-%d")
    time = kst.strftime("%H:%M")
    repo = ev["repo"]["name"]
    ev_type = ev.get("type", "")
    payload = ev.get("payload", {})

    if ev_type == "PushEvent":
        branch  = re.sub(r"^refs/heads/", "", payload.get("ref", ""))
        commits = payload.get("commits", [])
        count   = len(commits)
        msgs    = "\n".join(
            f"  - {c['message'].splitlines()[0]}" for c in commits[:3]
        )
        entry = f"- `{time}` **Push** to `{repo}/{branch}` ({count} commit(s))"
        if msgs:
            entry += "\n" + msgs
        add_entry(date, repo, entry)

    elif ev_type == "PullRequestEvent":
        pr = payload.get("pull_request", {})
        add_entry(date, repo,
            f"- `{time}` **PR {payload.get('action', '')}**: [{pr.get('title', '')}]({pr.get('html_url', '')}) in `{repo}`")

    elif ev_type == "IssuesEvent":
        issue = payload.get("issue", {})
        add_entry(date, repo,
            f"- `{time}` **Issue {payload.get('action', '')}**: [{issue.get('title', '')}]({issue.get('html_url', '')}) in `{repo}`")

    elif ev_type == "CreateEvent":
        add_entry(date, repo,
            f"- `{time}` **Created** {payload.get('ref_type', '')} `{payload.get('ref', '')}` in `{repo}`")

    elif ev_type == "ReleaseEvent":
        rel = payload.get("release", {})
        add_entry(date, repo,
            f"- `{time}` **Release {payload.get('action', '')}**: [{rel.get('tag_name', '')}]({rel.get('html_url', '')}) in `{repo}`")

    elif ev_type == "IssueCommentEvent":
        issue   = payload.get("issue", {})
        comment = payload.get("comment", {})
        add_entry(date, repo,
            f"- `{time}` **Comment** on [#{issue.get('number', '')} {issue.get('title', '')}]({comment.get('html_url', '')}) in `{repo}`")

    elif ev_type == "PullRequestReviewEvent":
        pr     = payload.get("pull_request", {})
        review = payload.get("review", {})
        add_entry(date, repo,
            f"- `{time}` **Review ({review.get('state', '')})**: [{pr.get('title', '')}]({pr.get('html_url', '')}) in `{repo}`")

now = tz_now()
now_str = now.strftime("%Y-%m-%d %H:%M")

for date in sorted(by_date, reverse=True):
    path = DAILY_DIR / f"{date}.md"
    header  = f"# GitHub Activity — {date}\n\n> Auto-generated. Last updated: {now_str} (UTC+{TZ_OFFSET})\n\n"
    content = header + "\n\n".join(by_date[date]) + "\n"
    path.write_text(content, encoding="utf-8")
    write_log(f"Written: {path}", LOG)

safe_re = re.compile(r'[/\\:*?"<>|]')
for repo in sorted(by_repo):
    safe_name = safe_re.sub("-", repo)
    path      = PROJECTS_DIR / f"{safe_name}.md"
    header    = f"# {repo}\n\n> Auto-generated. Last updated: {now_str} (UTC+{TZ_OFFSET})\n\n"
    content   = header + "\n\n".join(by_repo[repo]) + "\n"
    path.write_text(content, encoding="utf-8")
    write_log(f"Written: {path}", LOG)

repo_links  = "\n".join(
    f"- [[{safe_re.sub('-', r)}]] ({r})" for r in sorted(by_repo)
)
daily_links = "\n".join(
    f"- [[{d}]]" for d in sorted(by_date, reverse=True)[:14]
)
readme = (
    f"# GitHub Activity Index\n\n"
    f"> Last updated: {now_str} (UTC+{TZ_OFFSET})\n\n"
    f"## Recent Days\n{daily_links}\n\n"
    f"## Projects\n{repo_links}\n"
)
(ACTIVITY_DIR / "README.md").write_text(readme, encoding="utf-8")

sync_vault(["GitHub Activity/"], f"chore: github activity sync {now_str} (UTC+{TZ_OFFSET})")
write_log("Done.", LOG)
