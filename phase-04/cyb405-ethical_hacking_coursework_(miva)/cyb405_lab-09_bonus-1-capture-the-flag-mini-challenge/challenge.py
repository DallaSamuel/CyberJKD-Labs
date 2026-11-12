#!/usr/bin/env python3
# CYB 405 - Bonus 1 CTF (v2): recover the flag.
#
# The flag was encrypted with a SHORT repeating-key XOR, then hex-encoded,
# then the hex string was reversed, then base64-encoded. The XOR key is a
# secret and is NOT in this file - you must recover it.
#
# Hint: every flag begins with the known plaintext  CYB405{
import base64

PAYLOAD = "MDE2NDY0OTQyMzc0MjA1MGU1NjU5MjU0NTE3MDIwZjVjNTAwYTExNDIzYTUxMDEwMzBmNWQwNDBkNTAwNDM4NmUy"

# Keyless layers you can peel without the secret:
#   step = base64.b64decode(PAYLOAD).decode()   # undo base64
#   step = step[::-1]                            # undo the reverse
#   ct   = bytes.fromhex(step)                   # undo hex -> XOR ciphertext
# Then recover the key from the known "CYB405{" prefix and decrypt.
