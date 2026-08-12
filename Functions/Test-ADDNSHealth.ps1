<#
.SYNOPSIS
    Validates DNS health for Active Directory-integrated zones and domain controller records.

.DESCRIPTION
    This function checks that critical AD-related DNS records (SRV records for domain
    controllers, A records, and AD-integrated zone replication) are present and consistent
    across domain controllers. Helps catch DNS misconfigurations that can cause authentication,
    replication, or Group Policy failures.

.PARAMETER OutputPath
    Optional path to export an HTML report. If omitted, results are only shown in console.

.EXAMPLE
    Test-ADDNSHealth

.EXAMPLE
    Test-ADDNSHealth -OutputPath "C:\Reports\ADDNSHealth.html"

.NOTES
    Requires: ActiveDirectory and DnsServer PowerShell modules
    Requires: Read access to DNS zones and AD replication metadata
    Recommended: Run from or against a domain controller with DNS Server role installed
#>

function Test-ADDNSHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    foreach ($module in @('ActiveDirectory', 'DnsServer')) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Error "$module module not found. Install RSAT-AD-PowerShell / RSAT-DNS-Server and try again."
            return
        }
        Import-Module $module -ErrorAction Stop
    }

    $domain = Get-ADDomain
    $domainDNSName = $domain.DNSRoot
    $domainControllers = Get-ADDomainController -Filter *

    if (-not $domainControllers) {
        Write-Error "No domain controllers found. Check connectivity and permissions."
        return
    }

    $results = @()

    # --- Check 1: SRV records for domain controller location ---
    Write-Verbose "Checking critical SRV records..."
    $srvRecordsToCheck = @(
        "_ldap._tcp.dc._msdcs.$domainDNSName",
        "_kerberos._tcp.dc._msdcs.$domainDNSName",
        "_ldap._tcp.$domainDNSName",
        "_gc._tcp.$domainDNSName"
    )

    foreach ($srv in $srvRecordsToCheck) {
        try {
            $srvResult = Resolve-DnsName -Name $srv -Type SRV -ErrorAction Stop
            $count = ($srvResult | Where-Object { $_.Type -eq 'SRV' }).Count
            $results += [PSCustomObject]@{
                CheckType = "SRV Record"
                Target    = $srv
                Status    = if ($count -gt 0) { "OK" } else { "MISSING" }
                Detail    = "$count SRV record(s) found"
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "SRV Record"
                Target    = $srv
                Status    = "MISSING"
                Detail    = "Resolution failed: $($_.Exception.Message)"
            }
        }
    }

    # --- Check 2: A record for each domain controller ---
    Write-Verbose "Checking A records for each domain controller..."
    foreach ($dc in $domainControllers) {
        try {
            $aResult = Resolve-DnsName -Name $dc.HostName -Type A -ErrorAction Stop
            $resolvedIP = ($aResult | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1).IPAddress

            $status = "OK"
            $detail = "Resolves to $resolvedIP"

            if ($dc.IPv4Address -and $resolvedIP -ne $dc.IPv4Address) {
                $status = "MISMATCH"
                $detail = "DNS resolves to $resolvedIP, but AD reports IP as $($dc.IPv4Address)"
            }

            $results += [PSCustomObject]@{
                CheckType = "A Record"
                Target    = $dc.HostName
                Status    = $status
                Detail    = $detail
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "A Record"
                Target    = $dc.HostName
                Status    = "MISSING"
                Detail    = "Could not resolve: $($_.Exception.Message)"
            }
        }
    }

    # --- Check 3: Forward/reverse lookup consistency (PTR check) ---
    Write-Verbose "Checking PTR record consistency..."
    foreach ($dc in $domainControllers) {
        if (-not $dc.IPv4Address) { continue }

        try {
            $ptrResult = Resolve-DnsName -Name $dc.IPv4Address -Type PTR -ErrorAction Stop
            $ptrHost = ($ptrResult | Where-Object { $_.Type -eq 'PTR' } | Select-Object -First 1).NameHost

            $status = "OK"
            $detail = "PTR resolves to $ptrHost"

            if ($ptrHost -notlike "$($dc.HostName)*") {
                $status = "MISMATCH"
                $detail = "PTR resolves to '$ptrHost', expected '$($dc.HostName)'"
            }

            $results += [PSCustomObject]@{
                CheckType = "PTR Record"
                Target    = $dc.IPv4Address
                Status    = $status
                Detail    = $detail
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "PTR Record"
                Target    = $dc.IPv4Address
                Status    = "MISSING"
                Detail    = "No PTR record found: $($_.Exception.Message)"
            }
        }
    }

    # --- Check 4: AD-integrated zone replication scope consistency ---
    Write-Verbose "Checking AD-integrated DNS zone configuration on each DC..."
    foreach ($dc in $domainControllers) {
        try {
            $zone = Get-DnsServerZone -ComputerName $dc.HostName -Name $domainDNSName -ErrorAction Stop
            $status = if ($zone.ZoneType -eq 'Primary' -and $zone.IsDsIntegrated) { "OK" } else { "REVIEW" }
            $detail = "ZoneType: $($zone.ZoneType), DS-Integrated: $($zone.IsDsIntegrated), ReplicationScope: $($zone.ReplicationScope)"

            $results += [PSCustomObject]@{
                CheckType = "DNS Zone Config"
                Target    = $dc.HostName
                Status    = $status
                Detail    = $detail
            }
        }
        catch {
            $results += [PSCustomObject]@{
                CheckType = "DNS Zone Config"
                Target    = $dc.HostName
                Status    = "ERROR"
                Detail    = "Could not query DNS zone: $($_.Exception.Message)"
            }
        }
    }

    # --- Console summary ---
    $issues = $results | Where-Object { $_.Status -in @("MISSING", "MISMATCH", "ERROR", "REVIEW") }

    Write-Host "`n=== AD DNS Health Summary ===" -ForegroundColor Cyan
    Write-Host "Domain:                 $domainDNSName"
    Write-Host "Domain Controllers:     $($domainControllers.Count)"
    Write-Host "Checks performed:       $($results.Count)"
    Write-Host "Issues found:           $($issues.Count)`n"

    if ($issues.Count -gt 0) {
        Write-Host "Issues detected:" -ForegroundColor Yellow
        $issues | Format-Table CheckType, Target, Status, Detail -AutoSize
    } else {
        Write-Host "No DNS issues detected." -ForegroundColor Green
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
    tr.MISSING, tr.ERROR { background-color: #fdecea; }
    tr.MISMATCH, tr.REVIEW { background-color: #fff8e1; }
</style>
"@
        $htmlBody = $results | ConvertTo-Html -Head $htmlHeader -Title "AD DNS Health Report - $(Get-Date)" -PreContent "<h2>AD DNS Health Report</h2><p>Domain: $domainDNSName</p><p>Generated: $(Get-Date)</p>"
        $htmlBody | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Cyan
    }

    return $results
}
