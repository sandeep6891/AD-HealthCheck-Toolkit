<#
.SYNOPSIS
    Checks the health and reachability of Active Directory FSMO role holders.

.DESCRIPTION
    This function identifies which domain controllers hold each of the five FSMO roles
    (Schema Master, Domain Naming Master, PDC Emulator, RID Master, Infrastructure Master)
    and verifies each role holder is online and reachable. Helps catch situations where
    a FSMO role holder has been decommissioned or is unreachable, which can silently
    break AD operations like password resets, schema updates, or new object creation.

.PARAMETER OutputPath
    Optional path to export an HTML report. If omitted, results are only shown in console.

.EXAMPLE
    Test-FSMORoleHealth

.EXAMPLE
    Test-FSMORoleHealth -OutputPath "C:\Reports\FSMOHealth.html"

.NOTES
    Requires: ActiveDirectory PowerShell module
    Requires: Read access to forest and domain configuration
#>

function Test-FSMORoleHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        Write-Error "ActiveDirectory module not found. Install RSAT-AD-PowerShell and try again."
        return
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    Write-Verbose "Retrieving forest and domain FSMO role information..."

    try {
        $forest = Get-ADForest -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to retrieve forest/domain information: $($_.Exception.Message)"
        return
    }

    $fsmoRoles = @(
        [PSCustomObject]@{ RoleName = "Schema Master";          Holder = $forest.SchemaMaster;          Scope = "Forest" }
        [PSCustomObject]@{ RoleName = "Domain Naming Master";   Holder = $forest.DomainNamingMaster;    Scope = "Forest" }
        [PSCustomObject]@{ RoleName = "PDC Emulator";           Holder = $domain.PDCEmulator;           Scope = "Domain" }
        [PSCustomObject]@{ RoleName = "RID Master";             Holder = $domain.RIDMaster;              Scope = "Domain" }
        [PSCustomObject]@{ RoleName = "Infrastructure Master";  Holder = $domain.InfrastructureMaster;  Scope = "Domain" }
    )

    $results = @()

    foreach ($role in $fsmoRoles) {
        Write-Verbose "Checking $($role.RoleName) held by $($role.Holder)..."

        $status = "OK"
        $detail = "Role holder is reachable"

        if (-not $role.Holder) {
            $status = "MISSING"
            $detail = "No role holder found for this role"
        }
        else {
            $isReachable = Test-Connection -ComputerName $role.Holder -Count 1 -Quiet -ErrorAction SilentlyContinue

            if (-not $isReachable) {
                $status = "UNREACHABLE"
                $detail = "Role holder '$($role.Holder)' did not respond to ping. It may be offline or improperly decommissioned."
            }
            else {
                # Confirm it's still a valid, current domain controller
                try {
                    $null = Get-ADDomainController -Identity $role.Holder -ErrorAction Stop
                }
                catch {
                    $status = "REVIEW"
                    $detail = "Role holder '$($role.Holder)' responded to ping but could not be validated as an active domain controller."
                }
            }
        }

        $results += [PSCustomObject]@{
            Role   = $role.RoleName
            Scope  = $role.Scope
            Holder = $role.Holder
            Status = $status
            Detail = $detail
        }
    }

    # --- Console summary ---
    $issues = $results | Where-Object { $_.Status -in @("MISSING", "UNREACHABLE", "REVIEW") }

    Write-Host "`n=== AD FSMO Role Health Summary ===" -ForegroundColor Cyan
    Write-Host "Forest:           $($forest.Name)"
    Write-Host "Domain:           $($domain.DNSRoot)"
    Write-Host "Roles checked:    $($results.Count)"
    Write-Host "Issues found:     $($issues.Count)`n"

    if ($issues.Count -gt 0) {
        Write-Host "Issues detected:" -ForegroundColor Yellow
        $issues | Format-Table Role, Scope, Holder, Status, Detail -AutoSize
    } else {
        Write-Host "All FSMO roles are healthy and reachable." -ForegroundColor Green
    }

    $results | Format-Table Role, Scope, Holder, Status -AutoSize

    # --- Optional HTML export ---
    if ($OutputPath) {
        $htmlHeader = @"
<style>
    body { font-family: Segoe UI, Arial, sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background-color: #2c3e50; color: white; }
    tr.OK { background-color: #eafaf1; }
    tr.MISSING, tr.UNREACHABLE { background-color: #fdecea; }
    tr.REVIEW { background-color: #fff8e1; }
</style>
"@
        $htmlBody = $results | ConvertTo-Html -Head $htmlHeader -Title "AD FSMO Role Health Report - $(Get-Date)" -PreContent "<h2>AD FSMO Role Health Report</h2><p>Forest: $($forest.Name)</p><p>Domain: $($domain.DNSRoot)</p><p>Generated: $(Get-Date)</p>"
        $htmlBody | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Cyan
    }

    return $results
}
