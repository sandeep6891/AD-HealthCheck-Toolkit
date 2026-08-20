<#
.SYNOPSIS
    AD-HealthCheck-Toolkit - a PowerShell module for proactive Active Directory health monitoring.

.DESCRIPTION
    This module loads all AD health check functions from the Functions folder,
    making them available after a single Import-Module call. Includes:
      - Test-ADReplicationHealth
      - Test-ADDNSHealth
      - Test-FSMORoleHealth

.NOTES
    Author: Sandeep Kumar Reddy Lingampalli
    GitHub: https://github.com/sandeep6891/AD-HealthCheck-Toolkit
    Requires: ActiveDirectory and DnsServer PowerShell modules (RSAT)
#>

$FunctionFolder = Join-Path -Path $PSScriptRoot -ChildPath 'Functions'

if (-not (Test-Path -Path $FunctionFolder)) {
    Write-Error "Functions folder not found at path: $FunctionFolder"
    return
}

$FunctionFiles = Get-ChildItem -Path $FunctionFolder -Filter '*.ps1' -File -ErrorAction SilentlyContinue

if (-not $FunctionFiles) {
    Write-Warning "No function files found in $FunctionFolder"
}

foreach ($file in $FunctionFiles) {
    try {
        . $file.FullName
        Write-Verbose "Loaded function file: $($file.Name)"
    }
    catch {
        Write-Error "Failed to load $($file.Name): $($_.Exception.Message)"
    }
}

# Explicitly export the public functions
Export-ModuleMember -Function @(
    'Test-ADReplicationHealth',
    'Test-ADDNSHealth',
    'Test-FSMORoleHealth'
)
