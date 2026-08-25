<#
.SYNOPSIS
    Runs all AD health checks and emails a combined HTML report.

.DESCRIPTION
    This function runs Test-ADReplicationHealth, Test-ADDNSHealth, and 
    Test-FSMORoleHealth, combines the results into a single HTML report, 
    and emails it via SMTP. Useful for scheduled, unattended health monitoring.

.PARAMETER SmtpServer
    The SMTP server to send the report through.

.PARAMETER From
    The sender email address.

.PARAMETER To
    One or more recipient email addresses.

.PARAMETER Subject
    Optional custom subject line. Defaults to a date-stamped subject, with an 
    "[ACTION NEEDED]" prefix automatically added if issues are found.

.PARAMETER SmtpPort
    SMTP port. Defaults to 25.

.PARAMETER UseSsl
    Use SSL/TLS for the SMTP connection.

.EXAMPLE
    Send-ADHealthReport -SmtpServer "mail.contoso.com" -From "adhealth@contoso.com" -To "it-team@contoso.com"

.EXAMPLE
    Send-ADHealthReport -SmtpServer "smtp.office365.com" -From "adhealth@contoso.com" -To "it-team@contoso.com" -SmtpPort 587 -UseSsl

.NOTES
    Author: Sandeep Kumar Reddy Lingampalli
    GitHub: https://github.com/sandeep6891/AD-HealthCheck-Toolkit
    Requires: ActiveDirectory and DnsServer PowerShell modules (RSAT)
    Requires: SMTP relay access from the machine running this script
#>

function Send-ADHealthReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SmtpServer,

        [Parameter(Mandatory = $true)]
        [string]$From,

        [Parameter(Mandatory = $true)]
        [string[]]$To,

        [Parameter(Mandatory = $false)]
        [string]$Subject = "AD Health Check Report - $(Get-Date -Format 'yyyy-MM-dd')",

        [Parameter(Mandatory = $false)]
        [int]$SmtpPort = 25,

        [Parameter(Mandatory = $false)]
        [switch]$UseSsl
    )

    Write-Verbose "Running all AD health checks..."

    $replicationResults = Test-ADReplicationHealth
    $dnsResults = Test-ADDNSHealth
    $fsmoResults = Test-FSMORoleHealth

    $style = @"
<style>
    body { font-family: Segoe UI, Arial, sans-serif; }
    h2 { color: #2c3e50; }
    table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
    th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; }
    th { background-color: #2c3e50; color: white; }
</style>
"@

    $body = $style
    $body += "<h1>Active Directory Health Report - $(Get-Date)</h1>"

    $body += "<h2>Replication Health</h2>"
    $body += ($replicationResults | ConvertTo-Html -Fragment)

    $body += "<h2>DNS Health</h2>"
    $body += ($dnsResults | ConvertTo-Html -Fragment)

    $body += "<h2>FSMO Role Health</h2>"
    $body += ($fsmoResults | ConvertTo-Html -Fragment)

    $allResults = @($replicationResults) + @($dnsResults) + @($fsmoResults)
    $issueCount = ($allResults | Where-Object { $_.Status -ne "OK" }).Count

    if ($issueCount -gt 0) {
        $Subject = "[ACTION NEEDED] $Subject - $issueCount issue(s) found"
    }

    $mailParams = @{
        SmtpServer = $SmtpServer
        Port       = $SmtpPort
        From       = $From
        To         = $To
        Subject    = $Subject
        Body       = $body
        BodyAsHtml = $true
    }

    if ($UseSsl) {
        $mailParams.UseSsl = $true
    }

    try {
        Send-MailMessage @mailParams -ErrorAction Stop
        Write-Host "Report emailed successfully to $($To -join ', ')" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send email: $($_.Exception.Message)"
    }
}
