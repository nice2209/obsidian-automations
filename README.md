# obsidian-automations

Obsidian vault automation scripts. Logs GitHub activity, weekly reports, LLM session notes, and decision records automatically.

## Install (one-liner)

**Windows** (관리자 PowerShell):

```powershell
irm https://raw.githubusercontent.com/nice2209/obsidian-automations/main/install.ps1 | iex
```

**Mac/Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/nice2209/obsidian-automations/main/install.sh | bash
```

The installer checks all prerequisites first and tells you exactly what's missing.

## Requirements

| Tool     | Windows install                    | Mac install                    |
| -------- | ---------------------------------- | ------------------------------ |
| git      | `winget install Git.Git`           | `brew install git`             |
| gh CLI   | `winget install GitHub.cli`        | `brew install gh`              |
| Python 3 | `winget install Python.Python.3`   | `brew install python3`         |
| Obsidian | `winget install Obsidian.Obsidian` | `brew install --cask obsidian` |

After installing: `gh auth login` and open Obsidian once.

## What it does

| Script               | Trigger            | Output in Vault                                        |
| -------------------- | ------------------ | ------------------------------------------------------ |
| `github_to_obsidian` | Every hour         | `GitHub Activity/Daily/YYYY-MM-DD.md`, `Projects/*.md` |
| `weekly_report`      | Every Sunday 22:00 | `Weekly Reports/YYYY-WNN.md`                           |
| `sync_pull`          | On login           | Pulls latest vault from GitHub                         |
| `daily_note`         | Every day 08:00    | `daily/YYYY-MM-DD.md`                                  |
| `llm_wiki`           | Manual             | `LLM Wiki/YYYY-MM-DD - Title.md`                       |
| `decision_log`       | Manual             | `Decision Log/YYYY-MM.md`                              |

## Manual usage

**Windows (PowerShell):**

```powershell
.\llm_wiki.ps1 -Title "nodriver vs camoufox" -Tags "scraping,python" -Content "..."
.\llm_wiki.ps1 -Title "My learning" -FromClipboard
.\decision_log.ps1 -Decision "Use SQLite" -Reason "Zero setup" -Context "Money-Engine"
.\sync_pull.ps1
```

**Mac/Linux (Python):**

```bash
python3 llm_wiki.py --title "My learning" --from-clipboard
python3 llm_wiki.py --title "nodriver vs camoufox" --tags "scraping,python" --content "..."
python3 decision_log.py --decision "Use SQLite" --reason "Zero setup" --context "Money-Engine"
python3 sync_pull.py
```

## Configuration

All values auto-detect. To override, copy `config.yaml.example` to `config.yaml`:

```yaml
vault_path: "/Users/yourname/Documents/Obsidian Vault" # Mac
# vault_path: "C:\Users\YourName\Documents\Obsidian Vault"  # Windows
github_username: "your-github-username"
timezone_offset: 9
```

`config.yaml` is gitignored.

## Claude Code integration

When a Claude Code session ends, `.omc/notepad.md` is automatically saved to `LLM Wiki/` if it has content.

Add this to `~/.claude/settings.json` under `"hooks" > "Stop"`:

```json
{
  "type": "command",
  "command": "python3 ~/Scripts/session_end_hook.py",
  "timeout": 15,
  "async": true
}
```

Windows uses `session_end_hook.ps1` (registered automatically by `install.ps1`).

## Vault structure

```
Obsidian Vault/
├── GitHub Activity/
│   ├── README.md
│   ├── Daily/             # One note per day (auto)
│   └── Projects/          # One note per repo (auto)
├── Weekly Reports/        # One note per week (auto)
├── daily/                 # Daily note template (auto)
├── LLM Wiki/              # Claude/LLM session learnings (manual + auto hook)
└── Decision Log/          # Architecture decisions by month (manual)
```

## Update scripts on existing machine

```powershell
# Windows
cd ~\Scripts && git pull

# Mac
cd ~/Scripts && git pull
```
