# Viewer Step-by-Step Guide - Lab 6: Web App Hacking (SQLi & XSS)

> A follow-along walkthrough of how this lab was actually done - including the dead-ends and how they were solved. Target: a self-built, air-gapped OWASP Juice Shop. Attacker: Kali Linux.

---

## 0. The setup (before any hacking)

OWASP Juice Shop runs as a Docker container. I gave it its own Ubuntu Server VM at a static Host-Only IP so the attacker and target are properly separated.

```bash
# On the target VM (temporary internet via NAT, just to pull the image)
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo docker pull bkimminich/juice-shop
sudo docker run -d --name juice-shop --restart unless-stopped -p 3000:3000 bkimminich/juice-shop
```

Then I **removed the NAT adapter** to air-gap the target and took a `clean-base` snapshot.

**Gotcha I hit:** Ubuntu 24.04 hung at *"Loading essential drivers"* on VirtualBox. Fix was booting with `nomodeset` (GRUB → press `e` → add `nomodeset` → Ctrl+X), then making it permanent in `/etc/default/grub`. A VPN also silently blocked the Host-Only network until I enabled *"Allow LAN connections"*.

**Verify from Kali:**
```bash
ping -c 3 192.168.56.104
curl -I http://192.168.56.104:3000     # expect: HTTP/1.1 200 OK
```

---

## 1. Map the app

**Directory brute-force.** Juice Shop is a single-page app, so it returns `200` with the *same* homepage for any unknown path - which makes gobuster think every word is a hit. The fix is to filter on that homepage's length:

```bash
gobuster dir -u http://192.168.56.104:3000 \
  -w /usr/share/wordlists/dirb/common.txt \
  -t 5 --delay 20ms --exclude-length 9984 -o gobuster.txt
```

> I first ran it at 20 threads and **crashed the container** - a single-process Node app can't take that. It auto-restarted (thanks to `--restart unless-stopped`); I re-ran at `-t 5`.

Real endpoints that surfaced: `/ftp`, `/api`, `/apis`, `/assets`.

**Burp mapping.** Launch Burp → Proxy → *Open browser* → browse the storefront, login page, and search. **Target → Site map** records the REST API, revealing the two endpoints that matter: `/rest/products/search` and `/rest/user/login`.

---

## 2. Low-hanging fruit: `/ftp`

Open `http://192.168.56.104:3000/ftp` in the browser. It's a **directory listing with no login** - exposing a KeePass vault (`incident-support.kdbx`), `.bak` backups, and `acquisitions.md`, which opens in full and is literally stamped *"This document is confidential! Do not distribute!"*

That's a Broken Access Control finding, found with nothing but a URL.

---

## 3. SQL injection - logging in as admin

Go to the Login page. In the **email** field, enter:

```
' or 1=1-- 
```

(note the trailing space after `--`), any password, and submit. The `' or 1=1` makes the WHERE clause always true and the `-- ` comments out the password check - so you authenticate as the **first** user in the table, the administrator. Juice Shop pops a green banner: *"You successfully solved a challenge: Login Admin."*

---

## 4. SQL injection - dumping the user database

This is the UNION attack, done in **Burp Repeater** for control. The search endpoint drops your input straight into SQL - proven because a bad payload makes it spit back a `500` with the **actual backend query** in the error.

**Find the column count.** A UNION needs the same number of columns as the original query. The usual "9 columns" didn't work here, so instead of guessing I asked the database directly:

```
qwert')) ORDER BY 50-- 
→ SQLITE_ERROR: 1st ORDER BY term out of range - should be between 1 and 10
```

So the `Products` table has **10 columns**. (The classic mistake is jumping 9 → 11 and skipping 10 - which is exactly what I did before the `ORDER BY` probe set me straight.)

**Build the matching 10-column UNION:**

```
qwert')) UNION SELECT id, email, password, '4','5','6','7','8','9','10' FROM Users-- 
```

Response flips to `200 OK` and returns the whole `Users` table - **24 accounts**, each email in the `name` field and its MD5 password hash in `description`. The admin hash `0192023a7bbd73250516f069df18b500` is just the unsalted MD5 of `admin123`.

> Tip: the browser shows *"No results found"* because the UI can't render user rows as product cards - but the raw API response (seen in Burp) contains all the data. Also watch for accidental line breaks in the request and use commas (`,`) between columns, not spaces.

---

## 5. Cross-site scripting (XSS)

Back in the app, type this into the **search box** and hit Enter:

```html
<iframe src="javascript:alert('xss')">
```

A JavaScript `alert` saying `xss` fires - the app rendered your input as live code instead of text. In a real attack this same reflection point can steal session tokens or harvest credentials.

---

## 6. What it all means

| What I did | Why it's dangerous | How to fix it |
|---|---|---|
| Logged in with no password | Any input becomes SQL logic | Parameterised queries |
| Dumped 24 user records | UNION reads other tables | Parameterised queries |
| Read confidential files at `/ftp` | No authorisation check | Auth + allow-listed file access |
| Ran JavaScript via search | Input rendered as code | Output encoding + CSP |
| Cracked admin instantly | Unsalted MD5 | bcrypt / Argon2 |

---

*Self-built, air-gapped OWASP Juice Shop. No production system or real data involved.*

**CyberJKD - Becoming dangerous through fundamentals.**
