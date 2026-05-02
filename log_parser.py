#!/usr/bin/env python3
# CyberJKD Log Parser
# Phase 01 - Project 04
# Parses auth.log and detects failed SSH login attempts

import re
from collections import defaultdict
from datetime import datetime

LOG_FILE = "auth.log"
THRESHOLD = 3

failed_attempts = defaultdict(list)
pattern = re.compile(r'Failed password for (?:invalid user )?(\w+) from ([\d.]+)')

with open(LOG_FILE, 'r') as f:
    for line in f:
        match = pattern.search(line)
        if match:
            failed_attempts[match.group(2)].append({'ts': 'N/A', 'user': match.group(1)})

print("=" * 60)
print("      CyberJKD SSH Log Analysis Report")
print("      Generated:", datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
print("=" * 60)
flagged = []
for ip, attempts in sorted(failed_attempts.items()):
    count = len(attempts)
    users = set(a['user'] for a in attempts)
    status = "[!] FLAGGED" if count > THRESHOLD else "[+] OK"
    print(status, "| IP:", ip, "| Attempts:", count, "| Users:", ','.join(users))
    if count > THRESHOLD:
        flagged.append(ip)
        for a in attempts:
            print("        [" + a['ts'] + "] User:", a['user'])
print("=" * 60)
print("[!] Flagged IPs:", len(flagged))
for ip in flagged:
    print("    ->", ip, "-- block with UFW")
print("=" * 60)
print("  ANALYSIS COMPLETE -- CyberJKD")
print("  Becoming dangerous through fundamentals.")
print("=" * 60)
