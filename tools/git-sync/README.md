# git-sync — keep local clones in step with GitHub

> **First principle:** GitHub is the master copy; the PC pulls what is new and — only when you switch it on with `-Push` — pushes what you already committed. It never commits for you.
> **Analogy:** a mail carrier on a round every 15 minutes — collects what is in the outbox (your commits), delivers what arrived (cloud commits), and never writes letters itself.

## Install (once, no admin rights)

In PowerShell, inside the repository:

```powershell
cd C:\Users\JaideepSharma\Downloads\USAA\bai\tools\git-sync
```

```powershell
powershell -ExecutionPolicy Bypass -File .\install-git-sync-task.ps1
```

It registers the task **git-sync** (every 15 min + at logon), runs it once and prints the last log lines.
By default the task **only pulls**. To let it push your local commits too (opt-in):

```powershell
powershell -ExecutionPolicy Bypass -File .\install-git-sync-task.ps1 -Push
```

More repositories or another interval:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-git-sync-task.ps1 -RepoPath 'C:\Users\JaideepSharma\Downloads\USAA\bai','C:\Projects\other' -EveryMinutes 10
```

Remove it:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-git-sync-task.ps1 -Uninstall
```

## What it does on each run

| Situation | Action | Log word |
|---|---|---|
| Nothing new anywhere | nothing | `OK` |
| New commits on GitHub, no local edits | `git pull --rebase` | `PULLED` |
| New commits on GitHub, you have uncommitted edits | waits — VS Code shows the pending pull | `WAIT` |
| You committed but did not push, task installed with `-Push` | `git push` | `PUSHED` |
| You committed but did not push, default task | nothing — reported only | `AHEAD` |
| Pull would conflict | `rebase --abort`, then verified: no rebase in progress, HEAD and branch back on the pre-pull commit | `ATTENTION` |
| Abort failed or the check above does not hold | nothing more — repair manually (`git status`) | `ERROR` |
| Merge/rebase already in progress, push rejected | nothing | `ATTENTION` |
| No network / VPN | nothing | `OFFLINE` |

Log: `%LOCALAPPDATA%\git-sync\git-sync.log` (rolls over at 1 MB). Check it with:

```powershell
Get-Content "$env:LOCALAPPDATA\git-sync\git-sync.log" -Tail 20
```

## Notes

- Runs only while you are logged on, as you — it uses the GitHub credentials git already stored.
- A PowerShell window may flash briefly at each run on some Windows builds.
- The task runs a copy in `%LOCALAPPDATA%\git-sync`; re-run the installer after changing `git-sync.ps1`.
- `-NoPush` from older installs is still accepted and has no effect (push is off unless `-Push`).
- Not executed in the cloud session that wrote it (no PowerShell there); the first run on the PC is the test.
  The git behaviour it relies on (a conflicting `pull --rebase` leaves a rebase in progress,
  `rebase --abort` restores HEAD and branch, `rebase --abort` without a rebase exits 128) was
  checked with a scripted conflict in a scratch repository on 2026-11-06 (audit A48).
