@{
    # Module info
    RootModule        = 'AD-HealthCheck-Toolkit.psm1'
    ModuleVersion      = '1.0.0'
    GUID               = 'bee307ac-009c-457c-a50f-f12a932720db'
    Author             = 'Sandeep Kumar Reddy Lingampalli'
    CompanyName        = 'Unknown'
    Copyright          = '(c) 2026 Sandeep Kumar Reddy Lingampalli. All rights reserved.'
    Description        = 'A PowerShell toolkit for proactive Active Directory health monitoring - checks replication health, DNS zone/record validation, and FSMO role holder reachability to help sysadmins catch issues before they cause outages.'

    # Minimum PowerShell version required
    PowerShellVersion  = '5.1'

    # Functions to export from this module
    FunctionsToExport  = @(
        'Test-ADReplicationHealth',
        'Test-ADDNSHealth',
        'Test-FSMORoleHealth'
    )

    # Cmdlets, variables, aliases - none exported explicitly
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Private data for PowerShell Gallery metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('ActiveDirectory', 'DNS', 'FSMO', 'Replication', 'SysAdmin', 'Monitoring', 'Health-Check', 'Windows')
            LicenseUri   = 'https://github.com/sandeep6891/AD-HealthCheck-Toolkit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/sandeep6891/AD-HealthCheck-Toolkit'
            ReleaseNotes = 'Initial release: includes AD replication health check, DNS zone/record validation, and FSMO role holder health check.'
        }
    }
}
