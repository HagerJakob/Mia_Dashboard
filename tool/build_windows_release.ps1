$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot '..\.config\supabase.local.json'
if (-not (Test-Path $configPath)) {
  throw "Missing local Supabase config: $configPath"
}

$builtAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
$label = "windows-release-$($builtAt -replace '[:+]', '-')"

flutter build windows --release `
  --dart-define-from-file=$configPath `
  --dart-define=STUDYBUDDY_BUILD_LABEL=$label `
  --dart-define=STUDYBUDDY_BUILT_AT=$builtAt

$dist = Join-Path $PSScriptRoot "..\dist\StudyBuddy-Windows-$($builtAt -replace '[:+]', '-')"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item -Path (Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\*') -Destination $dist -Recurse -Force
"Build: $label`nBuilt at: $builtAt`nStart study_buddy.exe from this folder and keep data/ plus DLL files next to it." |
  Set-Content -Path (Join-Path $dist 'BUILD_INFO.txt') -Encoding UTF8

Write-Host "Windows release copied to $dist"
