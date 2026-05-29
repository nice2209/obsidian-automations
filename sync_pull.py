from _config import *
import subprocess

write_log("Pulling vault from GitHub ...", "sync-pull")

try:
    status = subprocess.run(
        ["git", "-C", str(VAULT), "status", "--porcelain"],
        capture_output=True, text=True, check=False
    )
    if status.stdout.strip():
        write_log("Local changes detected, stashing ...", "sync-pull")
        subprocess.run(["git", "-C", str(VAULT), "stash"], capture_output=True, check=False)
        subprocess.run(["git", "-C", str(VAULT), "pull", "--no-rebase", "-X", "ours", "--quiet"], capture_output=True, check=False)
        subprocess.run(["git", "-C", str(VAULT), "stash", "pop"], capture_output=True, check=False)
        write_log("Pulled (stash restored).", "sync-pull")
    else:
        subprocess.run(["git", "-C", str(VAULT), "pull", "--no-rebase", "-X", "ours", "--quiet"], capture_output=True, check=False)
        write_log("Pulled (clean).", "sync-pull")
except Exception as e:
    write_log(f"Pull failed: {e}", "sync-pull")

write_log("Done.", "sync-pull")
