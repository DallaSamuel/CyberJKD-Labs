# CYB 405 - Bonus 2: IDS Rule Creation (Suricata)

![Course](https://img.shields.io/badge/CYB%20405-Bonus%202-0B1F3A?style=flat-square)
![Tool](https://img.shields.io/badge/IDS-Suricata%208.0.8-1F8A8C?style=flat-square)
![Focus](https://img.shields.io/badge/Focus-Detection%20Engineering-c9252d?style=flat-square)
![Weight](https://img.shields.io/badge/Weight-4%25-2DD4BF?style=flat-square)
![Status](https://img.shields.io/badge/Status-Validated-3fb950?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel |
| **Challenge** | Bonus 2 - write a Suricata rule to detect a malware pattern, test and validate |
| **Environment** | Kali Linux 2026.1, isolated Host-Only lab |
| **Roadmap** | [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - Phase 04 |

## Task

Write a Suricata rule to detect a sample malware network pattern, then test and validate it fires. The chosen pattern is an HTTP command-and-control (C2) beacon: a `/gate.php` check-in carrying a hardcoded `EvilRAT` User-Agent.

## The sample and its IOCs

A benign Python stand-in (`malware_sample.py`) sends one harmless HTTP GET carrying the indicators a real beacon would expose:

- **URI:** `/gate.php?bot=victim01&cmd=checkin` - a classic C2 gate check-in
- **User-Agent:** `EvilRAT/1.0 (c2 beacon)` - a hardcoded, non-browser agent

## Detection pipeline

![Pipeline](img/architecture.png)

```
malware_sample.py --beacon--> local C2 :8000 --tcpdump--> malware_capture.pcap --suricata -r--> fast.log ALERT
```

## The rule

```
# precise - method + URI + User-Agent (low false positives)
alert http any any -> any any (msg:"CYB405 Malware C2 Beacon - EvilRAT gate.php check-in"; \
  flow:to_server,established; http.method; content:"GET"; http.uri; content:"/gate.php"; nocase; \
  http.user_agent; content:"EvilRAT"; nocase; classtype:trojan-activity; sid:1000001; rev:1;)

# broad - User-Agent only (safety net)
alert http any any -> any any (msg:"CYB405 Suspicious User-Agent - EvilRAT"; \
  flow:to_server,established; http.user_agent; content:"EvilRAT"; nocase; \
  classtype:trojan-activity; sid:1000002; rev:1;)
```

**How it works:** sticky buffers (`http.uri`, `http.user_agent`) match parsed HTTP fields, so detection is precise and port-agnostic; `flow:to_server,established` limits to client-to-server traffic; `classtype`/`sid` set the alert class and unique IDs.

## Test and validation

```bash
# 1. generate + capture the beacon
./gen_capture.sh                 # writes malware_capture.pcap

# 2. run the rule against the capture
sudo suricata -r malware_capture.pcap -S local.rules -l logs -k none

# 3. confirm the alerts
cat logs/fast.log
```

### Result (both rules fired)

```
[1:1000001:1] CYB405 Malware C2 Beacon - EvilRAT gate.php check-in  [Classification: A Network Trojan was detected] [Priority: 1]
[1:1000002:1] CYB405 Suspicious User-Agent - EvilRAT                [Classification: A Network Trojan was detected] [Priority: 1]
```

## Tuning note

The broad User-Agent-only rule is the higher false-positive risk and would be scoped or lowered in production; the precise rule (gate path + agent together) is safe at Priority 1. Keeping both, with the broad one as a lower-confidence backstop, is a common detection-engineering pattern.

## Files

| File | Purpose |
|---|---|
| `malware_sample.py` | benign C2-beacon stand-in (generates the IOCs) |
| `gen_capture.sh` | one-shot traffic generator + capture |
| `local.rules` | the two Suricata rules |
| `outputs/fast.log` | the validated alert output |
| `CYB405_Bonus2_IDS_Report.pdf/.docx` | full writeup |
| `VIEWER-GUIDE.md` / `social-posts.md` | walkthrough + social |

---

*No live malware was used; a benign stand-in generated the test traffic inside an isolated lab.*

**CyberJKD - Becoming dangerous through fundamentals.**
