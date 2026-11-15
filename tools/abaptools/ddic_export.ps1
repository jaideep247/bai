# Runs ddic_export.py on Windows with the logon of the user's environment (setx SAP_* or ZCA_TT_A4H_* variables,
# the same as the test tool's qualification harness), also when the variables were set after this shell started.
# The password goes to the child process environment only, never printed. Run from the repository root:
#   powershell -File tools\abaptools\ddic_export.ps1 -Out ops-suite\ddic\a4h
param([string]$Out = "ops-suite\ddic\a4h",
      [string[]]$Tables = @("ops-framework\config\ddic\standard_tables.txt"))
foreach ($n in 'SAP_URL','SAP_USER','SAP_PASSWORD','SAP_CLIENT','SAP_TLS_PIN',
               'ZCA_TT_A4H_URL','ZCA_TT_A4H_USER','ZCA_TT_A4H_PASSWORD','ZCA_TT_A4H_CLIENT','ZCA_TT_A4H_TLS_PIN') {
  if (-not (Get-Item "env:$n" -ErrorAction SilentlyContinue)) {
    $v = [Environment]::GetEnvironmentVariable($n, 'User')
    if ($v) { Set-Item "env:$n" $v }
  }
}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tableArgs = @(); foreach ($t in $Tables) { $tableArgs += @('--tables', $t) }
python "$here\ddic_export.py" export @tableArgs --out $Out
if ($LASTEXITCODE -eq 0) { python "$here\ddic_export.py" compare --exports $Out --repo . }
exit $LASTEXITCODE
