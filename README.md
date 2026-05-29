# obsidian-automations

Obsidian vault automation scripts. Logs GitHub activity, weekly reports, LLM session notes, and decision records automatically.

## Install (one-liner)

```powershell
irm https://raw.githubusercontent.com/nice2209/obsidian-automations/main/install.ps1 | iex
```

**Requirements:** [git](https://git-scm.com), [GitHub CLI](https://cli.github.com) + `gh auth login`, Obsidian opened at least once.

## What it does

| Script                   | Trigger            | Output in Vault                                        |
| ------------------------ | ------------------ | ------------------------------------------------------ |
| `github_to_obsidian.ps1` | Every hour         | `GitHub Activity/Daily/YYYY-MM-DD.md`, `Projects/*.md` |
| `weekly_report.ps1`      | Every Sunday 22:00 | `Weekly Reports/YYYY-WNN.md`                           |
| `sync_pull.ps1`          | On login           | Pulls latest vault from GitHub                         |
| `llm_wiki.ps1`           | Manual             | `LLM Wiki/YYYY-MM-DD - Title.md`                       |
| `decision_log.ps1`       | Manual             | `Decision Log/YYYY-MM.md`                              |

## Manual usage

```powershell
# Save a Claude/LLM session learning
.\llm_wiki.ps1 -Title "nodriver vs camoufox" -Tags "scraping,python" -Content "nodriver wins on Korean finance..."
.\llm_wiki.ps1 -Title "My learning" -FromClipboard

# Log an architectural decision
.\decision_log.ps1 -Decision "Use SQLite" -Reason "Zero setup, embedded" -Context "Money-Engine" -Alternatives "PostgreSQL, JSON files"

# Pull latest vault manually (e.g. after working on another PC)
.\sync_pull.ps1
```

## Configuration

All values auto-detect. To override, copy `config.yaml.example` to `config.yaml`:

```yaml
vault_path: "C:\Users\YourName\Documents\Obsidian Vault"
github_username: "your-github-username"
timezone_offset: 9
```

`config.yaml` is gitignored.

## Vault structure

```
Obsidian Vault/
├── GitHub Activity/
│   ├── README.md          # Index
│   ├── Daily/             # One note per day
│   └── Projects/          # One note per repo
├── Weekly Reports/        # One note per week (auto)
├── LLM Wiki/              # Claude/LLM session learnings (manual)
└── Decision Log/          # Architecture decisions by month (manual)
```

## Update scripts on existing machine

```powershell
cd ~\Scripts
git pull
```
