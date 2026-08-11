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
- 🔜 **DNS Zone/Record Validation** — *(coming soon)*
- 🔜 **FSMO Role Health Check** — *(coming soon)*

## Requirements

- PowerShell 5.1 or later
- ActiveDirectory PowerShell module (RSAT-AD-PowerShell feature)
- Read access to AD replication metadata (typically Domain Admin or delegated permissions)

## Installation

Clone this repository or download the script directly:

    git clone https://github.com/sandeep6891/AD-HealthCheck-Toolkit.git

Then import the function:

    . .\Functions\Test-ADReplicationHealth.ps1

## Usage

**Basic check (console output only):**

    Test-ADReplicationHealth

**With HTML report export:**

    Test-ADReplicationHealth -OutputPath "C:\Reports\ADReplHealth.html"

**With a custom staleness threshold (e.g., flag anything older than 12 hours):**

    Test-ADReplicationHealth -MaxReplicationAgeHours 12

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
- [ ] DNS zone and record validation
- [ ] FSMO role holder health check
- [ ] Combined module (.psm1) for one-line import of all checks

## Notes

This is an evolving project — I'm adding DNS and FSMO checks next based on what I've found 
most useful in real environments. Feedback and PRs welcome.

## License

MIT License — free to use, modify, and distribute.

## Author

**Sandeep Kumar Reddy Lingampalli**
Enterprise IT Infrastructure | Cloud & Virtualization | Active Directory, Azure, VMware
[LinkedIn](https://www.linkedin.com/in/sandeep-kumar-reddy-744a5b66/)
