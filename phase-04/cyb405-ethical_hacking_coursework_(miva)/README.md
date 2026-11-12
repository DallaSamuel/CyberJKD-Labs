# CYB 405 - Lab 8: Evasion, IDS/Firewall Bypass & DoS Simulation

![Platform](https://img.shields.io/badge/Target-Metasploitable2-f0a73d?style=flat-square)
![Attacker](https://img.shields.io/badge/Attacker-Kali%20Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white)
![Tools](https://img.shields.io/badge/Tools-nmap%20%7C%20scapy%20%7C%20Wireshark-e34f26?style=flat-square&logo=wireshark&logoColor=white)
![Category](https://img.shields.io/badge/Focus-Evasion%20%7C%20DoS-c9252d?style=flat-square)
![Weight](https://img.shields.io/badge/Weight-15%25-6f42c1?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-3fb950?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel |
| **Date** | November 2026 |
| **Platform** | Kali -> Metasploitable2 on an air-gapped VirtualBox lab |
| **Lab Source** | CYB 405 - Introduction to Ethical Hacking (Miva Open University) |
| **Roadmap** | [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - Phase 04 |

---

## Objective

Simulate IDS/firewall evasion, detect a honeypot, and run a safe, low-impact DoS experiment, all inside an isolated lab. Specifically: apply packet fragmentation, timing and decoy evasion; stand up and detect a honeypot and document its signatures; and simulate a connection-exhaustion DoS, measuring the target's response and recovery.

## Business Problem

Defences are only as good as what they can see. Attackers routinely fragment, slow down, and disguise their traffic to slip past signature and rate-based detection; honeypots are deployed to catch them; and a single host can be knocked offline by a handful of slow connections. Understanding all three, from the attacker's side, is what lets a defender tune detections that fire on the real thing and harden a service against cheap denial-of-service.

## Environment

| Component | Detail |
|---|---|
| Attacker | Kali Linux 2026.1 - `192.168.56.102` |
| Target | Metasploitable2 - `192.168.56.101` (Apache on `:80`) |
| Honeypot | Python multi-port listener (local listener on Kali, deployed for the exercise) |
| Network | VirtualBox Host-Only `192.168.56.0/24`, **air-gapped** |
| Tools | nmap 7.99, tcpdump, Wireshark, scapy, custom Python slowloris |
| Rollback | Metasploitable2 snapshot `lab-8` taken before the DoS task |

## Architecture

![Lab 8 Attack Flow](img/architecture.png)

```
Kali (192.168.56.102)  ──1. evasion scans (-f / --mtu / -T1 / -D / src-port)──►  Metasploitable2 (.101:80)
       │  tcpdump -> evasion_capture.pcap                                        │  Apache + services
       ├──2. nmap -sV ────────────────────────────────►  Honeypot (many ports, identical banners)
       └──3. slowloris (200 conns) ───────────────────►  .101:80  (measured before/during/after)
```

> **Scope note:** no live IDS or firewall was deployed in this run. Task 1 demonstrates the evasion techniques and proves fragmentation at the packet level; it does not measure bypass of an active detector. Confirming real IDS evasion would require running Suricata (optional) or a firewall, noted as future work.

## Key Concepts

- **Packet fragmentation** - splitting a probe across tiny IP fragments so a signature engine cannot match it in one piece.
- **Timing evasion** - scanning slowly (`-T1`, `--scan-delay`) to stay under rate-based thresholds.
- **Decoy / source-port spoofing** - hiding the real source IP, or posing as trusted traffic (source port 53).
- **Honeypot** - a decoy host that looks vulnerable; the tell is that it behaves unlike real services.
- **Slowloris DoS** - holding many half-open connections so a server exhausts its worker pool.

## Walkthrough Summary

| # | Task | Result |
|---|---|---|
| 1 | Evasion / bypass | 5 scan variants (fragmentation x2, timing, decoy, source-port); 15 fragmented packets confirmed in Wireshark |
| 2 | Honeypot detection | 12 ports, all returning an identical banner; nmap flagged "9 services unrecognized despite returning data" |
| 3 | Low-impact DoS | Apache: 200 OK @ 1.66s -> no response (HTTP 000) -> recovered to 200 OK @ 0.26s |

> Full step-by-step discovery walkthrough: see **[VIEWER-GUIDE.md](VIEWER-GUIDE.md)**.

## Command Reference

```bash
# capture (evidence)
sudo tcpdump -i eth0 host 192.168.56.101 -w evasion_capture.pcap

# Task 1 - evasion
sudo nmap -sS -f -p 21,22,80,139,445 192.168.56.101 -oN frag8_scan.txt
sudo nmap -sS --mtu 24 -p 21,22,80,139,445 192.168.56.101 -oN frag_mtu24_scan.txt
sudo nmap -sS -T1 --scan-delay 1s -p 21,22,80 192.168.56.101 -oN timing_scan.txt
sudo nmap -sS -D RND:5 -p 80,445 192.168.56.101 -oN decoy_scan.txt
sudo nmap -sS --source-port 53 -p 80 192.168.56.101 -oN srcport_scan.txt
# Wireshark filter for the fragments:
#   ip.flags.mf == 1 || ip.frag_offset > 0

# Task 2 - honeypot detection
sudo nmap -sT -sV -p 21,23,25,110,143,445,1433,3306,3389,5900,8080,9200 192.168.56.102 -oN honeypot_scan.txt

# Task 3 - low-impact DoS (own VM, snapshot first)
python3 slowloris.py
curl -m 5 -s -o /dev/null -w 'HTTP %{http_code}  time %{time_total}s\n' http://192.168.56.101/
```

## Results

| # | Task | Technique | Outcome | Evidence |
|---|---|---|---|---|
| 1 | Evasion | Fragmentation (`-f`, `--mtu 24`) | Ports found; probes fragmented on the wire | `frag*_scan.txt`, pcap, Wireshark |
| 2 | Evasion | Timing / decoy / source-port | Scans succeeded with altered signature | `timing/decoy/srcport_scan.txt` |
| 3 | Honeypot | `nmap -sV` fingerprint | Detected: uniform banners, no real services | `honeypot_scan.txt` |
| 4 | DoS | Slowloris (200 conns) | Service down (HTTP 000), recovered after stop | curl before/during/after |

## Defensive Countermeasures

| Technique | Detection / mitigation |
|---|---|
| Fragmented scans | IP defragmentation / stream reassembly at the IDS (Suricata, Snort) before matching |
| Slow timing scans | Low-and-slow / long-window correlation, not just per-second rate rules |
| Decoy / source-port spoofing | Egress filtering, stateful inspection; don't trust source port 53 alone |
| Honeypot | Fingerprint uniformity flags it; defenders use honeypots as sensors |
| Slowloris DoS | Apache `mod_reqtimeout` + `mod_qos`, per-IP connection limits, buffering reverse proxy |

## Verification Checklist

- [x] Evasion capture started before scanning
- [x] Fragmentation, timing, decoy, source-port scans completed
- [x] Fragmented packets confirmed in Wireshark (15 packets, 8-byte fragments)
- [x] Honeypot deployed and detected; signatures documented
- [x] Snapshot taken before DoS
- [x] DoS measured before / during / after
- [x] Service recovery verified

## Troubleshooting Log

| Issue | Cause | Fix |
|---|---|---|
| `--mtu 24 -p 1-200` hung | Fragmented scan of a large port range is slow | Narrowed to 5 key ports (under 3s); fragmentation evidence unaffected |
| `slowloris` / `slowhttptest` not found | Neither installed, Kali air-gapped | Wrote a pure-Python slowloris, no install needed |

## What I'd Change for Production

- Deploy Suricata with stream reassembly and tune low-and-slow scan detection.
- Front Apache with a reverse proxy; enable `mod_reqtimeout` and per-IP connection limits against slowloris.
- Use honeypots intentionally as early-warning sensors and alert on the scan patterns seen here.

## Connection to Roadmap

This lab builds the **defensive-evasion and resilience** competency on the CyberJKD roadmap: recognising fragmented/slow/decoyed scans in a capture, spotting a honeypot, and understanding connection-exhaustion DoS, core situational skills for the SOC Analyst / Cloud Security Engineer track.

---

*All testing was performed inside a self-built, air-gapped lab against the author's own VMs. No production system or real data was involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
