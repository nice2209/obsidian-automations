# obsidian-automations

Obsidian vault automation scripts. Logs GitHub activity, weekly reports, LLM session notes, and decision records automatically.

## What it does

| Script                   | Trigger                     | Output in Vault                                        |
| ------------------------ | --------------------------- | ------------------------------------------------------ |
| `github_to_obsidian.ps1` | Every hour (Task Scheduler) | `GitHub Activity/Daily/YYYY-MM-DD.md`, `Projects/*.md` |
| `weekly_report.ps1`      | Every Sunday 22:00          | `Weekly Reports/YYYY-WNN.md`                           |
| `llm_wiki.ps1`           | Manual                      | `LLM Wiki/YYYY-MM-DD - Title.md`                       |
| `decision_log.ps1`       | Manual                      | `Decision Log/YYYY-MM.md`                              |

## Setup (new machine)

### Requirements

- [git](https://git-scm.com)
- [GitHub CLI](https://cli.github.com) + `gh auth login`
- Obsidian installed and opened at least once
- PowerShell 5.1+

### Windows

```powershell
git clone https://github.com/nice2209/obsidian-automations C:\Users\<you>\Scripts
cd C:\Users\<you>\Scripts
.\setup.ps1
```

That's it. Tasks are registered in Task Scheduler automatically.

### Mac / Linux

```bash
git clone https://github.com/nice2209/obsidian-automations ~/.local/obsidian-automations
cd ~/.local/obsidian-automations
chmod +x setup.sh && ./setup.sh
```

## Configuration

All values auto-detect. To override, copy `config.yaml.example` to `config.yaml`:

```yaml
vault_path: "C:\Users\YourName\Documents\Obsidian Vault"
github_username: "your-github-username"
timezone_offset: 9
```

`config.yaml` is gitignored — safe to commit the repo publicly.

## Manual usage

**Save a Claude session learning:**

```powershell
.\llm_wiki.ps1 -Title "nodriver vs camoufox" -Tags "scraping,python" -Content "nodriver wins on Korean finance sites because..."
# Or paste from clipboard:
.\llm_wiki.ps1 -Title "My learning" -FromClipboard
```

**Log an architectural decision:**

```powershell
.\decision_log.ps1 -Decision "Use SQLite" -Reason "Zero setup, embedded" -Context "Money-Engine" -Alternatives "PostgreSQL, JSON files"
```

## Vault structure

```
Obsidian Vault/
├── GitHub Activity/
│   ├── README.md          # Index
│   ├── Daily/             # One note per day
│   └── Projects/          # One note per repo
├── Weekly Reports/        # One note per week
├── LLM Wiki/              # Claude/LLM session learnings
└── Decision Log/          # ADR by month
```
