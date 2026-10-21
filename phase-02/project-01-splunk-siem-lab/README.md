# Splunk Enterprise SIEM Lab - Detecting Real Attacks on a Cloud VM

![Azure](https://img.shields.io/badge/Azure-free%20tier-0078D4?style=flat-square&logo=microsoftazure&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu%20Server-24.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)
![Splunk](https://img.shields.io/badge/Splunk-Enterprise%209.4.1-000000?style=flat-square&logo=splunk&logoColor=white)
![SPL](https://img.shields.io/badge/SPL-3%20detections-65A637?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel (CyberJKD) |
| **Date** | June 7, 2026 |
| **Platform** | Azure Free Account VM · Ubuntu Server 24.04 LTS |
| **Lab Source** | CloudTechExec - 5 Labs To Get You Hired · Lab 3 |
| **Roadmap** | [Phase 02 · Lab 01](https://dallasamuel.github.io/CyberJKD-Roadmap) |

---

## Objective

Deploy Splunk Enterprise 9.4.1 on an Azure VM, ingest live Linux authentication logs, write SPL detection queries, build a scheduled alert, and create the CyberJKD Security Monitor dashboard - visualizing real external attack activity detected within hours of deployment.

## Business Problem This Lab Solves

Every security team needs visibility. Without a SIEM, attacks happen silently - no alerts, no timeline, no evidence. This lab builds the core skill that SOC analysts use every day: ingesting logs, writing detection logic, and turning raw events into actionable intelligence.

| Role | How this applies |
|------|-----------------|
| SOC Analyst | Core daily tool - ingest logs, write SPL queries, build detection rules, respond to alerts |
| Cloud Security Engineer | Splunk on Azure is a real enterprise deployment pattern - same architecture used at scale |
| Junior Security Engineer | SIEM experience is the #1 differentiator at entry level - most candidates have never touched it |
| Incident Responder | Dashboard and alert workflow mirrors real IR triage process |

## What This Lab Covers

| Skill | Detail |
|-------|--------|
| Azure VM deployment | Ubuntu Server 24.04 on Azure with NSG configuration |
| Splunk installation | Enterprise 9.4.1 installed via .deb package on Linux |
| Log ingestion | /var/log/auth.log continuously monitored as a data source |
| SPL queries | Three detection queries written from scratch |
| Alert creation | Scheduled detection rule - High severity |
| Dashboard build | 3-panel CyberJKD Security Monitor in Dashboard Studio |
| Real threat detection | 3 external IPs detected probing the VM within hours of deployment |

## Environment

| Component | Detail |
|-----------|--------|
| Cloud Platform | Microsoft Azure Free Account |
| VM Size | Standard D2s v3 (2 vCPUs, 8GB RAM) |
| OS | Ubuntu Server 24.04 LTS |
| SIEM | Splunk Enterprise 9.4.1 |
| Log Source | /var/log/auth.log (sourcetype `linux_auth`) |
| NSG Rules | Port 22 (SSH) · Port 8000 (Splunk Web) |
| Cost | $0 - covered by Azure free credits |

## Architecture

![Splunk Enterprise SIEM Lab architecture](screenshots/architecture-diagram.png)

```
Internet scanners ──► public IP 102.37.19.163 ──► "Connection reset … [preauth]" in auth.log
                                                   (blocked by NSG + SSH key auth)
   │
   ▼
Azure VM "Splunk-VM" (Ubuntu Server 24.04, D2s v3)
   ├── /var/log/auth.log  ── continuous monitor, sourcetype linux_auth ──►  Splunk Enterprise 9.4.1
   │                                                                          (index + search, Web UI :8000)
   │                                                                             │
   │                                                              ┌──────────────┼──────────────┐
   │                                                              ▼              ▼              ▼
   │                                                        SPL queries     hourly alert   3-panel
   │                                                        (sshd / susp /   "Brute Force   dashboard
   │                                                         rank src_ip)     SSH" (High)    (Security Monitor)
```

## Key Concepts

### What is a SIEM?
A Security Information and Event Management system collects logs from across an environment - servers, firewalls, applications - and centralises them for search, correlation, and alerting. Splunk is the industry standard. Being able to deploy it, ingest data, and write detection logic is a core SOC skill.

### What is SPL?
Splunk Processing Language - the query language used to search, filter, and transform log data inside Splunk. Similar in concept to SQL but purpose-built for security log analysis. Every SOC analyst writes SPL daily.

### What is auth.log?
The Linux authentication log. Every SSH connection attempt, login success, login failure, sudo command, and user creation gets recorded here. It is the primary source for detecting brute force attacks, unauthorised access, and privilege escalation on Linux systems.

### Why do external IPs appear immediately after deployment?
Internet-facing VMs are scanned continuously by automated bots within minutes of receiving a public IP. These are not targeted attacks - they are mass scanners probing every IP on the internet for open ports. This lab captured exactly that activity in real time.

---

## Lab Walkthrough

### Stage 1 - Deploy Azure VM

- Created Resource Group: CyberJKD-Lab (East US)
- Deployed Ubuntu Server 24.04 LTS VM: Splunk-VM
- Configured SSH key authentication - downloaded .pem private key
- Connected via PowerShell: `ssh -i Splunk-VM-001_key.pem splunkadmin@102.37.19.163`
- Ran system update: `sudo apt-get update && sudo apt-get upgrade -y`

![Azure VM Deployed and SSH Connected](screenshots/01-azure-vm-ssh-connected.webp)

### Stage 2 - Install Splunk Enterprise

```bash
# Download Splunk 9.4.1
wget -O splunk.deb "https://download.splunk.com/products/splunk/releases/9.4.1/linux/splunk-9.4.1-e3bdab203ac8-linux-amd64.deb"

# Install
sudo dpkg -i splunk.deb

# Start Splunk and accept license - create admin credentials on first run
sudo /opt/splunk/bin/splunk start --accept-license

# Configure Splunk to start automatically on VM boot
sudo /opt/splunk/bin/splunk enable boot-start
```

Added NSG inbound rule: Port 8000 TCP - Allow (Splunk Web UI). Accessed Splunk at `http://102.37.19.163:8000`.

![Splunk Enterprise Web UI - Hello Administrator](screenshots/02-splunk-web-ui.webp)

### Stage 3 - Ingest Auth Logs

- Add Data → Monitor → Files & Directories
- File path: `/var/log/auth.log`
- Monitoring type: Continuously Monitor
- Source type: `linux_auth` (custom, created during setup)
- Host: Splunk-VM · Index: default

Splunk immediately began indexing 63 events - including user creation, sudo commands, SSH sessions, and external connection attempts.

![Auth Log Ingestion - 63 Events Indexed](screenshots/03-auth-log-ingestion.webp)

### Stage 4 - SPL Detection Queries

**Query 1 - All SSH events:**
```spl
source="/var/log/auth.log" "sshd"
```
Returned 11 events - successful logins, session opens/closes, and external connection resets.

**Query 2 - Suspicious connection attempts:**
```spl
source="/var/log/auth.log" ("Failed" OR "Invalid" OR "Connection reset")
```
Returned 6 events. **4** were external-IP `Connection reset … [preauth]` events; the other 2 were Splunk's own `mongod` noise (see [Review Note 1](#review-notes-october-2026)).

**Query 3 - Top attacking IPs (threat intelligence):**
```spl
source="/var/log/auth.log" "Connection reset" | rex "by (?P<src_ip>\d+.\d+.\d+.\d+)" | stats count by src_ip | sort -count
```
Extracted and ranked all source IPs from connection reset events.

![SPL Queries - Suspicious Events and Top Attacking IPs](screenshots/04-spl-querie.webp)

### Stage 5 - Brute Force SSH Detection Alert

- Saved Query 2 as a scheduled alert
- Alert name: **Brute Force SSH Detection**
- Description: Detects repeated SSH connection resets indicating suspicious pre-auth activity
- Alert type: Scheduled - runs every hour
- Trigger condition: Number of Results is greater than 3
- Severity: **High** · Action: Add to Triggered Alerts

![Brute Force SSH Detection Alert - Configured](screenshots/05-brute-force-alert.webp)

### Stage 6 - CyberJKD Security Monitor Dashboard

Built in Dashboard Studio with 3 panels:

- **Panel 1 - Suspicious Connection Attempts:** live events table showing all failed/invalid/reset connection events with timestamps.
- **Panel 2 - SSH Attack Timeline:** timechart of connection reset events per hour - a spike is clearly visible around 11PM on deployment night.
- **Panel 3 - Top Attacking IPs:** bar chart ranking source IPs by number of connection attempts.

![CyberJKD Security Monitor Dashboard](screenshots/06-cyberjkd-security-monitor-dashboard.png.webp)

---

## Findings - Real Attack Activity Detected

Within hours of the VM being deployed with a public IP, Splunk detected `Connection reset … [preauth]` attempts from 3 external IPs:

| IP Address | Attempts | Classification |
|---|---|---|
| 197.210.71.163 | 2 | Automated scanner - pre-auth SSH probe |
| 197.210.71.158 | 1 | Automated scanner - pre-auth SSH probe |
| 205.210.31.140 | 1 | Automated scanner - pre-auth SSH probe |

4 reset events, 3 unique IPs - matching the dashboard's Top Attacking IPs bar chart. All blocked at the pre-authentication stage; NSG rules and SSH key auth prevented any access. Documented as expected internet background noise, not a targeted attack.

## SPL Reference - Queries Used in This Lab

| Query fragment | Purpose |
|-------|---------|
| `source="/var/log/auth.log" "sshd"` | All SSH-related events |
| `("Failed" OR "Invalid" OR "Connection reset")` | Suspicious auth events (broad - see Review Note 1) |
| `\| stats count by src_ip` | Count events grouped by source IP |
| `\| timechart count span=1h` | Plot event count over time |
| `\| rex "by (?P<src_ip>...)"` | Extract IP address from raw log text |
| `\| sort -count` | Sort results highest to lowest |

## Verification Checklist

- [x] Azure VM deployed and hardened with NSG rules
- [x] Splunk Enterprise 9.4.1 installed on Ubuntu via CLI
- [x] Auth log ingested as continuous-monitor data source
- [x] SPL queries written - SSH events, suspicious attempts, top IPs
- [x] Scheduled High-severity alert created (hourly)
- [x] CyberJKD Security Monitor dashboard built - 3 panels
- [x] Real external activity detected and documented (3 IPs, matches the dashboard)
- [x] Splunk configured for boot-start on VM restart
- [ ] The "suspicious" query returns only auth events: **no, 2 of 6 are Splunk noise - see Review Note 1**
- [ ] The alert detects a password brute force: **no, it detects pre-auth scans - see Review Note 2**

## Review Notes (October 2026)

I came back to this lab after later projects and re-read the screenshots against the claims. The deployment, detection and findings all hold up - the 3 scanner IPs and their counts match the dashboard exactly. Two notes sharpen the detection logic, which is the part a SOC interviewer will probe.

**1. The "suspicious events" query catches non-auth noise.** `("Failed" OR "Invalid" OR "Connection reset")` is a broad keyword match. In the Stage 4 screenshot it returns 6 events, but only **4** are real SSH resets - the other **2** are Splunk's own `mongod: … failed to open directory` messages, matched purely because they contain the word "Failed". On a busy host that broad query would surface a lot of irrelevant lines. A production detection scopes to the actual auth patterns: `"Failed password"`, `"Invalid user"`, or events tagged `[preauth]` - not the bare word "Failed".

**2. "Connection reset … [preauth]" is scanning, not brute force.** The alert is named *Brute Force SSH Detection*, but every event it fires on is a `Connection reset by <ip> … [preauth]` - a bot that opens a TCP connection to port 22 and drops it before authenticating. A real password **brute force** produces repeated `Failed password for <user>` lines (as in [Phase 01 · Project 05](../../phase-01/project-05-brute-force-simulation)). To the lab's credit, the Findings section already classifies these correctly as "automated scanner - pre-auth SSH probe"; it's only the alert's name that overstates it. Cleaner design: two rules - one for pre-auth scans (`Connection reset … [preauth]`), one for brute force (`Failed password` repetition per source IP).

**3. Minor.** The dashboard image is committed as `...-dashboard.png.webp` (double extension) - it renders fine, but a single `.webp` is tidier. The badge and roadmap call this "Lab 01" while the folder is `project-01`; both point to the same lab.

## What I'd Change for Production

| Lab setup | Production reality |
|-----------|-------------------|
| Single VM auth-log source | Production SIEMs ingest from hundreds of sources - firewalls, endpoints, cloud APIs |
| Broad keyword SPL | Scoped detections (`Failed password`, `Invalid user`), saved searches, correlation rules, playbooks (Review Notes 1, 2) |
| Free-trial Splunk license | Enterprise license with full scheduling and alerting |
| Public IP on VM | Private endpoints / bastion - no direct internet exposure |
| Manual alert review | Ticketing integration (ServiceNow) to auto-create incidents from Splunk alerts |

## Connection to Roadmap

This lab is **Phase 02 · Lab 01** of the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap). The SIEM foundation built here transfers directly to:

- **[Nessus Vulnerability Scanning](../project-02-nessus-vulnerability-scanning)** and **[ServiceNow Ticketing](../project-03-servicenow-vulnerabiity-ticketing)** - the detect → assess → ticket workflow
- **Phase 03** - Microsoft Sentinel + KQL (same SIEM concepts, Azure-native tool)
- **Phase 05** - automated incident detection and response with Sentinel + Logic Apps

The same auth.log attack patterns detected here are what [Phase 01 · Project 04 (Python Log Parser)](../../phase-01/project-04-python-log-parser) parsed by hand - this lab does it at SIEM scale.

---

🌐 Full roadmap: [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)

🔗 All labs: [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

---

*CyberJKD - Becoming dangerous through fundamentals. 🔒*
