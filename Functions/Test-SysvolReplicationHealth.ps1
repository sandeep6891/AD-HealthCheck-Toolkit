<#
.SYNOPSIS
    Checks SYSVOL replication health via DFSR (or legacy FRS) across domain controllers.

.DESCRIPTION
    This function checks the health of SYSVOL replication, which is responsible for
    keeping Group Policy Objects and logon scripts consistent across all domain
    controllers. It reports on DFSR replication backlog per DC, detects whether the
    domain is still using legacy FRS instead of DFSR, and flags DCs where SYSVOL
    content appears out of sync. SYSVOL drift is a common, easy-to-miss cause of
    "this Group Policy setting applies on some machines but not others" symptoms.

.PARAMETER OutputPath
    Optional path to export an HTML report. If omitted, results are only shown in console.

.PARAMETER MaxBacklogCount
    Threshold for flagging a DFSR backlog as excessive. Default is 10 pending files.

.EXAMPLE
    Test-SysvolReplicationHealth

.EXAMPLE
    Test-SysvolReplicationHealth -OutputPath "C:\Reports\SysvolHealth.html" -MaxBacklogCount 25

.NOTES
    Author: Sandeep Kumar Reddy Lingampalli
    GitHub: https://github.com/sandeep6891/AD-HealthCheck-Toolkit
    Requires: ActiveDirectory PowerShell module (RSAT-AD-PowerShell)
    Requires: DFSR management tools (dfsrdiag.exe, present on domain controllers / RSAT-DFS-Mgmt-Con)
    Credit: Feature scoped based on community feedback — see Issue #1 on GitHub
#>

function Test-SysvolReplicationHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [int]$MaxBacklogCount = 10
    )

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Error "ActiveDirectory module not found. Install RSAT-AD-PowerShell and try again."
        return
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    $domain = Get-ADDomain
    $domainControllers = Get-ADDomainController -Filter *

    if (-not $domainControllers) {
        Write-Error "No domain controllers found. Check connectivity and permissions."
        return
    }

    $results = @()

    # --- Check 1: Detect legacy FRS vs DFSR migration state ---
    Write-Verbose "Checking SYSVOL replication migration state (FRS vs DFSR)..."
    try {
        $ntfrsMigration = Get-ADObject -Identity "CN=DFSR-GlobalSettings,CN=System,$($domain.DistinguishedName)" -Properties msDFSR-Flags -ErrorAction Stop
        $migrationState = "DFSR (migrated)"
        $migrationStatus = "OK"
        $migrationDetail = "Domain is using DFSR for SYSVOL replication."
    }
    catch {
        $migrationState = "Unknown / Possibly legacy FRS"
        $migrationStatus = "REVIEW"
        $migrationDetail = "Could not confirm DFSR-GlobalSettings object. Domain may still be using legacy FRS, which Microsoft has deprecated."
    }

    $results += [PSCustomObject]@{
        CheckType = "Migration State"
        Target    = $domain.DNSRoot
        Status    = $migrationStatus
        Detail    = "$migrationDetail (State: $migrationState)"
    }

    # --- Check 2: DFSR replication backlog per DC ---
    Write-Verbose "Checking DFSR replication backlog per domain controller..."
    foreach ($dc in $domainControllers) {
        try {
            $backlogOutput = dfsrdiag backlog /rgname:"Domain System Volume" /rfname:"SYSVOL Share" /sendingmember:$($dc.HostName) /receivingmember:$($dc.HostName) 2>&1

            $backlogCount = 0
            if ($backlogOutput -match "Backlog File count:\s*(\d+)") {
                $backlogCount = [int]$Matches[1]
            }

            $status = "OK"
            $detail = "Backlog: $backlogCount file(s)"

            if ($backlogCount -gt $MaxBacklogCount) {
                $status = "BACKLOG"
                $detail = "Backlog of $backlogCount file(s) exceeds threshold ($MaxBacklogCount). May indicate replication lag or failure."
            }

            $results += [PSCustomObject]@{
                CheckType = "DFSR Backlog"
                Target    = $dc.HostName
                Status    = $status
                Detail    = $detail
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "DFSR Backlog"
                Target    = $dc.HostName
                Status    = "ERROR"
                Detail    = "Could not query DFSR backlog: $($_.Exception.Message)"
            }
        }
    }

    # --- Check 3: SYSVOL content consistency across DCs (file/folder count comparison) ---
    Write-Verbose "Checking SYSVOL content consistency across domain controllers..."
    $sysvolCounts = @()

    foreach ($dc in $domainControllers) {
        try {
            $sysvolPath = "\\$($dc.HostName)\SYSVOL\$($domain.DNSRoot)\Policies"
            $itemCount = (Get-ChildItem -Path $sysvolPath -Recurse -ErrorAction Stop -Force).Count

            $sysvolCounts += [PSCustomObject]@{
                DC    = $dc.HostName
                Count = $itemCount
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "SYSVOL Content"
                Target    = $dc.HostName
                Status    = "ERROR"
                Detail    = "Could not access SYSVOL path: $($_.Exception.Message)"
            }
        }
    }

    if ($sysvolCounts.Count -gt 1) {
        $baseline = ($sysvolCounts | Group-Object Count | Sort-Object Count -Descending | Select-Object -First 1).Name

        foreach ($entry in $sysvolCounts) {
            $status = "OK"
            $detail = "$($entry.Count) items under Policies (matches majority baseline)"

            if ($entry.Count -ne [int]$baseline) {
                $status = "MISMATCH"
                $detail = "$($entry.Count) items under Policies, but majority baseline is $baseline — possible SYSVOL drift."
            }

            $results += [PSCustomObject]@{
                CheckType = "SYSVOL Content"
                Target    = $entry.DC
                Status    = $status
                Detail    = $detail
            }
        }
    }

    # --- Console summary ---
    $issues = $results | Where-Object { $_.Status -in @("BACKLOG", "MISMATCH", "ERROR", "REVIEW") }

    Write-Host "`n=== SYSVOL Replication Health Summary ===" -ForegroundColor Cyan
    Write-Host "Domain:                 $($domain.DNSRoot)"
    Write-Host "Domain Controllers:     $($domainControllers.Count)"
    Write-Host "Checks performed:       $($results.Count)"
    Write-Host "Issues found:           $($issues.Count)`n"

    if ($issues.Count -gt 0) {
        Write-Host "Issues detected:" -ForegroundColor Yellow
        $issues | Format-Table CheckType, Target, Status, Detail -AutoSize
    } else {
        Write-Host "No SYSVOL replication issues detected." -ForegroundColor Green
    }

    # --- Optional HTML export ---
    if ($OutputPath) {
        $htmlHeader = @"
<style>
    body { font-family: Segoe UI, Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background-color: #2c3e50; color: white; }
    tr.OK { background-color: #eafaf1; }
    tr.BACKLOG, tr.MISMATCH, tr.ERROR { background-color: #fdecea; }
    tr.REVIEW { background-color: #fff8e1; }
</style>
"@
        $htmlBody = $results | ConvertTo-Html -Head $htmlHeader -Title "SYSVOL Replication Health Report - $(Get-Date)" -PreContent "<h2>SYSVOL Replication Health Report</h2><p>Domain: $($domain.DNSRoot)</p><p>Generated: $(Get-Date)</p>"
        $htmlBody | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Cyan
    }

    return $results
}
