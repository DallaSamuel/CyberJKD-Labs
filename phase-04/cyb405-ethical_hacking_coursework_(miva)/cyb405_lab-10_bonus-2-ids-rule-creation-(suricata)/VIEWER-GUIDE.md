# Viewer Step-by-Step Guide - Bonus 2: Suricata IDS Rule

> A follow-along walkthrough of writing and validating a Suricata rule that detects a malware C2 beacon, including how to generate your own test traffic. All in an isolated Kali lab with a benign stand-in, no live malware.

---

## 0. The idea

You can't test a detection rule without something to detect. So the flow is: generate recognizable "malware" traffic, capture it, write a rule for its indicators, then run Suricata over the capture and confirm the alert fires.

Our pattern is an HTTP C2 beacon with two indicators:
- a `/gate.php` check-in URI
- a hardcoded `EvilRAT` User-Agent

---

## 1. Install Suricata

Kali 2026.1 doesn't ship it, and if your VM is air-gapped you'll need the temporary NAT adapter first (same as apktool/jadx).

```bash
sudo apt update && sudo apt install -y suricata
suricata --build-info | head -3     # confirm it installed
```

---

## 2. Generate the test traffic

The benign `malware_sample.py` fires one HTTP GET carrying the IOCs. `gen_capture.sh` wraps the whole capture:

```bash
cd ~/bonus2
./gen_capture.sh
```

It starts a local listener on `127.0.0.1:8000`, captures loopback traffic with tcpdump, fires the beacon, and writes `malware_capture.pcap`.

> **Expected gotcha:** the beacon prints `HTTP Error 404`. That's fine, the local listener just has no `/gate.php` file. The **request** (with the IOCs) still went out and is in the capture, which is all the rule needs.

---

## 3. Write the rule

Two rules in `local.rules`, a precise one and a broad backstop:

```
# precise - all three must match
alert http any any -> any any (msg:"CYB405 Malware C2 Beacon - EvilRAT gate.php check-in";
  flow:to_server,established; http.method; content:"GET";
  http.uri; content:"/gate.php"; nocase; http.user_agent; content:"EvilRAT"; nocase;
  classtype:trojan-activity; sid:1000001; rev:1;)

# broad - the User-Agent alone
alert http any any -> any any (msg:"CYB405 Suspicious User-Agent - EvilRAT";
  flow:to_server,established; http.user_agent; content:"EvilRAT"; nocase;
  classtype:trojan-activity; sid:1000002; rev:1;)
```

The parts that matter:
- `http.uri` and `http.user_agent` are **sticky buffers**, they match parsed HTTP fields, so the rule works regardless of port and doesn't false-match on raw bytes.
- `flow:to_server,established` keeps it to real client-to-server requests.
- `sid` must be unique (local rules use the 1000000+ range).

---

## 4. Test and validate

Run Suricata over the captured pcap, loading only your rules:

```bash
mkdir -p ~/bonus2/logs
sudo suricata -r malware_capture.pcap -S local.rules -l logs -k none
cat logs/fast.log
```

`-r` reads the pcap offline, `-S` loads only your rules, `-k none` skips checksum checks (loopback captures have bogus checksums, so without this Suricata would drop the packets).

You should see both rules alert:

```
[1:1000001:1] CYB405 Malware C2 Beacon - EvilRAT gate.php check-in  [A Network Trojan was detected] [Priority: 1]
[1:1000002:1] CYB405 Suspicious User-Agent - EvilRAT                [A Network Trojan was detected] [Priority: 1]
```

Screenshot `fast.log`, that's your validation evidence.

---

## 5. What it all means

| Step | Why it matters |
|---|---|
| Picked concrete IOCs (`/gate.php`, `EvilRAT`) | Detection starts from an observed indicator, not a guess |
| Used sticky buffers | Precise, protocol-aware matching instead of brittle byte matching |
| Wrote precise + broad rules | Balance false positives against coverage |
| Ran it against real traffic | A rule isn't done until it's proven to fire |

This is the core SOC loop: take an indicator, turn it into a signature, and validate it against traffic before it ever goes to production.

---

*No live malware was used; a benign stand-in generated the test traffic inside an isolated lab.*

**CyberJKD - Becoming dangerous through fundamentals.**
