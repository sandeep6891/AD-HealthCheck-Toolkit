<#
.SYNOPSIS
    Checks Active Directory replication health across all domain controllers in the domain.

.DESCRIPTION
    This function queries AD replication partner metadata and replication failure data
    to identify domain controllers with replication issues, stale replication, or
    consecutive failures. Outputs a summary report to the console and optionally to HTML.

.PARAMETER OutputPath
    Optional path to export an HTML report. If omitted, results are only shown in console.

.PARAMETER MaxReplicationAgeHours
    Threshold (in hours) beyond which last successful replication is flagged as stale.
    Default is 24 hours.

.EXAMPLE
    Test-ADReplicationHealth

.EXAMPLE
    Test-ADReplicationHealth -OutputPath "C:\Reports\ADReplHealth.html" -MaxReplicationAgeHours 12

.NOTES
    Requires: ActiveDirectory PowerShell module (RSAT-AD-PowerShell)
    Requires: Domain Admin or delegated read access to replication metadata
#>

function Test-ADReplicationHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxReplicationAgeHours = 24
    )

    # Ensure the ActiveDirectory module is available
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Error "ActiveDirectory module not found. Install RSAT-AD-PowerShell and try again."
        return
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    Write-Verbose "Retrieving list of domain controllers..."
    $domainControllers = Get-ADDomainController -Filter *

    if (-not $domainControllers) {
        Write-Error "No domain controllers found. Check connectivity and permissions."
        return
    }

    $results = @()
    $now = Get-Date

    foreach ($dc in $domainControllers) {
        Write-Verbose "Checking replication metadata for $($dc.HostName)..."

        try {
            $partnerMetadata = Get-ADReplicationPartnerMetadata -Target $dc.HostName -ErrorAction Stop
        }
        catch {
            # DC unreachable or replication metadata query failed
            $results += [PSCustomObject]@{
                SourceDC              = $dc.HostName
                Partner               = "N/A"
                LastReplicationSuccess = "N/A"
                LastReplicationResult  = "ERROR"
                ConsecutiveFailures    = "N/A"
                Status                 = "UNREACHABLE"
                Detail                 = $_.Exception.Message
            }
            continue
        }

        foreach ($partner in $partnerMetadata) {
            $hoursSinceSuccess = if ($partner.LastReplicationSuccess) {
                [math]::Round((New-TimeSpan -Start $partner.LastReplicationSuccess -End $now).TotalHours, 1)
            } else {
                $null
            }

            $status = "OK"
            $detail = ""

            if ($partner.ConsecutiveReplicationFailures -gt 0) {
                $status = "FAILING"
                $detail = "Consecutive failures: $($partner.ConsecutiveReplicationFailures). Last result: $($partner.LastReplicationResult)"
            }
            elseif ($null -eq $hoursSinceSuccess) {
                $status = "UNKNOWN"
                $detail = "No successful replication recorded."
            }
            elseif ($hoursSinceSuccess -gt $MaxReplicationAgeHours) {
                $status = "STALE"
                $detail = "Last success was $hoursSinceSuccess hours ago (threshold: $MaxReplicationAgeHours hrs)."
            }

            $results += [PSCustomObject]@{
                SourceDC               = $dc.HostName
                Partner                = $partner.Partner
                LastReplicationSuccess = $partner.LastReplicationSuccess
                LastReplicationResult  = $partner.LastReplicationResult
                ConsecutiveFailures    = $partner.ConsecutiveReplicationFailures
                Status                 = $status
                Detail                 = $detail
            }
        }
    }

    # Console summary
    $failing = $results | Where-Object { $_.Status -in @("FAILING", "STALE", "UNREACHABLE", "UNKNOWN") }

    Write-Host "`n=== AD Replication Health Summary ===" -ForegroundColor Cyan
    Write-Host "Domain Controllers checked: $($domainControllers.Count)"
    Write-Host "Replication links checked:  $($results.Count)"
    Write-Host "Issues found:               $($failing.Count)`n"

    if ($failing.Count -gt 0) {
        Write-Host "Issues detected:" -ForegroundColor Yellow
        $failing | Format-Table SourceDC, Partner, Status, Detail -AutoSize
    } else {
        Write-Host "No replication issues detected." -ForegroundColor Green
    }

    # Optional HTML export
    if ($OutputPath) {
        $htmlHeader = @"
<style>
    body { font-family: Segoe UI, Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background-color: #2c3e50; color: white; }
    tr.OK { background-color: #eafaf1; }
    tr.FAILING, tr.UNREACHABLE { background-color: #fdecea; }
    tr.STALE, tr.UNKNOWN { background-color: #fff8e1; }
</style>
"@
        $htmlBody = $results | ConvertTo-Html -Head $htmlHeader -Title "AD Replication Health Report - $now" -PreContent "<h2>AD Replication Health Report</h2><p>Generated: $now</p>"
        $htmlBody | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Cyan
    }

    return $results
}
