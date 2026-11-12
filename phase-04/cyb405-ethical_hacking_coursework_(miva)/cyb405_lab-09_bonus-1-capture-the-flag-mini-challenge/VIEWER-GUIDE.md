# Viewer Step-by-Step Guide - Bonus 1: CTF Mini-Challenge

> A follow-along walkthrough of solving the layered-encoding CTF, including the moment the challenge stops being "reverse a recipe" and becomes real key recovery. Self-authored challenge, solved in an isolated Kali lab.

---

## 0. The challenge

You're handed `challenge.py`. Read it first:

```bash
cd ~/bonus1
cat challenge.py
```

It tells you the flag was **XOR-encrypted with a short secret key**, then hex-encoded, then the hex string was reversed, then base64-encoded. The twist: **the key is not in the file.** You get one hint, every flag starts with `CYB405{`.

So three of the four layers peel with no secret. The XOR layer does not, and that's the actual challenge.

---

## 1. Phase 1 - strip the keyless layers

base64, reverse, and hex all undo without knowing anything:

```python
import base64
from challenge import PAYLOAD
rev  = base64.b64decode(PAYLOAD).decode()   # undo base64
hexs = rev[::-1]                            # undo the reverse
ct   = bytes.fromhex(hexs)                  # undo hex -> raw XOR ciphertext
print(ct.hex())
```

Now you have the raw XOR ciphertext, but it's still scrambled because you don't have the key.

---

## 2. Phase 2 - recover the key from known plaintext

This is the real move. A repeating-key XOR has a fatal weakness: **if you know any plaintext, you get the key for free.** XOR is reversible, so `plaintext XOR ciphertext = key`.

You know the flag starts with `CYB405{`. XOR that known prefix against the first 7 ciphertext bytes:

```python
KNOWN  = b"CYB405{"
stream = bytes([ct[i] ^ KNOWN[i] for i in range(len(KNOWN))])
print(stream.decode())     # -> m1v4m1v
```

Look at that output: `m1v4m1v`. It **repeats every 4 characters**. That's the key cycling. So the key length is 4 and the key is `m1v4`:

```python
def period(s):
    for p in range(1, len(s)):
        if all(s[i] == s[i % p] for i in range(len(s))):
            return p
    return len(s)
KEY = stream[:period(stream)].decode()     # -> 'm1v4'
```

No brute force, no guessing. The predictable flag prefix leaked the key straight out of the ciphertext.

---

## 3. Phase 3 - decrypt

Now that you have the key, decrypt the whole thing:

```python
flag = bytes([b ^ ord(KEY[i % len(KEY)]) for i, b in enumerate(ct)]).decode()
print(flag)     # -> CYB405{kn0wn_pl41nt3xt_b34ts_x0r}
```

The flag is the lesson.

---

## 4. Running it

All of the above lives in `solve.py`. Overwrite any old copy, then run:

```bash
python3 solve.py
```

You'll see `[P1]` the ciphertext, `[P2]` the key recovered from the prefix, and `[P3]` the recovered flag. Screenshot that, it's your evidence.

---

## 5. What it all means

| Step | Why it matters |
|---|---|
| Peeled base64 / hex / reverse | Encoding is reversible with no secret, it is **not** encryption |
| Recovered the key from `CYB405{` | A **known-plaintext attack**: predictable plaintext leaks the key |
| Key was short and reused | Repeating-key XOR offers no real protection |

The takeaway for real systems: never roll your own crypto. Use a vetted cipher with a long, secret, non-reused key, or the first known byte of plaintext unravels the whole thing.

---

*Self-authored challenge, solved and documented in an isolated lab. No production system or real data involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
