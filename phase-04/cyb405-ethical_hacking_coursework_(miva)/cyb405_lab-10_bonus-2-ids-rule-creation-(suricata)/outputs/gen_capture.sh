#!/bin/bash
# Generates the malware-beacon traffic and captures it to a pcap.
cd ~/bonus2
echo "[*] starting local C2 listener on 127.0.0.1:8000"
python3 -m http.server 8000 >/dev/null 2>&1 &
HTTP=$!
sleep 1
echo "[*] starting capture on loopback (needs sudo)"
sudo tcpdump -i lo -w malware_capture.pcap 'tcp port 8000' >/dev/null 2>&1 &
sleep 2
echo "[*] firing the C2 beacon"
python3 malware_sample.py
sleep 2
echo "[*] stopping capture + listener"
sudo pkill -f "tcpdump -i lo"
kill $HTTP 2>/dev/null
sleep 1
echo "[*] done:"
ls -la malware_capture.pcap
