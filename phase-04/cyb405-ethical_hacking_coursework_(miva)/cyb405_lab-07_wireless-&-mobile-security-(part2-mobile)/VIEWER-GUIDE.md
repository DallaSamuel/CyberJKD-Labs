# Viewer Step-by-Step Guide - Lab 7 (Mobile): APK Static Analysis

> A follow-along walkthrough of how this lab was actually done - including the dead-ends and how they were solved. Target: InsecureBankv2, a deliberately vulnerable Android app. Attacker: Kali Linux. Only ever point these tools at an app you own or have permission to test.

---

## 0. Get the APK onto Kali (first wall)

My Kali VM is air-gapped (Host-Only only), so it has no internet and cannot download anything. A direct download fails with `Temporary failure in name resolution` - that is not a broken link, it is no DNS.

Fix: move the APK in through the host **shared folder**, then verify it arrived intact.

```bash
cd ~/lab7/apk
file InsecureBankv2.apk
sha256sum InsecureBankv2.apk
```

You want `Android package (APK)` and a SHA256 that matches the source. If it matches, the transfer was clean.

---

## 1. Install the tools (second wall)

On my Kali build, `apktool` and `jadx` were **not installed**, and with no internet I could not fetch them. If your Kali is the same, give it internet for a few minutes.

**Add a temporary NAT adapter:** power off Kali, in VirtualBox add Adapter 2 as NAT, turn the host VPN off, boot, then:

```bash
ping -c 2 8.8.8.8
sudo apt update
sudo apt install -y apktool jadx
```

> If `ping 8.8.8.8` works but hostnames fail, it is just DNS: `echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf`. Once the tools are in, you can air-gap again.

---

## 2. Decompile (third wall)

Kali's jadx wrapper resolves **relative** paths against its own install folder, not your current directory. A bare filename gives `File not found`; a relative output dir gives `Can't create directory`. The fix for both is **absolute paths**.

```bash
apktool d InsecureBankv2.apk -o ibank_src
jadx -d ~/lab7/apk/ibank_jadx ~/lab7/apk/InsecureBankv2.apk
```

Confirm jadx actually wrote the Java tree:

```bash
ls ~/lab7/apk/ibank_jadx/sources/com/android/insecurebankv2/ | head
```

You should see `CryptoClass.java`, `DoLogin.java`, `MyBroadCastReceiver.java`, and friends. If you do, you are through the hard part.

---

## 3. Finding 1 - the hardcoded key

```bash
grep -rniE "super secret key|SecretKeySpec|AES/CBC/PKCS5Padding" \
  ibank_jadx/sources/com/android/insecurebankv2/
```

The hit is `CryptoClass.java:22`:

```java
String key = "This is the super secret key 123";
```

Open `CryptoClass` in jadx-gui and read how it is used, then follow the key into `DoLogin.java`, where it encrypts the saved password. Since the key ships inside the app, decompiling the app hands you the key too - the encryption protects nothing.

---

## 4. Finding 2 - insecure data storage

```bash
grep -rniE "getSharedPreferences|superSecurePassword|openFileOutput|getExternalStorage" \
  ibank_jadx/sources/com/android/insecurebankv2/
```

Read the hits in order. The password is written to SharedPreferences in `DoLogin.java`. The one that should jump out is:

```java
// MyBroadCastReceiver.java:21
SharedPreferences settings = context.getSharedPreferences("mySharedPreferences", 1);
```

Mode `1` is **MODE_WORLD_READABLE** - any other app on the device can read the stored credentials. Then note `DoTransfer.java` and `ViewStatement.java` writing account statements to **external storage** with no encryption.

---

## 5. The bonus the manifest hands you

```bash
grep -E "allowBackup|debuggable|android:exported" ibank_src/AndroidManifest.xml
```

Three gifts: `allowBackup="true"` (data extractable over `adb backup`), `debuggable="true"`, and several `exported="true"` components, including a content provider any app can query. All real findings, all free.

---

## 6. What it all means

| What I found | Why it's dangerous | How to fix it |
|---|---|---|
| Hardcoded AES key | Key ships in the APK, so "encryption" is recoverable | Android Keystore, never in the app |
| World-readable prefs | Any app on the device reads the creds | `MODE_PRIVATE` + `EncryptedSharedPreferences` |
| Statements on external storage | World-readable, unencrypted | Internal storage, encrypt at rest |
| Exported components | Externally reachable attack surface | `exported="false"` by default |
| allowBackup / debuggable | Data extraction + runtime inspection | `false` for release builds |

---

*Self-built, air-gapped lab using InsecureBankv2, a vulnerable app published for training. No production system or real data involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
