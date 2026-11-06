<#
.SYNOPSIS
    Registers the Windows scheduled task "git-sync": runs git-sync.ps1 every
    15 minutes and at logon, hidden, as the current user (uses your git
    credentials). Re-run to change repositories or interval. No admin rights needed.
    The task only pulls unless -Push is given (push is opt-in).

.EXAMPLE
    .\install-git-sync-task.ps1

.EXAMPLE
    .\install-git-sync-task.ps1 -RepoPath 'C:\Users\JaideepSharma\Downloads\USAA\bai','C:\Projects\other' -EveryMinutes 10

.EXAMPLE
    .\install-git-sync-task.ps1 -Push

.EXAMPLE
    .\install-git-sync-task.ps1 -Uninstall

.NOTES
    2026-11-06 | Push opt-in (-Push); the default task never pushes. -NoPush is accepted and ignored.
#>
[CmdletBinding()]
param(
    [string[]] $RepoPath     = @('C:\Users\JaideepSharma\Downloads\USAA\bai'),
    [int]      $EveryMinutes = 15,
    [string]   $TaskName     = 'git-sync',
    [switch]   $Push,
    # Deprecated: the task does not push unless -Push is given
    [switch]   $NoPush,
    [switch]   $Uninstall
)
$ErrorActionPreference = 'Stop'

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Scheduled task '$TaskName' removed."
    return
}

foreach ($repo in $RepoPath) {
    if (-not (Test-Path (Join-Path $repo '.git'))) { throw "Not a git repository: $repo" }
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git.exe is not on PATH' }

# Copy the sync script to a stable place so the task does not depend on the checkout.
$home_dir = Join-Path $env:LOCALAPPDATA 'git-sync'
New-Item -ItemType Directory -Path $home_dir -Force | Out-Null
$target = Join-Path $home_dir 'git-sync.ps1'
Copy-Item -Path (Join-Path $PSScriptRoot 'git-sync.ps1') -Destination $target -Force

$repoList = ($RepoPath | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ','
$pushArg  = ''
if ($Push) { $pushArg = ' -Push' }
$command  = "& '$target' -RepoPath $repoList$pushArg"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"$command`""
$triggers = @(
    (New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)),
    (New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME")
)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Settings $settings `
    -Principal $principal -Description 'Pull/push git repositories to keep them in sync with GitHub (never commits).' -Force | Out-Null

Write-Host "Scheduled task '$TaskName' registered: every $EveryMinutes min and at logon."
Write-Host "Repositories: $($RepoPath -join ', ')"
if ($Push) { Write-Host 'Push: ON (local commits are pushed)' } else { Write-Host 'Push: OFF (pull only; re-run with -Push to push)' }
Write-Host "Log: $(Join-Path $home_dir 'git-sync.log')"
Write-Host "Running once now..."
& $target -RepoPath $RepoPath -Push:$Push
Get-Content (Join-Path $home_dir 'git-sync.log') -Tail 5
