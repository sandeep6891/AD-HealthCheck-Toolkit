# AD-HealthCheck-Toolkit

A PowerShell toolkit for proactive Active Directory health monitoring — helping sysadmins catch replication, DNS, and FSMO role issues before they cause outages.

## Why this exists

During my time managing enterprise AD environments with 1000+ servers, I saw how easily 
replication issues could go unnoticed until they caused real problems — a stale replication 
link between sites, for example, isn't always obvious until users start seeing inconsistent 
group policy or authentication failures. I built this toolkit to make these checks fast and 
repeatable, so issues get caught early instead of during an incident.

## Features

- ✅ **Replication Health Check** — identifies domain controllers with failing, stale, or unknown replication status
- ✅ **DNS Zone/Record Validation** — checks SRV records, A records, PTR consistency, and AD-integrated zone configuration
- ✅ **FSMO Role Health Check** — verifies all 5 FSMO role holders are assigned, online, and reachable

## Requirements

- PowerShell 5.1 or later
- ActiveDirectory PowerShell module (RSAT-AD-PowerShell feature)
- DnsServer PowerShell module (RSAT-DNS-Server feature) — required for DNS health checks
- Read access to AD replication metadata, DNS zones, and forest/domain configuration (typically Domain Admin or delegated permissions)

## Installation

Clone this repository or download the scripts directly:

    git clone https://github.com/sandeep6891/AD-HealthCheck-Toolkit.git

**Option A — Import the full module (recommended):**

    Import-Module .\AD-HealthCheck-Toolkit.psm1

This makes all three functions available: `Test-ADReplicationHealth`, `Test-ADDNSHealth`, `Test-FSMORoleHealth`.

**Option B — Import individual scripts:**

    . .\Functions\Test-ADReplicationHealth.ps1
    . .\Functions\Test-ADDNSHealth.ps1
    . .\Functions\Test-FSMORoleHealth.ps1

## Usage

**Replication health check:**

    Test-ADReplicationHealth

**With HTML report export:**

    Test-ADReplicationHealth -OutputPath "C:\Reports\ADReplHealth.html"

**With a custom staleness threshold (e.g., flag anything older than 12 hours):**

    Test-ADReplicationHealth -MaxReplicationAgeHours 12

**DNS health check:**

    Test-ADDNSHealth

**With HTML report export:**

    Test-ADDNSHealth -OutputPath "C:\Reports\ADDNSHealth.html"

**FSMO role health check:**

    Test-FSMORoleHealth

**With HTML report export:**

    Test-FSMORoleHealth -OutputPath "C:\Reports\FSMOHealth.html"

## Sample Output

    === AD Replication Health Summary ===
    Domain Controllers checked: 4
    Replication links checked:  12
    Issues found:               1

    Issues detected:
    SourceDC        Partner         Status   Detail
    --------        -------         ------   ------
    DC02.corp.local DC01.corp.local STALE    Last success was 30.2 hours ago (threshold: 24 hrs).

## Roadmap

- [x] Replication health check
- [x] DNS zone and record validation
- [x] FSMO role holder health check
- [x] Combined module (.psm1) for one-line import of all checks

## Notes

This is an evolving project — feedback, issues, and PRs are welcome. Future ideas include 
Group Policy health checks and a scheduled-task/reporting wrapper for automated monitoring.

## License

MIT License — free to use, modify, and distribute.

## Author

**Sandeep Kumar Reddy Lingampalli**
Enterprise IT Infrastructure | Cloud & Virtualization | Active Directory, Azure, VMware
[LinkedIn](https://www.linkedin.com/in/sandeep-kumar-reddy-744a5b66/)
