param(
    [switch]$SkipDevDependencies
)

$ErrorActionPreference = "Stop"
$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BackendRoot = Join-Path $RepositoryRoot "backend"
$VenvRoot = Join-Path $BackendRoot ".venv"
$PythonExecutable = Join-Path $VenvRoot "Scripts\python.exe"

if (-not (Test-Path -LiteralPath $PythonExecutable)) {
    Write-Host "Creating Python virtual environment at $VenvRoot"
    python -m venv $VenvRoot
}

Write-Host "Installing JobEval backend dependencies"
& $PythonExecutable -m pip install --upgrade pip
if ($SkipDevDependencies) {
    & $PythonExecutable -m pip install -e $BackendRoot
} else {
    & $PythonExecutable -m pip install -e "${BackendRoot}[dev]"
}

Write-Host "Backend environment is ready."
Write-Host "Start it with: scripts\run_backend.ps1"
