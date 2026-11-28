param(
    [string]$OutputPath = "environment-report.txt"
)

$ErrorActionPreference = "Continue"
$lines = [System.Collections.Generic.List[string]]::new()

$lines.Add("JobEval environment report")
$lines.Add("Generated: $([DateTime]::UtcNow.ToString('o'))")
$lines.Add("OS: $((Get-CimInstance Win32_OperatingSystem).Caption) $((Get-CimInstance Win32_OperatingSystem).Version)")
$lines.Add("CPU: $((Get-CimInstance Win32_Processor).Name)")
$lines.Add("RAM bytes: $((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory)")
$lines.Add("")

foreach ($command in @(
    @{ Name = "git"; Arguments = @("--version") },
    @{ Name = "python"; Arguments = @("--version") },
    @{ Name = "flutter"; Arguments = @("--version") },
    @{ Name = "dart"; Arguments = @("--version") },
    @{ Name = "java"; Arguments = @("-version") }
)) {
    try {
        $output = & $command.Name @($command.Arguments) 2>&1 | Out-String
        $lines.Add("--- $($command.Name) ---")
        $lines.Add($output.Trim())
    } catch {
        $lines.Add("--- $($command.Name) ---")
        $lines.Add("Unavailable: $($_.Exception.Message)")
    }
    $lines.Add("")
}

$lines | Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Host "Environment report written to $OutputPath"
