# CyberJKD Labs

![Focus](https://img.shields.io/badge/Focus-Cloud%20Security%20%7C%20SOC%20Analyst-183A61?style=flat-square)
![Documented Labs](https://img.shields.io/badge/Documented%20Labs-20-0078D4?style=flat-square)
![Progress](https://img.shields.io/badge/19%20Complete%20·%201%20In%20Progress-brightgreen?style=flat-square)
![Roadmap](https://img.shields.io/badge/Part%20of-CyberJKD%20Roadmap-ff8800?style=flat-square)

> *Becoming dangerous through fundamentals* 🔒

A hands-on cybersecurity lab portfolio - defensive, offensive, and cloud - each project documented end to end as evidence of applied skill, not just completion.

**Author:** Dalla Samuel (CyberJKD)

**Goal:** Building toward a first **Cloud Security Engineer / SOC Analyst** role, through documented labs and a public portfolio.

**Roadmap:** [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - the phase structure, certification path (AZ-900 → AZ-104 → AZ-500 → SC-200), and project rationale live here.

---

## About this repo

Every folder is a complete lab write-up in one consistent format, so each project reads like a real engagement deliverable rather than a notebook dump. A typical lab README contains:

- **Objective · Business Problem · Environment** - what was built and why it matters, mapped to real roles
- **Architecture** - a diagram and an ASCII topology of the lab
- **Step-by-step evidence** - commands, screenshots, and verified output for each exercise
- **Troubleshooting Log** - real errors and fixes, documented rather than edited out
- **Verification checklist · Review Notes · "What I'd Change for Production"** - honest self-review and a production lens

Lab environments are built locally in VirtualBox and on Microsoft Azure.

---

## Skills &amp; tools demonstrated

| Area | Tools &amp; techniques |
|------|----------------------|
| **Offensive / Pentest** | nmap · Metasploit · Nikto · enum4linux · smbclient · Hydra · searchsploit · Ghidra · Sherlock |
| **Blue Team / Detection** | Splunk (SPL) · Nessus · ServiceNow ITSM · Suricata · Wireshark · Python log parsing |
| **Cloud / IaC** | Microsoft Azure · Terraform · Active Directory · Azure Key Vault · Group Policy |
| **Systems / Network** | Kali Linux · Ubuntu &amp; Windows Server · pfSense · VirtualBox Host-Only networking · UFW · Linux hardening |

---

## Labs by phase

### Phase 01 - Security Fundamentals
Host hardening, network segmentation, packet analysis, detection scripting, and OSINT.

| Lab | Focus | Status |
|-----|-------|--------|
| [Linux Hardening](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-01-linux-hardening) | Step-by-step hardening of an Ubuntu Server 24.04 VM, each control verified with before/after evidence | ✅ |
| [Network Segmentation](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-02-network-segmentation) | pfSense LAN / DMZ isolation; firewall rules proven to stop lateral movement | ✅ |
| [Wireshark Packet Analysis](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-03-wireshark-packet-analysis) | Capturing and dissecting live ICMP, SSH, and ARP traffic on a LAN | ✅ |
| [Python Log Parser](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-04-python-log-parser) | A script that parses `auth.log`, detects SSH brute force, and flags offending source IPs | ✅ |
| [Brute Force Simulation + Log Analysis](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-05-brute-force-simulation) | Full attack-and-defence cycle: Hydra attack → `auth.log` detection → UFW block | ✅ |
| [B819 Router Firmware Research](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-06-router-firmware-research) | Reverse-engineering a white-label 4G/5G router's firmware | ⏳ In progress |
| [Sherlock OSINT](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-01/project-07-sherlock-osint) | Username self-audit across 400+ sites, with manual true/false-positive verification | ✅ |

### Phase 02 - Blue Team: SIEM, Vulnerability Management &amp; Ticketing
Detection engineering and the vulnerability-to-remediation workflow on cloud VMs.

| Lab | Focus | Status |
|-----|-------|--------|
| [Splunk Enterprise SIEM](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-02/project-01-splunk-siem-lab) | Splunk on Azure: ingest Linux auth logs, write SPL detections, build an alert and a monitoring dashboard | ✅ |
| [Nessus Vulnerability Scanning](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-02/project-02-nessus-vulnerability-scanning) | Unauthenticated vs credentialed scans on Azure - real CVEs, CVSS interpretation, remediation plan | ✅ |
| [ServiceNow Vulnerability Ticketing](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-02/project-03-servicenow-vulnerabiity-ticketing) | Triaging and tracking 6 Nessus findings as incidents with a CVSS-to-priority mapping | ✅ |

### Phase 03 - Azure: Active Directory &amp; Network Analysis
Enterprise identity and traffic analysis on Microsoft Azure.

| Lab | Focus | Status |
|-----|-------|--------|
| [Active Directory on Azure](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-03/project-02-active-directory) | Building AD from scratch: DC promotion, OUs, users/groups, and Group Policy | ✅ |
| [Wireshark &amp; Network Analysis](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-03/project-03-wireshark-network-analysis) | DNS queries, TCP handshakes, cleartext HTTP credentials, and TCP-stream reconstruction | ✅ |

### Phase 04 - Offensive Security · CYB 405 Ethical Hacking (Miva Open University)
Graded mid-semester coursework, documented to portfolio standard. All work confined to an isolated, air-gapped Host-Only lab.

| Lab | Focus | Status |
|-----|-------|--------|
| [Lab 01 · Virtual Lab Setup &amp; Configuration](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-04/cyb405-ethical_hacking_coursework_(miva)/cyb405_lab-01_virtual-lab-setup-%26-configuration) | An isolated 3-VM Host-Only pentest range (Kali · Metasploitable2 · Windows Server) | ✅ |
| [Lab 02 · Footprinting &amp; Reconnaissance](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-04/cyb405-ethical_hacking_coursework_(miva)/cyb405_lab-02_footprinting-%26-reconnaissance) | WHOIS/DNS (air-gap limits), a Shodan-substitute banner grab, full nmap, and Nikto | ✅ |
| [Lab 03 · Network Scanning &amp; Enumeration](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-04/cyb405-ethical_hacking_coursework_(miva)/cyb405_lab-03_network-scanning-%26-enumeration) | Subnet sweep + SMB/RPC enumeration cross-verified across three tools + a vuln scan | ✅ |
| [Lab 04 · System Hacking &amp; Privilege Escalation](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-04/cyb405-ethical_hacking_coursework_(miva)/cyb405_lab-04_system-hacking%20-%26-privilege-escalation) | Exploiting the vsftpd 2.3.4 backdoor to root, an anti-forensics discovery, and a remediation plan | ✅ |
| [Lab 05 · Malware Analysis &amp; Reverse Engineering](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-04/cyb405-ethical_hacking_coursework_(miva)/cyb405_lab-05_malware-analysis-%26-reverse-engineering) | Static/dynamic analysis of a benign self-authored sample in Ghidra → IOCs + a Suricata rule | ✅ |

### Phase 06 - Cloud Systems Administration (Terraform &amp; Azure IaC)
Infrastructure-as-code deployment and hardening on Azure.

| Lab | Focus | Status |
|-----|-------|--------|
| [Terraform AD DC Deployment](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/lab-01_terraform-ad-dc) | One `terraform apply` deploys a Windows Server VM and promotes it to an AD Domain Controller | ✅ |
| [VS Code Remote-SSH Setup](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/lab-02_vscode-remote-ssh-setup) | VS Code + Git + a working Remote-SSH connection into the Kali lab VM | ✅ |
| [NTFS File Server (Hardened, on Azure)](https://github.com/DallaSamuel/CyberJKD-Labs/tree/main/phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/lab-03_ntfs-file-server) | A three-tier Windows file server via Terraform, with per-user Key Vault secrets and NTFS hardening | ✅ |

---

**20 documented labs · 19 complete.** Phase/numbering and what's next are tracked on the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap).

---
> "Becoming dangerous through fundamentals 🔒." — CyberJKD
