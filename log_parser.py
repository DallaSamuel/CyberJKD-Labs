#!/usr/bin/env python3
# CyberJKD Log Parser
# Phase 01 · Project 04
# Parses auth.log and detects failed SSH login attempts

import re
from collections import defaultdict
from datetime import datetime

LOG_FILE = "auth.log"
THRESHOLD = 3

def parse_log(filepath):
    failed_attempts = defaultdict(list)
    pattern = re.compile(
        r'(\w+\s+\d+\s+\d+:\d+:\d+).*Failed password for (?:invalid user )?(\w+) from ([\d.]+)'
    )
    try:
        with open(filepath, 'r') as f:
            for line in f:
                match = pattern.search(line)
                if match:
                    timestamp = match.group(1)
                    username = match.group(2)
                    ip = match.group(3)
                    failed_attempts[ip].append({
                        'timestamp': timestamp,
                        'username': username
                    })
    except FileNotFoundError:
        print(f"[ERROR] Log file not found: {filepath}")
        return {}
    return failed_attempts

def generate_report(failed_attempts):
    print("=" * 60)
    print("       CyberJKD SSH Log Analysis Report")
    print(f"       Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    if not failed_attempts:
        print("\n[+] No failed login attempts found.")
        return
    print(f"\n[*] Total IPs with failed attempts: {len(failed_attempts)}\n")
    flagged = []
    for ip, attempts in sorted(failed_attempts.items()):
        count = len(attempts)
        usernames = set(a['username'] for a in attempts)
        status = "[!] FLAGGED" if count > THRESHOLD else "[+] OK"
        print(f"{status} | IP: {ip} | Attempts: {count} | Users tried: {','.join(usernames)}")
        if count > THRESHOLD:
            flagged.append(ip)
            for a in attempts:
                print(f"         [{a['timestamp']}] User: {a['username']}")
    print("\n" + "=" * 60)
    print(f"[!] Flagged IPs (>{THRESHOLD} attempts): {len(flagged)}")
    for ip in flagged:
        print(f"    -> {ip} -- recommended action: block with UFW")
    print("=" * 60)
    print("\n  ANALYSIS COMPLETE -- CyberJKD")
    print("  Becoming dangerous through fundamentals.")
    print("=" * 60)

if __name__ == "__main__":
    results = parse_log(LOG_FILE)
    generate_report(results)
