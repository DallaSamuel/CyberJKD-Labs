#!/usr/bin/env python3
import base64
from challenge import PAYLOAD

# Phase 1 - strip the keyless layers (no secret needed)
rev  = base64.b64decode(PAYLOAD).decode()
hexs = rev[::-1]
ct   = bytes.fromhex(hexs)
print("[P1] XOR ciphertext (hex):", ct.hex())

# Phase 2 - known-plaintext key recovery
KNOWN = b"CYB405{"                        # every flag starts this way
stream = bytes([ct[i] ^ KNOWN[i] for i in range(len(KNOWN))])
print("[P2] key stream from prefix:", stream.decode(errors="replace"))

def period(s):
    for p in range(1, len(s)):
        if all(s[i] == s[i % p] for i in range(len(s))):
            return p
    return len(s)

klen = period(stream)
KEY  = stream[:klen].decode()
print("[P2] detected key length :", klen, "->  KEY =", repr(KEY))

# Phase 3 - decrypt everything with the recovered key
flag = bytes([b ^ ord(KEY[i % len(KEY)]) for i, b in enumerate(ct)]).decode()
print("[P3] recovered FLAG      :", flag)
