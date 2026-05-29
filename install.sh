#!/usr/bin/env bash
# install.sh — obsidian-automations one-liner installer for Mac/Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/nice2209/obsidian-automations/main/install.sh | bash

set -euo pipefail

REPO_URL="https://github.com/nice2209/obsidian-automations.git"
INSTALL_DIR="$HOME/Scripts"

echo ""
echo "=== obsidian-automations installer ==="
echo ""

# --- Prerequisite checker ---
check_prerequisites() {
    local missing=0

    # git
    if command -v git &>/dev/null; then
        echo "[OK]     git $(git --version | sed 's/git version //')"
    else
        echo "[MISSING] git not found -- install: brew install git"
        missing=$((missing + 1))
    fi

    # gh
    if command -v gh &>/dev/null; then
        echo "[OK]     gh $(gh --version | head -1 | sed 's/gh version //' | sed 's/ (.*//')"
    else
        echo "[MISSING] gh not found -- install: brew install gh"
        missing=$((missing + 1))
    fi

    # python3
    if command -v python3 &>/dev/null; then
        echo "[OK]     $(python3 --version)"
    else
        echo "[MISSING] python3 not found -- install: brew install python3"
        missing=$((missing + 1))
    fi

    # Obsidian
    if [[ -d "/Applications/Obsidian.app" ]]; then
        echo "[OK]     Obsidian found at /Applications/Obsidian.app"
    else
        echo "[WARN]   Obsidian not found -- install: brew install --cask obsidian"
    fi

    # gh auth
    if command -v gh &>/dev/null; then
        if gh auth status &>/dev/null; then
            echo "[OK]     gh authenticated ($(gh api user --jq .login 2>/dev/null || echo 'unknown'))"
        else
            echo "[MISSING] gh not authenticated -- run: gh auth login"
            missing=$((missing + 1))
        fi
    fi

    # Obsidian vault
    local obs_json="$HOME/Library/Application Support/obsidian/obsidian.json"
    if [[ ! -f "$obs_json" ]]; then
        obs_json="$HOME/.config/obsidian/obsidian.json"
    fi
    if [[ -f "$obs_json" ]]; then
        local vault_path
        vault_path=$(python3 -c "
import json
data = json.load(open('$obs_json'))
vaults = data.get('vaults', {})
open_vault = next((v for v in vaults.values() if v.get('open')), None)
vault = open_vault or (list(vaults.values())[0] if vaults else None)
print(vault['path'] if vault else '')
" 2>/dev/null || echo "")
        if [[ -n "$vault_path" && -d "$vault_path" ]]; then
            echo "[OK]     Obsidian vault: $vault_path"
        else
            echo "[WARN]   obsidian.json found but vault path missing -- open Obsidian first"
        fi
    else
        echo "[WARN]   obsidian.json not found -- open Obsidian at least once to create a vault"
    fi

    echo ""
    if [[ $missing -gt 0 ]]; then
        echo "[FAIL]   $missing required tool(s) missing. Install them and re-run."
        exit 1
    fi
    echo "[OK]     All prerequisites satisfied. Continuing install..."
    echo ""
}

check_prerequisites

# --- Clone or update ---
if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "[UPDATE] Pulling latest scripts in $INSTALL_DIR ..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    if [[ -d "$INSTALL_DIR" ]]; then
        backup="${INSTALL_DIR}-backup-$(date +%Y%m%d-%H%M%S)"
        mv "$INSTALL_DIR" "$backup"
        echo "[BACKUP] Existing Scripts folder moved to $backup"
    fi
    echo "[CLONE]  Cloning into $INSTALL_DIR ..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# --- Run setup ---
echo ""
echo "[SETUP]  Running setup.sh ..."
chmod +x "$INSTALL_DIR/setup.sh"
bash "$INSTALL_DIR/setup.sh"
