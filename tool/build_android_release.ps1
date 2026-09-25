$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '..\.config\supabase.local.json'
if (-not (Test-Path $configPath)) {
  throw "Missing local Supabase config: $configPath"
}

$builtAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
$label = "android-release-$($builtAt -replace '[:+]', '-')"

flutter build apk --release `
  --dart-define-from-file=$configPath `
  --dart-define=STUDYBUDDY_BUILD_LABEL=$label `
  --dart-define=STUDYBUDDY_BUILT_AT=$builtAt

Write-Host "Android release built at build\app\outputs\flutter-apk\app-release.apk"
