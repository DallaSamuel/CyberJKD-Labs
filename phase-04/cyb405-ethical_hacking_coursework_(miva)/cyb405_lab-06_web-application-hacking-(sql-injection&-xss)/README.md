# CYB 405 - Lab 6: Web Application Hacking (SQL Injection & XSS)

![Platform](https://img.shields.io/badge/Platform-OWASP%20Juice%20Shop-f0a73d?style=flat-square)
![Attacker](https://img.shields.io/badge/Attacker-Kali%20Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white)
![Tools](https://img.shields.io/badge/Tools-Burp%20Suite%20%7C%20gobuster-e34f26?style=flat-square)
![Category](https://img.shields.io/badge/OWASP-A03%20Injection-c9252d?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-3fb950?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel |
| **Date** | November 2026 |
| **Platform** | OWASP Juice Shop (Docker) on an air-gapped VirtualBox lab |
| **Lab Source** | CYB 405 - Introduction to Ethical Hacking (Miva Open University) |
| **Roadmap** | [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - Web Application Security |

---

## Objective

Perform secure, controlled testing of the OWASP Juice Shop web application for **SQL injection** and **cross-site scripting (XSS)** vulnerabilities: map the application's endpoints with Burp Suite, exploit SQL injection to extract sample data, execute an XSS payload, and recommend remediations.

## Business Problem

Modern web applications expose REST APIs and user-input fields directly to the internet. A single unsanitised input can let an attacker bypass authentication, read an entire user database, or run code in another user's browser. This lab demonstrates - on an intentionally-vulnerable target - how those flaws are found and exploited, and how to fix them, so the same classes of bug can be recognised and prevented in real systems.

## Environment

| Component | Detail |
|---|---|
| Host | Windows 11, 31 GB RAM, Oracle VirtualBox |
| Attacker | Kali Linux 2026.1 - `192.168.56.102` |
| Target | Ubuntu Server 24.04.4 LTS - `192.168.56.104` |
| Target App | OWASP Juice Shop via Docker 29.1.3 (`bkimminich/juice-shop`) |
| Network | VirtualBox Host-Only `192.168.56.0/24`, DHCP disabled, static IPs, **air-gapped** |
| Tools | gobuster 3.8.2, Burp Suite Community 2026.7.2, curl, Firefox/Chromium |

## Architecture

![Attack Topology](img/architecture.png)

```
Physical Host (Windows 11, VirtualBox)
└── Host-Only Network 192.168.56.0/24  [AIR-GAPPED]
    ├── Kali Linux (Attacker)      192.168.56.102
    │     gobuster · Burp Suite · curl
    │        │
    │        └── Burp Proxy 127.0.0.1:8080
    │               │  SQLi / XSS payloads
    │               ▼
    └── Ubuntu Server (Target)     192.168.56.104
          └── Docker ──> OWASP Juice Shop  :3000
```

## Key Concepts

- **SQL Injection (SQLi)** - untrusted input concatenated into a SQL query, allowing an attacker to alter the query's logic (authentication bypass) or append a `UNION SELECT` to read other tables (data exfiltration).
- **UNION column matching** - a `UNION`-based injection must return the same number of columns as the original query; an `ORDER BY n` probe reveals that count.
- **DOM-based XSS** - user input reflected into the page DOM without encoding, so the browser executes it as live code.
- **Broken Access Control** - resources served without an authorisation check (here, an open `/ftp` directory listing).

## Walkthrough Summary

| # | Phase | Result |
|---|---|---|
| A | Infrastructure build | Juice Shop container on static `.104`, air-gapped, `clean-base` snapshot |
| B | Endpoint enumeration | gobuster + Burp site-map; found `/ftp`, `/rest/products/search`, `/rest/user/login` |
| C | Sensitive data exposure | `/ftp` lists confidential files + a KeePass vault, no auth |
| D | SQLi - auth bypass | Logged in as `admin@juice-sh.op` with `' or 1=1-- ` |
| E | SQLi - data exfiltration | UNION injection dumped **24 user credentials** (emails + MD5 hashes) |
| F | DOM XSS | `<iframe src="javascript:alert('xss')">` executed in the app context |

> Full step-by-step discovery walkthrough: see **[VIEWER-GUIDE.md](VIEWER-GUIDE.md)**.

## Command / Payload Reference

```bash
# Target reachability (from Kali)
ping -c 3 192.168.56.104
curl -I http://192.168.56.104:3000

# Directory enumeration (SPA needs wildcard-length filter)
gobuster dir -u http://192.168.56.104:3000 \
  -w /usr/share/wordlists/dirb/common.txt \
  -t 5 --delay 20ms --exclude-length 9984 -o gobuster.txt
```

```sql
-- D. SQLi authentication bypass (email field; any password)
' or 1=1-- 

-- E. Column-count probe (via /rest/products/search?q=)
qwert')) ORDER BY 50--        -- returns: should be between 1 and 10

-- E. UNION data exfiltration (10 columns to match Products table)
qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9','10' FROM Users-- 
```

```html
<!-- F. DOM XSS (search field) -->
<iframe src="javascript:alert('xss')">
```

## Findings

| # | Finding | OWASP | Severity |
|---|---|---|---|
| 1 | SQLi - authentication bypass (login) | A03 Injection | Critical |
| 2 | SQLi - UNION data exfiltration (24 credentials) | A03 Injection | Critical |
| 3 | Sensitive data exposure - unauthenticated `/ftp` | A01 Broken Access Control | High |
| 4 | DOM-based XSS (search field) | A03 Injection (XSS) | High |
| 5 | Weak password storage - unsalted MD5 | A02 Cryptographic Failures | High |
| 6 | Verbose errors leaking backend SQL | A05 Security Misconfiguration | Medium |

## Remediation

| Finding | Fix |
|---|---|
| SQL injection | Parameterised queries / prepared statements everywhere; never concatenate input into SQL; ORM-safe builders; server-side validation. |
| `/ftp` exposure | Remove directory listing; require auth; serve an allow-list of file types from a non-web-root path; purge `.bak`/confidential files. |
| DOM XSS | Context-aware output encoding; framework-safe bindings (no `innerHTML`); strict Content-Security-Policy blocking inline script and `javascript:` URIs. |
| Weak hashing | Replace MD5 with salted bcrypt/scrypt/Argon2; force reset after migration. |
| Verbose errors | Generic client errors; detailed logs server-side only. |

## Verification Checklist

- [x] Target reachable from attacker (`200 OK` on `:3000`)
- [x] Endpoints enumerated (gobuster + Burp site-map)
- [x] `/ftp` sensitive data exposure confirmed
- [x] SQLi authentication bypass (admin login) confirmed
- [x] SQLi UNION dump - 24 credentials extracted
- [x] DOM XSS payload executed
- [x] Remediations documented for every finding

## What I'd Change for Production

- Enforce parameterised queries across the data layer; add a WAF as a secondary control.
- Deploy a strict Content-Security-Policy and modern anti-XSS framework defaults.
- Migrate password storage to Argon2id with per-user salts and a pepper.
- Remove backup/confidential artefacts from web-served paths; enforce authenticated, allow-listed file access.
- Replace verbose error handling with generic client responses and centralised logging.
- Add rate limiting so a single client cannot exhaust the service.

## Connection to Roadmap

This lab reinforces the **Web Application Security** competency on the CyberJKD roadmap - injection testing, proxy-based application mapping, and vulnerability remediation - core skills for the Cloud Security Engineer / SOC Analyst track.

---

*All testing was performed against a self-built, air-gapped OWASP Juice Shop instance published by OWASP for training. No production system or real data was involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
