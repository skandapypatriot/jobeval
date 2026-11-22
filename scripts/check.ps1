$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BackendRoot = Join-Path $RepositoryRoot "backend"
$FrontendRoot = Join-Path $RepositoryRoot "frontend"
$PythonExecutable = Join-Path $BackendRoot ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $PythonExecutable)) {
    throw "Backend virtual environment not found. Run scripts\setup_backend.ps1 first."
}

Push-Location $BackendRoot
try {
    & $PythonExecutable -m ruff format --check app tests
    & $PythonExecutable -m ruff check app tests
    & $PythonExecutable -m pytest -q
} finally {
    Pop-Location
}

Push-Location $FrontendRoot
try {
    dart format --output=none --set-exit-if-changed lib test
    flutter analyze
    flutter test
} finally {
    Pop-Location
}

Write-Host "All JobEval checks passed."
