# diegema-sync: builds the CLI on first use (or when its sources change),
# then runs it. Usage: tool\diegema-sync.ps1 <status|devices|log|peers|sync> [options]
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'build/diegema-sync-cli/bundle/bin/diegema_sync.exe'
$stale = -not (Test-Path $exe)
if (-not $stale) {
  $built = (Get-Item $exe).LastWriteTime
  $sources = @('bin', 'lib/sync', 'lib/sync_cli', 'lib/database') |
    ForEach-Object { Get-ChildItem -Recurse -File (Join-Path $root $_) }
  $sources += Get-Item (Join-Path $root 'pubspec.lock')
  $stale = [bool]($sources | Where-Object { $_.LastWriteTime -gt $built })
}
if ($stale) {
  Push-Location $root
  try { dart build cli -t bin/diegema_sync.dart -o build/diegema-sync-cli | Out-Null }
  finally { Pop-Location }
}
& $exe @args
exit $LASTEXITCODE
