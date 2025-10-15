# Example: Basic usage
.\Check-SCEPProfiles.ps1 -DeviceName "DESKTOP-ABC123"

# Example: With verbose output
.\Check-SCEPProfiles.ps1 -DeviceName "LAPTOP-XYZ789" -Verbose

# Example: Checking multiple devices (loop)
$devices = @("DESKTOP-ABC123", "LAPTOP-XYZ789", "WORKSTATION-001")
foreach ($device in $devices) {
    Write-Host "`n`n=== Checking device: $device ===" -ForegroundColor Magenta
    .\Check-SCEPProfiles.ps1 -DeviceName $device
}

# Example: Export results to file
.\Check-SCEPProfiles.ps1 -DeviceName "DESKTOP-ABC123" | Out-File -FilePath "scep-report.txt"

# Example: Run with error handling
try {
    .\Check-SCEPProfiles.ps1 -DeviceName "DESKTOP-ABC123"
} catch {
    Write-Error "Failed to check SCEP profiles: $_"
}
