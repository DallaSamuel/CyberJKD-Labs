# CYB 405 - Bonus 1: Capture-The-Flag Mini-Challenge

![Course](https://img.shields.io/badge/CYB%20405-Bonus%201-0B1F3A?style=flat-square)
![Type](https://img.shields.io/badge/Type-CTF%20%7C%20Cryptanalysis-1F8A8C?style=flat-square)
![Weight](https://img.shields.io/badge/Weight-3%25-2DD4BF?style=flat-square)
![Status](https://img.shields.io/badge/Status-Solved-3fb950?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel |
| **Challenge** | Bonus 1 - decrypt an encoded Python script to recover a flag |
| **Environment** | Kali Linux 2026.1, isolated Host-Only lab |
| **Roadmap** | [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - Phase 04 |

## Task

Recover the flag hidden inside `challenge.py` and document every step. The flag was XOR-encrypted with a **short secret key**, then hex-encoded, reversed, and base64-encoded. The XOR key is **not** in the file, so it must be recovered.

## Encoding chain and attack

![Decode chain](img/decode_chain.png)

```
ENCODE:  FLAG --XOR(secret key)--> hex --> reverse --> base64 = PAYLOAD   (key NOT shipped)
DECODE:  Phase 1  base64 decode -> reverse -> hex decode  -> XOR ciphertext   (no secret)
         Phase 2  XOR known prefix "CYB405{" vs ciphertext -> key stream -> recover key
         Phase 3  full ciphertext XOR recovered key        -> FLAG
```

## Solve

```bash
python3 solve.py      # peels the keyless layers, recovers the key, decrypts the flag
```

### How the key falls out (known-plaintext attack)

Every flag starts with `CYB405{`. XOR that known prefix against the first 7 ciphertext bytes and the key stream appears: `m1v4m1v`. It repeats every 4 characters, so the key is `m1v4`, recovered without brute force and without ever reading it from the file.

## Flag

```
CYB405{kn0wn_pl41nt3xt_b34ts_x0r}
```

## Key lesson

Two lessons stack: **encoding is not encryption** (base64/hex/reverse are reversible with no secret), and **even XOR encryption falls to a known-plaintext attack** when the plaintext format is predictable and the key is short and reused. Real confidentiality needs a strong cipher with a long, secret, non-reused key.

## Files

| File | Purpose |
|---|---|
| `challenge.py` | the encoded CTF challenge (no key inside) |
| `solve.py` | 3-phase solver: strip layers, recover key, decrypt |
| `CYB405_Bonus1_CTF_Report.pdf/.docx` | full writeup |
| `img/decode_chain.png` | the decode + key-recovery diagram |
| `VIEWER-GUIDE.md` | step-by-step discovery walkthrough |
| `social-posts.md` | 4-platform social posts + YouTube metadata |

---

*Self-authored challenge, solved and documented in an isolated lab. No production system or real data involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
