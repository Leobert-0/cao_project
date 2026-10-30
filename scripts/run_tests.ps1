param([switch]$Quick, [string]$Python = 'python')
$ErrorActionPreference = 'Stop'
$runnerArgs = @((Join-Path $PSScriptRoot 'run_tests.py'))
if ($Quick) { $runnerArgs += '--quick' }
& $Python @runnerArgs
exit $LASTEXITCODE
