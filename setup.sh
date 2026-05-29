#!/usr/bin/env bash
# setup.sh — obsidian-automations Mac/Linux setup
# Usage: ./setup.sh
# Requires: git, gh (gh auth login), Obsidian opened at least once, Python 3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"

echo ""
echo "=== obsidian-automations setup (Mac/Linux) ==="
echo ""

# --- Check dependencies ---
for cmd in git gh python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' not found. Install it and re-run."
        exit 1
    fi
done

if ! gh auth status &>/dev/null; then
    echo "ERROR: Not logged in to GitHub. Run: gh auth login"
    exit 1
fi
echo "[OK] git, gh, python3 found"

# --- Auto-detect vault ---
OBSIDIAN_JSON="$HOME/Library/Application Support/obsidian/obsidian.json"
if [[ ! -f "$OBSIDIAN_JSON" ]]; then
    OBSIDIAN_JSON="$HOME/.config/obsidian/obsidian.json"  # Linux fallback
fi

VAULT_PATH=""
if [[ -f "$OBSIDIAN_JSON" ]]; then
    VAULT_PATH=$(python3 -c "
import json, sys
data = json.load(open('$OBSIDIAN_JSON'))
vaults = data.get('vaults', {})
if vaults:
    print(list(vaults.values())[0]['path'])
" 2>/dev/null || true)
fi

if [[ -z "$VAULT_PATH" || ! -d "$VAULT_PATH" ]]; then
    read -rp "Vault path not found. Enter manually: " VAULT_PATH
fi
echo "[OK] Vault: $VAULT_PATH"

# --- Auto-detect GitHub username ---
GH_USER=$(gh api user --jq .login 2>/dev/null || true)
if [[ -z "$GH_USER" ]]; then
    read -rp "GitHub username: " GH_USER
fi
echo "[OK] GitHub user: $GH_USER"

# --- Write config.yaml if not present ---
CONFIG="$SCRIPT_DIR/config.yaml"
if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" <<EOF
vault_path: "$VAULT_PATH"
github_username: "$GH_USER"
timezone_offset: 9
EOF
    echo "[OK] Created config.yaml"
else
    echo "[OK] config.yaml already exists"
fi

# --- Helper: create launchd plist ---
create_plist() {
    local label="$1"
    local script="$2"
    local plist_path="$PLIST_DIR/$label.plist"

    mkdir -p "$PLIST_DIR"

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$script</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$TMPDIR/$label.log</string>
    <key>StandardErrorPath</key>
    <string>$TMPDIR/$label.log</string>
</dict>
</plist>
EOF
    echo "[OK] plist: $plist_path"
}

create_plist_interval() {
    local label="$1"
    local script="$2"
    local interval_seconds="$3"
    local plist_path="$PLIST_DIR/$label.plist"

    mkdir -p "$PLIST_DIR"

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$script</string>
    </array>
    <key>StartInterval</key>
    <integer>$interval_seconds</integer>
    <key>StandardOutPath</key>
    <string>$TMPDIR/$label.log</string>
    <key>StandardErrorPath</key>
    <string>$TMPDIR/$label.log</string>
</dict>
</plist>
EOF
    echo "[OK] plist (interval=${interval_seconds}s): $plist_path"
}

# --- Create Mac wrapper scripts (bash → python) ---
# On Mac the scripts are Python equivalents (shared logic via _config.py)
WRAPPER_DIR="$SCRIPT_DIR/mac"
mkdir -p "$WRAPPER_DIR"

# github_to_obsidian wrapper
cat > "$WRAPPER_DIR/github_to_obsidian.sh" <<'BASH'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$SCRIPT_DIR/github_to_obsidian.py"
BASH

# weekly_report wrapper
cat > "$WRAPPER_DIR/weekly_report.sh" <<'BASH'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$SCRIPT_DIR/weekly_report.py"
BASH

# sync_pull wrapper
cat > "$WRAPPER_DIR/sync_pull.sh" <<'BASH'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$SCRIPT_DIR/sync_pull.py"
BASH

# daily_note wrapper
cat > "$WRAPPER_DIR/daily_note.sh" <<'BASH'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$SCRIPT_DIR/daily_note.py"
BASH

chmod +x "$WRAPPER_DIR/"*.sh

# --- Register launchd agents ---
# Unload existing if present
for label in com.obsidian-automations.github com.obsidian-automations.weekly com.obsidian-automations.sync com.obsidian-automations.daily; do
    launchctl unload "$PLIST_DIR/$label.plist" 2>/dev/null || true
done

create_plist_interval "com.obsidian-automations.github" "$WRAPPER_DIR/github_to_obsidian.sh" 3600
create_plist_interval "com.obsidian-automations.daily"  "$WRAPPER_DIR/daily_note.sh"           86400

# Weekly: Sunday 22:00 — use calendar interval plist
cat > "$PLIST_DIR/com.obsidian-automations.weekly.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.obsidian-automations.weekly</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$WRAPPER_DIR/weekly_report.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>0</integer>
        <key>Hour</key><integer>22</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$TMPDIR/com.obsidian-automations.weekly.log</string>
    <key>StandardErrorPath</key>
    <string>$TMPDIR/com.obsidian-automations.weekly.log</string>
</dict>
</plist>
EOF
echo "[OK] plist (weekly Sunday 22:00): $PLIST_DIR/com.obsidian-automations.weekly.plist"

# sync_pull on login
cat > "$PLIST_DIR/com.obsidian-automations.sync.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.obsidian-automations.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$WRAPPER_DIR/sync_pull.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$TMPDIR/com.obsidian-automations.sync.log</string>
    <key>StandardErrorPath</key>
    <string>$TMPDIR/com.obsidian-automations.sync.log</string>
</dict>
</plist>
EOF
echo "[OK] plist (run at login): $PLIST_DIR/com.obsidian-automations.sync.plist"

# Load all
for label in com.obsidian-automations.github com.obsidian-automations.weekly com.obsidian-automations.sync com.obsidian-automations.daily; do
    launchctl load "$PLIST_DIR/$label.plist" 2>/dev/null && echo "[LOADED] $label" || echo "[WARN] Could not load $label"
done

echo ""
echo "=== Setup complete ==="
echo ""
echo "Agents registered:"
echo "  com.obsidian-automations.github  — every hour"
echo "  com.obsidian-automations.weekly  — every Sunday 22:00"
echo "  com.obsidian-automations.sync    — on login"
echo "  com.obsidian-automations.daily   — every 24h"
echo ""
echo "Manual usage:"
echo "  python3 $SCRIPT_DIR/llm_wiki.py --title 'Title' --content 'Content'"
echo "  python3 $SCRIPT_DIR/decision_log.py --decision 'X' --reason 'Y'"
