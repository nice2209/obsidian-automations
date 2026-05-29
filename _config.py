import json
import subprocess
import sys
import tempfile
from datetime import datetime, timezone, timedelta
from pathlib import Path

_SCRIPT_DIR = Path(__file__).parent
_config_path = _SCRIPT_DIR / "config.yaml"

_cfg: dict[str, str] = {
    "vault_path": "",
    "github_username": "",
    "timezone_offset": "9",
    "log_dir": "",
}

if _config_path.exists():
    import re
    for line in _config_path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'^\s*([a-zA-Z_]+)\s*:\s*"?([^"#\r\n]*)"?\s*$', line)
        if m:
            _cfg[m.group(1).strip()] = m.group(2).strip()

# --- Auto-detect vault path ---
if not _cfg["vault_path"]:
    _candidates = [
        Path.home() / "Library" / "Application Support" / "obsidian" / "obsidian.json",
        Path.home() / ".config" / "obsidian" / "obsidian.json",
    ]
    for _obs_json in _candidates:
        if _obs_json.exists():
            try:
                _parsed = json.loads(_obs_json.read_text(encoding="utf-8"))
                _vaults = _parsed.get("vaults", {})
                _open = next((v for v in _vaults.values() if v.get("open")), None)
                _best = _open or (next(iter(_vaults.values()), None) if _vaults else None)
                if _best:
                    _cfg["vault_path"] = _best["path"]
                    break
            except Exception:
                pass

if not _cfg["vault_path"] or not Path(_cfg["vault_path"]).exists():
    raise RuntimeError(
        "Vault path not found. Set 'vault_path' in config.yaml or open Obsidian at least once."
    )

# --- Auto-detect GitHub username ---
if not _cfg["github_username"]:
    try:
        result = subprocess.run(
            ["gh", "api", "user", "--jq", ".login"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            _cfg["github_username"] = result.stdout.strip()
    except Exception:
        pass

if not _cfg["github_username"]:
    raise RuntimeError(
        "GitHub username not found. Run 'gh auth login' or set 'github_username' in config.yaml."
    )

# --- Exported globals ---
VAULT = Path(_cfg["vault_path"])
GH_USER: str = _cfg["github_username"]
TZ_OFFSET: int = int(_cfg["timezone_offset"])
LOG_DIR = Path(_cfg["log_dir"]) if _cfg["log_dir"] else Path(tempfile.gettempdir())

_tz = timezone(timedelta(hours=TZ_OFFSET))


def tz_now() -> datetime:
    return datetime.now(_tz)


def to_tz(iso_string: str) -> datetime:
    dt = datetime.fromisoformat(iso_string.replace("Z", "+00:00"))
    return dt.astimezone(_tz)


def write_log(message: str, log_name: str = "obsidian-auto") -> None:
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"{ts}  {message}"
    print(line)
    try:
        log_file = LOG_DIR / f"{log_name}.log"
        with log_file.open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def sync_vault(paths: list[str], commit_msg: str) -> None:
    try:
        dirty = subprocess.run(
            ["git", "-C", str(VAULT), "status", "--porcelain"],
            capture_output=True, text=True
        ).stdout.strip()
        if dirty:
            for p in paths:
                subprocess.run(["git", "-C", str(VAULT), "add", p], capture_output=True)
            subprocess.run(["git", "-C", str(VAULT), "commit", "-m", commit_msg], capture_output=True)
            subprocess.run(["git", "-C", str(VAULT), "pull", "--no-rebase", "-X", "ours", "--quiet"], capture_output=True)
            subprocess.run(["git", "-C", str(VAULT), "push", "origin", "main"], capture_output=True)
            print(f"Pushed: {commit_msg}")
        else:
            print("No changes to commit.")
    except Exception as e:
        print(f"Warning: Git sync failed (files saved locally): {e}", file=sys.stderr)
