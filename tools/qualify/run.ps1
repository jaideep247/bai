# Runs the install harness of the product on Windows (adapted from the test tool's ci/qualify/run.ps1).
# In the same PowerShell window, without starting a nested powershell.exe:
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\tools\qualify\run.ps1 -PackageRoot ZR1 -Transport A4HK900123 -DryRun
# Reads the logon from the user's environment (setx ZCA_TT_A4H_USER / ZCA_TT_A4H_PASSWORD / ZCA_TT_A4H_CLIENT /
# ZCA_TT_A4H_URL / ZCA_TT_A4H_TLS_PIN), also when the variables were set after this shell started. The password is
# passed to the child process environment only, never printed.
param([Parameter(Mandatory = $true)][string]$PackageRoot,
      [Parameter(Mandatory = $true)][string]$Transport,
      [string]$Stages = "",
      [string]$Variant = "DEFAULT",
      [string]$Only = "",
      [switch]$DryRun,
      [switch]$WithDemo)
foreach ($n in 'ZCA_TT_A4H_USER','ZCA_TT_A4H_PASSWORD','ZCA_TT_A4H_CLIENT','ZCA_TT_A4H_URL','ZCA_TT_A4H_TLS_PIN') {
  if (-not (Get-Item "env:$n" -ErrorAction SilentlyContinue)) {
    $v = [Environment]::GetEnvironmentVariable($n, 'User')
    if ($v) { Set-Item "env:$n" $v }
  }
}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$argsList = @("$here\qualify.py", "--package-root", $PackageRoot, "--transport", $Transport, "--variant", $Variant)
if ($Stages) { $argsList += @("--stages", $Stages) }
if ($Only) { $argsList += @("--only", $Only) }
if ($DryRun) { $argsList += "--dry-run" }
if ($WithDemo) { $argsList += "--with-demo" }
python @argsList
exit $LASTEXITCODE
