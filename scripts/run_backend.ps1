param(
    [string]$HostAddress = "127.0.0.1",
    [int]$Port = 8000,
    [switch]$NoReload
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BackendRoot = Join-Path $RepositoryRoot "backend"
$PythonExecutable = Join-Path $BackendRoot ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $PythonExecutable)) {
    throw "Backend virtual environment not found. Run scripts\setup_backend.ps1 first."
}

$arguments = @("-m", "uvicorn", "app.main:app", "--host", $HostAddress, "--port", $Port)
if (-not $NoReload) {
    $arguments += "--reload"
}

Push-Location $BackendRoot
try {
    & $PythonExecutable @arguments
} finally {
    Pop-Location
}
