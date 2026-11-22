param(
    [string]$Device = "chrome",
    [string]$ApiBaseUrl = "http://127.0.0.1:8000/api/v1"
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$FrontendRoot = Join-Path $RepositoryRoot "frontend"

Push-Location $FrontendRoot
try {
    flutter pub get
    flutter run -d $Device --dart-define=API_BASE_URL=$ApiBaseUrl
} finally {
    Pop-Location
}
