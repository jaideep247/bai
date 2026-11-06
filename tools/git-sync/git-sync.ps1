<#
.SYNOPSIS
    Keeps local git clones in step with GitHub. Pulls new commits and pushes
    commits you already made. Never creates commits, never touches uncommitted work.

.DESCRIPTION
    For each repository:
      1. Skips it if a merge or rebase is in progress, the branch is detached,
         or the branch has no upstream (origin/...).
      2. git fetch.
      3. If GitHub has new commits:
           - working tree clean  -> git pull --rebase
           - uncommitted changes -> pull postponed (VS Code shows the pending pull)
           - rebase conflict     -> rebase aborted, repository left exactly as before,
                                    logged as ATTENTION
      4. If you have local commits not on GitHub -> git push, ONLY with -Push (opt-in).
         Without -Push the commits are reported as AHEAD and stay local.
    After an aborted rebase the result is verified (no rebase in progress, HEAD and
    branch back on the commit they had before the pull); if not, the run logs ERROR
    and leaves the repository for manual repair.
    Every run is written to %LOCALAPPDATA%\git-sync\git-sync.log.

.EXAMPLE
    .\git-sync.ps1 -RepoPath 'C:\Users\JaideepSharma\Downloads\USAA\bai'

.EXAMPLE
    .\git-sync.ps1 -RepoPath 'C:\repo1','C:\repo2' -Push

.NOTES
    2026-11-06 | Push is opt-in (-Push); -NoPush kept as a no-op for old task definitions.
               | Rebase abort result verified before the repository is reported unchanged.
#>
[CmdletBinding()]
param(
    [string[]] $RepoPath = @('C:\Users\JaideepSharma\Downloads\USAA\bai'),
    [switch]   $Push,
    # Deprecated: pushing is off unless -Push is given; accepted so old tasks keep working
    [switch]   $NoPush,
    [string]   $LogFile = (Join-Path $env:LOCALAPPDATA 'git-sync\git-sync.log')
)

# Native git writes progress to stderr; never let that become a terminating error.
$ErrorActionPreference = 'Continue'
$script:attention = $false

function Write-Log {
    param([string] $Message)
    $dir = Split-Path $LogFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 1MB)) {
        Move-Item $LogFile "$LogFile.old" -Force
    }
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Verbose $line
}

function Invoke-Git {
    param([string] $Repo, [string[]] $Arguments)
    $output = & git -C $Repo @Arguments 2>&1 | ForEach-Object { "$_" }
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = (($output -join ' ').Trim()) }
}

function Get-Head {
    param([string] $Repo)
    (Invoke-Git $Repo @('rev-parse', 'HEAD')).Output
}

function Test-RebaseInProgress {
    param([string] $Repo)
    $gitDir = (Invoke-Git $Repo @('rev-parse', '--git-dir')).Output
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $Repo $gitDir }
    (Test-Path (Join-Path $gitDir 'rebase-merge')) -or (Test-Path (Join-Path $gitDir 'rebase-apply'))
}

function Undo-FailedPull {
    <# Aborts a rebase left by a failed pull and proves the repository is back where it was.
       Returns $true only when no rebase is in progress, HEAD is the pre-pull commit and
       the branch is checked out again. #>
    param([string] $Repo, [string] $Branch, [string] $HeadBefore)
    $abortOutput = ''
    if (Test-RebaseInProgress $Repo) {
        $abort = Invoke-Git $Repo @('rebase', '--abort')
        $abortOutput = $abort.Output
        if ($abort.Code -ne 0) {
            Write-Log "ERROR     $Repo [$Branch] - rebase --abort failed (exit $($abort.Code)): $abortOutput"
            return $false
        }
    }
    $stillRebasing = Test-RebaseInProgress $Repo
    $headAfter     = Get-Head $Repo
    $branchAfter   = (Invoke-Git $Repo @('rev-parse', '--abbrev-ref', 'HEAD')).Output
    if ($stillRebasing -or $headAfter -ne $HeadBefore -or $branchAfter -ne $Branch) {
        Write-Log ("ERROR     $Repo [$Branch] - repository NOT restored after the failed pull " +
                   "(rebase in progress: $stillRebasing, HEAD $headAfter, expected $HeadBefore, " +
                   "branch $branchAfter); repair manually. $abortOutput")
        return $false
    }
    return $true
}

function Sync-Repository {
    param([string] $Repo)

    if (-not (Test-Path (Join-Path $Repo '.git'))) {
        Write-Log "SKIP      $Repo - not a git repository"
        return
    }
    $gitDir = Join-Path $Repo '.git'
    foreach ($marker in 'rebase-merge', 'rebase-apply', 'MERGE_HEAD') {
        if (Test-Path (Join-Path $gitDir $marker)) {
            Write-Log "ATTENTION $Repo - merge/rebase in progress, finish it in VS Code first"
            $script:attention = $true
            return
        }
    }

    $branch = (Invoke-Git $Repo @('rev-parse', '--abbrev-ref', 'HEAD')).Output
    if ($branch -eq 'HEAD') {
        Write-Log "SKIP      $Repo - detached HEAD"
        return
    }
    $upstream = Invoke-Git $Repo @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    if ($upstream.Code -ne 0) {
        Write-Log "SKIP      $Repo [$branch] - no upstream branch"
        return
    }

    $fetch = Invoke-Git $Repo @('fetch', '--prune', '--quiet')
    if ($fetch.Code -ne 0) {
        Write-Log "OFFLINE   $Repo [$branch] - fetch failed: $($fetch.Output)"
        return
    }

    $counts = (Invoke-Git $Repo @('rev-list', '--left-right', '--count', 'HEAD...@{u}')).Output -split '\s+'
    $ahead  = [int]$counts[0]
    $behind = [int]$counts[1]
    $dirty  = [bool](Invoke-Git $Repo @('status', '--porcelain')).Output

    if ($behind -gt 0) {
        if ($dirty) {
            Write-Log "WAIT      $Repo [$branch] - $behind new commit(s) on GitHub; you have uncommitted changes, pull postponed"
        } else {
            $headBefore = Get-Head $Repo
            $pull = Invoke-Git $Repo @('pull', '--rebase', '--quiet')
            if ($pull.Code -ne 0) {
                $script:attention = $true
                if (Undo-FailedPull -Repo $Repo -Branch $branch -HeadBefore $headBefore) {
                    Write-Log "ATTENTION $Repo [$branch] - pull failed and was undone (verified: HEAD $headBefore); resolve with Sync in VS Code. $($pull.Output)"
                }
                return
            }
            Write-Log "PULLED    $Repo [$branch] - $behind commit(s)"
        }
    }

    if ($ahead -gt 0 -and -not $Push) {
        Write-Log "AHEAD     $Repo [$branch] - $ahead local commit(s) not pushed (push is opt-in: -Push)"
    }
    if ($ahead -gt 0 -and $Push -and ($behind -eq 0 -or -not $dirty)) {
        $push = Invoke-Git $Repo @('push', '--quiet')
        if ($push.Code -ne 0) {
            Write-Log "ATTENTION $Repo [$branch] - push failed: $($push.Output)"
            $script:attention = $true
            return
        }
        Write-Log "PUSHED    $Repo [$branch] - $ahead commit(s)"
    }

    if ($behind -eq 0 -and $ahead -eq 0) {
        Write-Log "OK        $Repo [$branch] - in sync"
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Log 'ERROR     git.exe not found on PATH'
    exit 2
}

foreach ($repo in $RepoPath) {
    try {
        Sync-Repository -Repo $repo
    } catch {
        Write-Log "ERROR     $repo - $($_.Exception.Message)"
        $script:attention = $true
    }
}

if ($script:attention) { exit 1 } else { exit 0 }
