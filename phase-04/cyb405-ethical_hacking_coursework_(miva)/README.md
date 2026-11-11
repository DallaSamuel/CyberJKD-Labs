# CYB 405 - Lab 7: Wireless & Mobile Security (Part 2 - Mobile)

![Platform](https://img.shields.io/badge/Platform-InsecureBankv2-f0a73d?style=flat-square)
![Attacker](https://img.shields.io/badge/Attacker-Kali%20Linux-557C94?style=flat-square&logo=kalilinux&logoColor=white)
![Tools](https://img.shields.io/badge/Tools-apktool%20%7C%20jadx-e34f26?style=flat-square&logo=android&logoColor=white)
![Category](https://img.shields.io/badge/OWASP-Mobile%20Top%2010-c9252d?style=flat-square)
![Mobile](https://img.shields.io/badge/Mobile%20Task-Complete-3fb950?style=flat-square)
![Wireless](https://img.shields.io/badge/Wireless%20Task-Pending%20Hardware-b9770e?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel |
| **Date** | November 2026 |
| **Platform** | InsecureBankv2 (OWASP vulnerable app) on an air-gapped Kali VM |
| **Lab Source** | CYB 405 - Introduction to Ethical Hacking (Miva Open University) |
| **Roadmap** | [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap) - Phase 04, Mobile Security |

---

## Objective

Decompile an Android APK to identify **insecure local data storage** and **hardcoded secrets / API keys**, then recommend remediation. This is **Task 2** of Lab 7. Task 1 (WPA2 handshake capture) is documented as pending the required USB wireless adapter (see [Wireless Task Status](#wireless-task-status)).

## Business Problem

Mobile apps ship their logic to the user's device, so anything baked into the binary, keys, credentials, or unprotected local data, is recoverable by anyone who decompiles it. A single hardcoded key or a world-readable preferences file can hand an attacker every user's credentials. This lab shows, on an intentionally-vulnerable target, how those flaws are found and how to fix them, so the same classes of bug can be recognised in real client-side code.

## Environment

| Component | Detail |
|---|---|
| Host | Windows 11, Oracle VirtualBox |
| Attacker | Kali Linux 2026.1 - `192.168.56.102` |
| Target | `InsecureBankv2.apk` (deliberately vulnerable training app) |
| Integrity | SHA256 `b18af2a0e44d7634bbcdf93664d9c78a2695e050393fcfbb5e8b91f902d194a4` |
| Network | VirtualBox Host-Only `192.168.56.0/24`, **air-gapped**; temporary NAT only to install tooling |
| Tools | apktool 2.7.0, jadx 1.5.6, grep, strings |

## Architecture

![APK Static Analysis Flow](img/architecture.png)

```
Kali Linux 2026.1 (air-gapped Host-Only; temporary NAT only to install tooling)
│
InsecureBankv2.apk  ──► apktool d ──► AndroidManifest.xml · smali · resources
        │
        └──────────────► jadx ─────► readable Java (com/android/insecurebankv2/)
                                        │
                                        ▼
                                   grep / review
                                        │
                 ┌──────────────────────┼───────────────────────┐
                 ▼                       ▼                       ▼
        F1 Hardcoded key        F2 Insecure storage     F5-F7 Manifest exposures
        (CryptoClass:22)        (WORLD_READABLE)         (backup/debug/exported)
                 └──────────────────────┴───────────────────────┘
                                        ▼
                                  REMEDIATION
```

## Key Concepts

- **Static analysis** - inspecting an app without running it, by decompiling the APK.
- **APK internals** - `AndroidManifest.xml` (permissions, components, flags), `classes.dex` (bytecode), `res/` (resources).
- **Insecure data storage** - credentials in plaintext, world-readable SharedPreferences, or on external storage.
- **Hardcoded secrets** - keys or credentials embedded in the binary, trivially extractable.
- **MODE_WORLD_READABLE** - a deprecated SharedPreferences mode (int `1`) that lets any app on the device read the file.

## Walkthrough Summary

| # | Phase | Result |
|---|---|---|
| A | Tooling + transfer | APK staged via shared folder (air-gapped), SHA256 verified; apktool + jadx installed via temp NAT |
| B | Decompilation | apktool (manifest/smali) + jadx (readable Java) completed |
| C | Finding 1 | Hardcoded AES key `"This is the super secret key 123"` in `CryptoClass.java:22` |
| D | Finding 2 | Credentials in SharedPreferences, **world-readable** in `MyBroadCastReceiver.java:21`; statements on external storage |
| E | Manifest | `allowBackup`, `debuggable`, and multiple `exported="true"` components incl. a content provider |

> Full step-by-step discovery walkthrough: see **[VIEWER-GUIDE.md](VIEWER-GUIDE.md)**.

## Command Reference

```bash
# Verify the transferred APK
file InsecureBankv2.apk
sha256sum InsecureBankv2.apk

# Decompile (jadx needs ABSOLUTE paths on Kali's wrapper)
apktool d InsecureBankv2.apk -o ibank_src
jadx -d ~/lab7/apk/ibank_jadx ~/lab7/apk/InsecureBankv2.apk

# Finding 1 - hardcoded key
grep -rniE "super secret key|SecretKeySpec|AES/CBC/PKCS5Padding" \
  ibank_jadx/sources/com/android/insecurebankv2/

# Finding 2 - insecure storage
grep -rniE "getSharedPreferences|superSecurePassword|openFileOutput|getExternalStorage" \
  ibank_jadx/sources/com/android/insecurebankv2/

# Supporting - manifest flags
grep -E "allowBackup|debuggable|android:exported" ibank_src/AndroidManifest.xml
```

## Findings

| # | Finding | OWASP Mobile | Severity |
|---|---|---|---|
| 1 | Hardcoded AES key in app code | M10 Insufficient Cryptography | High |
| 2 | Credentials world-readable in one path | M9 Insecure Data Storage | High |
| 3 | Weak at-rest protection (hardcoded-key AES) | M10 Insufficient Cryptography | High |
| 4 | Sensitive statements on external storage | M9 Insecure Data Storage | Medium |
| 5 | Exported content provider | M8 Security Misconfiguration | Medium |
| 6 | `allowBackup` enabled | M8 Security Misconfiguration | Medium |
| 7 | `debuggable` enabled | M8 Security Misconfiguration | Medium |

## Remediation

| Finding | Fix |
|---|---|
| Hardcoded key / weak crypto | Android Keystore for keys (never in the APK); `EncryptedSharedPreferences` for storage. |
| World-readable storage | Remove `MODE_WORLD_READABLE`; use `MODE_PRIVATE`; store a revocable token, not the password. |
| External-storage files | Keep sensitive files in internal storage (`getFilesDir`); encrypt at rest. |
| Exported components | `exported="false"` by default; signature-level permissions for the rest. |
| Backup / debug flags | `allowBackup="false"`, `debuggable="false"` for release builds. |

## Verification Checklist

- [x] APK integrity confirmed by SHA256 after transfer
- [x] apktool and jadx decompile completed
- [x] Hardcoded key located and traced to its usage
- [x] Insecure storage confirmed, including a world-readable path
- [x] Manifest exposures enumerated
- [x] Remediation mapped for every finding
- [ ] Task 1 (WPA2 capture) - pending USB adapter

## Troubleshooting Log

| Issue | Cause | Fix |
|---|---|---|
| APK download failed (name resolution) | Kali air-gapped, no DNS | Transferred via host shared folder |
| `apktool` / `jadx` not found, could not install | No internet on Kali | Temporary NAT adapter, installed, continued offline |
| jadx "File not found" | Kali wrapper resolves bare paths against its install dir | Passed absolute input path |
| jadx "Can't create directory" | Same wrapper behaviour on output path | Passed absolute `-d` path |

## What I'd Change for Production

- Run static analysis (for example MobSF) in CI on every build.
- Add a secrets-scanning pre-commit hook so keys never reach the binary.
- Enforce a release checklist: `exported=false`, `allowBackup=false`, `debuggable=false`, Keystore-backed crypto.
- Replace client-side secrets with a backend broker and short-lived tokens.

## Wireless Task Status

Task 1 (WPA2 handshake capture and crack) requires a USB Wi-Fi adapter with monitor mode and injection, which VirtualBox cannot provide via the host's built-in card. The task is **deferred, not dropped**: full methodology is in the Lab 7 Execution Guide and will be completed against a self-owned test AP once the adapter is sourced.

## Connection to Roadmap

This lab reinforces the **Mobile / client-side security** competency on the CyberJKD roadmap - APK decompilation, insecure-storage and hardcoded-secret identification, manifest review, and standards-mapped remediation - core skills for the Cloud Security Engineer / SOC Analyst track.

---

*All testing was performed against InsecureBankv2, an intentionally-vulnerable application published for training. No production system or real data was involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
