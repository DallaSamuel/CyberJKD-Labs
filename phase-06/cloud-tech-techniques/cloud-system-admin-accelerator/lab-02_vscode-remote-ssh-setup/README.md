# VS Code Home Lab Setup - Git, Extensions & Remote-SSH

![VS Code](https://img.shields.io/badge/VS%20Code-Latest-007ACC?style=flat-square&logo=visualstudiocode)
![Git](https://img.shields.io/badge/Git-2.55.0-F05032?style=flat-square&logo=git)
![Kali Linux](https://img.shields.io/badge/Kali%20Linux-Remote--SSH-557C94?style=flat-square&logo=kalilinux)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel (CyberJKD) |
| **Date** | September 18, 2026 |
| **Platform** | Windows 11 (HP EliteBook 835 G8) → Kali Linux VM |
| **Course** | Cloud System Admin Accelerator - How To Automate The VM Deployment - VSCode Guide |
| **Roadmap** | Phase 06 · Cloud Tech Techniques · Cloud System Admin Accelerator |
| **Video Walkthrough** | [VS Code Home Lab Setup](https://youtu.be/K8Qd1uASNPE) |
| **Viewer Guide** | [CyberJKD-VSCode-Remote-SSH-Viewer-Guide.pdf](CyberJKD-VSCode-Remote-SSH-Viewer-Guide.pdf) |

---

## Objective

Set up Visual Studio Code as the primary editor for home-lab and CyberJKD-Labs work - Git integration, core extensions, and a working Remote-SSH connection into the Kali VM - so lab scripting and documentation can happen in one environment instead of juggling a separate SSH terminal and text editor.

## Business Problem

Editing files over a raw SSH session (`nano`/`vim`) works, but it's slow and error-prone for anything beyond a quick edit - no IntelliSense, no syntax highlighting, no easy multi-file search. IT and cloud teams standardize on an editor like VS Code with Remote Development extensions specifically so engineers can work directly on remote hosts (servers, VMs, containers) with the full editor experience, without files ever needing to be copied back and forth.

This is the **VSCode Guide** module of Jhante Charles's Cloud System Admin Accelerator, under "How To Automate The VM Deployment" - the same category as the Terraform AD DC lab. Where that lab automated *provisioning* a VM, this module sets up the *editor* used to write and maintain that kind of infrastructure code and to work directly on deployed VMs going forward - including two real failures hit and resolved along the way, not just a clean install walkthrough.

| Role | How this applies |
|---|---|
| Cloud / Systems Administrator | Editing config and scripts directly on servers, with the full editor instead of `nano` |
| DevOps / Platform Engineer | Git + Terraform + YAML tooling in one place for infrastructure code |
| Help Desk / IT Support | The SSH troubleshooting chain here (timeout → refused → service down) is everyday support work |
| Security Engineer | Same Remote-SSH workflow reaches attack boxes and jump hosts in a lab |

## Environment

| Component | Value |
|---|---|
| Host machine | HP EliteBook 835 G8, Windows 11, AMD Ryzen 3 PRO 5450U |
| VS Code | Latest (pre-installed) |
| Git | v2.55.0.3 (installed via `winget`) |
| Target VM | Kali Linux (CYB 405 host-only lab network) |
| Kali IP | `192.168.56.102` |
| Kali login | `kali` / `kali` (default) |
| Repo | [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs) |
| Local repo path | `Documents\CyberJKD\CyberJKD-Labs` |

## Key Concepts

- **Remote-SSH (VS Code extension)** - connects a VS Code window directly to a remote machine's file system and shell, so editing happens with full IntelliSense instead of a plain terminal editor
- **Workspace Trust** - VS Code's Restricted Mode blocks certain features until you explicitly trust a folder's authors; cloning a repo directly auto-trusts it *(see [Review Note 2](#review-notes-october-2026))*
- **SSH host aliases** (`~/.ssh/config`) — named shortcuts (`Host kali`) mapping to an IP + username, so you connect with a name instead of typing the full address every time
- **`http.postBuffer`** - a Git config value controlling how much data Git buffers per HTTP request; too small a default can cause large clones to fail mid-transfer *(see [Review Note 1](#review-notes-october-2026))*
- **systemd service management** (`systemctl start` / `enable` / `status`) — starting a service for the current session vs. enabling it to persist across reboots
- **VS Code Server** *(added in review)* - Remote-SSH works by installing a small server process in the remote user's home folder (`~/.vscode-server` on Kali). The editor UI stays on Windows; file access, terminals and most extensions run on the VM. That's why language extensions have to be installed again "on SSH: kali".
- **Host key verification** *(added in review)* - the first SSH connection to a machine shows its key fingerprint and asks you to confirm it (screenshot 14). Accepting it stores the key in `known_hosts`; if the key ever changes, SSH refuses to connect, which is what protects against a machine-in-the-middle.

## Architecture

![VS Code Remote-SSH Setup Architecture](images/16-architecture-diagram.png)

```
Windows 11 Host (HP EliteBook 835 G8)
   │
   ├── VS Code
   │    ├── Extensions: Remote-SSH, PowerShell, YAML, Python, GitLens, Terraform, Docker
   │    ├── Git v2.55.0.3
   │    └── ~/.ssh/config
   │         ├── Host kali → 192.168.56.102 (CYB 405 host-only network)
   │         └── Host ubuntu-hardening → 192.168.1.103 (home-lab network, untouched)
   │
   ├── Local repo: Documents\CyberJKD\CyberJKD-Labs
   │    └── cloned from github.com/DallaSamuel/CyberJKD-Labs
   │
   └── Remote-SSH connection
        └── Kali Linux VM (192.168.56.102)
             └── SSH service (started + enabled via systemctl)
```

**Reviewed diagram (October 2026)** - dark version with the versions from the screenshots and the troubleshooting chain:

![VS Code Remote-SSH setup - reviewed architecture](images/17-architecture-diagram-reviewed.png)

## Exercises

**A. Confirm VS Code Installation** - Already installed. Workspace opened in Restricted Mode (no folder trusted yet); Docker extension recommendation prompt appeared on first launch and was accepted.

![Fresh VS Code install, Restricted Mode banner, Docker extension prompt](images/01-vscode-initial-launch.png)

**B. Verify Git** - Ran `git --version` in the integrated terminal (`` Ctrl+` ``); command not recognized, confirming Git wasn't installed.

![git --version not recognized](images/02-git-not-installed.png)

**C. Install Git** - `winget install Git.Git`, version 2.55.0.3, successful install.

![winget Git install output](images/03-git-install-success.png)

**D. Install Core Extensions** - Installed via terminal in a single batch: `ms-vscode-remote.remote-ssh`, `ms-vscode.powershell`, `redhat.vscode-yaml`, `ms-python.python`, `eamodio.gitlens`, `hashicorp.terraform` (Docker extension installed separately via the earlier prompt).

![All six extensions installed successfully](images/04-extensions-installed.png)
![PowerShell extension active in terminal](images/05-powershell-extension-active.png)

**E. Locate the Repo** - No local clone of CyberJKD-Labs existed yet on this device - confirmed via File Explorer against the `Documents\CyberJKD` folder, which held other CyberJKD project folders but not this repo.

![CyberJKD folder contents - no Labs repo present](images/06-folder-before-clone.png)

**F. Clone CyberJKD-Labs** - First attempt failed mid-transfer with an RPC/buffer error on a 1249-object repo. Fixed by raising Git's HTTP post-buffer size, then re-ran the clone clean.

![Failed clone - RPC error, early EOF](images/07-clone-rpc-error.png)
![Successful clone after buffer fix](images/08-clone-success.png)

**G. Open and Trust the Repo** - File → Open Folder → `CyberJKD-Labs`. Cloning directly auto-trusted the workspace; Restricted Mode banner did not reappear.

![CyberJKD-Labs open - phase-01 through phase-06, README.md visible](images/09-repo-opened.png)

**H. Configure Remote-SSH** - Added `kali` and `ubuntu-hardening` host entries to `~/.ssh/config`. First connection attempt to `kali` used the wrong IP (home-lab range instead of the CYB 405 host-only range) and timed out; corrected to `192.168.56.102`.

![SSH config with both host entries](images/10-ssh-config.png)
![Connection timed out — wrong IP](images/11-connection-timeout.png)

**I. Diagnose and Fix Connection Refused** - After correcting the IP, VS Code returned "Permission denied" with no password prompt - a stale extension state, not a real auth failure. Ran a raw `ssh kali@192.168.56.102` directly in the terminal to get the real error: **Connection refused, port 22** - meaning Kali's SSH service wasn't running at all (Kali does not start SSH by default). Started and enabled the service directly on the Kali VM, then confirmed the raw SSH connection worked.

![Permission denied via Remote-SSH extension](images/12-permission-denied.png)
![Raw ssh - connection refused, port 22](images/13-connection-refused.png)
![Successful raw SSH login to Kali](images/14-raw-ssh-success.png)

**J. Connect via Remote-SSH** - With the SSH service confirmed running, reconnected through the extension. Status bar shows **SSH: kali** in green - full editor session now running directly on the VM.

![Remote-SSH connected - green "SSH: kali" status bar](images/15-remote-ssh-connected.png)

## Command Reference

```powershell
# Verify / install Git
git --version
winget install Git.Git

# Install extensions
code --install-extension ms-vscode-remote.remote-ssh
code --install-extension ms-vscode.powershell
code --install-extension redhat.vscode-yaml
code --install-extension ms-python.python
code --install-extension eamodio.gitlens
code --install-extension hashicorp.terraform

# Fix clone RPC/buffer failure, then clone
git config --global http.postBuffer 524288000
cd "$HOME\Documents\CyberJKD"
git clone https://github.com/DallaSamuel/CyberJKD-Labs.git

# Diagnose the SSH connection directly
ssh kali@192.168.56.102
```

```bash
# On the Kali VM itself - start and persist the SSH service
sudo systemctl start ssh
sudo systemctl enable ssh
sudo systemctl status ssh
```

**Added in review:**

| Command | Purpose |
|---|---|
| `git config --global --unset http.postBuffer` | Remove the 500 MB buffer left behind by the clone fix (Review Note 1) |
| `git config --global --list --show-origin` | See every global Git setting and which file it lives in |
| `git clone --depth 1 <url>` | Smaller first download if a clone keeps dropping on a slow link |
| `code --list-extensions --show-versions` | Prove which extensions (and versions) are installed |
| Command Palette → **Remote-SSH: Show Log** | The real ssh output behind a vague Remote-SSH error (Review Note 3) |
| Command Palette → **Workspaces: Manage Workspace Trust** | See which folders, or parent folders, are trusted (Review Note 2) |
| `sudo systemctl enable --now ssh` | Start and enable in one command |
| `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` (on Kali) | Show the host key fingerprint, to compare with the one SSH asks you to accept |
| `ssh-keygen -t ed25519` then `type $env:USERPROFILE\.ssh\id_ed25519.pub \| ssh kali "cat >> ~/.ssh/authorized_keys"` | Switch from password to key login (production point 1) |

## Verification Checklist

- [x] `git --version` returns `2.55.0.3`
- [x] All six core extensions + Docker installed and listed in the Extensions panel
- [x] `CyberJKD-Labs` cloned locally with 0 file corruption (1249/1249 objects received)
- [x] Repo opens with Restricted Mode disabled (workspace trusted)
- [x] `~/.ssh/config` contains correct `kali` and `ubuntu-hardening` host entries
- [x] `sudo systemctl status ssh` on Kali shows `active (running)` - *no screenshot of this step, see Review Note 4*
- [x] Raw `ssh kali@192.168.56.102` connects and authenticates
- [x] VS Code Remote-SSH status bar shows green **SSH: kali**
- [ ] The `http.postBuffer` change is what fixed the clone: **no - see Review Note 1**
- [ ] Global Git config left clean after troubleshooting: **no - the 500 MB postBuffer is still set**

## Troubleshooting Log

**1. `git clone` failed mid-transfer - RPC error, early EOF.** Cloning the 1249-object CyberJKD-Labs repo over HTTPS failed partway through with `error: RPC failed; curl 18 transfer closed with outstanding read data remaining` and `fatal: early EOF`. This is a known Git-over-HTTPS issue on larger repos where the default buffer size is too small for the transfer. Fixed with `git config --global http.postBuffer 524288000` (500 MB buffer), then re-ran the clone clean. *(See [Review Note 1](#review-notes-october-2026).)*

**2. Commands silently combined when pasted.** Running `git config --global http.postBuffer 524288000 git clone https://...` as one pasted block caused PowerShell to treat the clone command as extra arguments to `git config`, producing `error: no action specified`. Fixed by running each command on its own line, waiting for the prompt to return between them.

**3. Remote-SSH connection timed out to the wrong network.** Initial SSH config pointed Kali at `192.168.1.102` (the home-lab network range used by other, unrelated VMs). Kali was actually running on the CYB 405 host-only lab network at `192.168.56.102`. Fixed by correcting the `HostName` value in `~/.ssh/config`.

**4. "Permission denied" with no password prompt.** After correcting the IP, the Remote-SSH extension returned `Could not establish connection to "kali": Permission denied` without ever prompting for a password - misleading, since it suggested an authentication problem. Bypassing the extension with a raw `ssh kali@192.168.56.102` in the terminal revealed the real issue.

**5. Raw SSH returned "Connection refused, port 22."** This confirmed the actual root cause: Kali's SSH server wasn't running at all - Kali does not enable or auto-start SSH by default on a fresh install. Fixed directly on the Kali VM with `sudo systemctl start ssh` (for the current session) and `sudo systemctl enable ssh` (to persist across reboots). Raw SSH then connected and authenticated cleanly, and the Remote-SSH extension connected successfully immediately after.

## Review Notes (October 2026)

I came back to this lab and checked each screenshot against the text, and the two technical claims against the official Git and VS Code documentation. The setup itself works - Git, extensions, clone, SSH config and the final Remote-SSH connection are all shown. The best part of the lab is Troubleshooting #4-5: dropping below the extension to a raw `ssh` to get the real error is exactly the right instinct. The notes below are about *why* two of the fixes worked, which is what an interviewer asks.

**1. `http.postBuffer` didn't fix the clone - the retry did.** Git's own documentation for [`http.postBuffer`](https://git-scm.com/docs/git-config#Documentation/git-config.txt-httppostBuffer) says it's the buffer used "when POSTing data to the remote system". That's the data Git *sends*, which in practice means pushes. It says raising it "is only effective for disabling chunked transfer encoding", that it should be used only with servers or proxies that are HTTP/1.0-only or non-compliant, and that it "is not, in general, an effective solution" while it can "increase memory consumption significantly since the entire buffer is allocated even for small pushes". A clone *downloads*. The error in screenshot 07 (`curl 18 transfer closed with outstanding read data remaining`, `early EOF`) is the connection dropping partway through the download. The second attempt (screenshot 08) received the same 1249 objects at 926 KiB/s without trouble, which fits a transient network drop. So:
- the "fix" probably did nothing;
- it's still set globally, so every push from this machine now allocates a 500 MB buffer.

`git config --global --unset http.postBuffer` puts it back. If a clone fails again, first retry it, then try `--depth 1` or a different network.

**2. Cloning doesn't auto-trust a folder in VS Code.** The [Workspace Trust documentation](https://code.visualstudio.com/docs/editing/workspaces/workspace-trust) says a new folder opens in Restricted Mode until you trust it, and that trusting a **parent** folder trusts everything inside it. The Recent list in screenshot 09 shows `CyberJKD Roadmap` had already been opened from `Documents\CyberJKD`. The most likely explanation is that `Documents\CyberJKD` (or a folder above it) was trusted during that earlier work, so the new clone inherited trust. **Workspaces: Manage Workspace Trust** will show which folder it was. Also, the clone was done with `git clone` in the terminal, not VS Code's own Clone command, so VS Code had no way to know it was a clone at all.

**3. The "Permission denied" cause is unconfirmed, and the log has the answer.** The README calls it "a stale extension state". Nothing on screen confirms that, and the dialog in screenshot 12 links an **Output Log** that records the exact ssh messages Remote-SSH received. The raw `ssh` test was the right move; next time, **Remote-SSH: Show Log** gives the same answer without leaving the extension. What *is* proven is the conclusion: sshd wasn't running (screenshot 13).

**4. Small evidence gaps.**
- The checklist ticks `sudo systemctl status ssh` showing `active (running)`, but there's no screenshot of it (or of `enable`); screenshot 14's successful login proves the service was up, not that it's enabled at boot.
- Screenshot 15 proves the connection (**SSH: kali** in the status bar - blue in this theme, not green) but no folder is open on Kali yet. Opening `/home/kali` would show the editor actually working on the VM.
- In screenshot 04, `ms-python.python` was already installed. The batch also pulled in `remote-ssh-edit` and `remote-explorer` automatically, which is normal.

**5. Security.**
- **Host key:** the first SSH login accepted Kali's host key with a plain `yes` (screenshot 14), without comparing the fingerprint. On a host-only network that's a reasonable trade-off, but it's the step that stops a machine-in-the-middle. `ssh-keygen -lf` on Kali shows the real fingerprint to compare.
- **Default password:** with sshd now **enabled at boot** and the default `kali`/`kali` password, Kali is reachable on port 22 by anything on the host-only network, including the deliberately vulnerable Metasploitable2 VM from CYB 405. Production point 1 (key-only auth) fixes that; at minimum, change the default password.

**6. Housekeeping.**
- The Connection to Roadmap section gives the repo path as `.../vscode-guide/`; the folder is `lab-02_vscode-remote-ssh-setup/`.
- The original diagram (16) is cropped at the top edge; the reviewed diagram (17) is a full redraw.

## What I'd Change for Production

- **Password authentication is still enabled.** Logging in with `kali`/`kali` over SSH works for a lab, but production (or even a serious home lab) should switch to SSH key-based auth and disable password login entirely in `sshd_config`.
- **No single source of truth for VM IPs.** Two different lab networks (home-lab `192.168.1.x` and CYB 405 host-only `192.168.56.x`) caused a wasted troubleshooting step from a stale assumption. A simple inventory file (or DHCP reservations) would prevent that.
- **SSH not enabled by default on the VM image.** Rather than starting the service manually each time a fresh Kali VM is built, this should be baked into a provisioning script or the VM template itself.
- **Default Kali credentials in use.** Fine for an isolated host-only lab network with no external exposure, but should never be left as-is on anything internet-facing.

Added after the October 2026 review:

| Lab setup | Production reality |
|---|---|
| Global Git setting changed to work around one failure | Troubleshooting changes reverted once the cause is understood (Review Note 1) |
| Host key accepted with a bare `yes` | Fingerprints verified out-of-band, or distributed via config management / SSH certificates (Review Note 5) |
| Vague tool error investigated by hand | Tool logs checked first (`Remote-SSH: Show Log`), then a raw-protocol test (Review Note 3) |
| `~/.ssh/config` with only HostName and User | Per-host `IdentityFile`, `IdentitiesOnly yes`, and a jump host (`ProxyJump`) for anything not on the local network |

## Connection to Roadmap

This lab sits under **Phase 06 - Cloud Tech Techniques (CTT) - Cloud System Admin Accelerator** of the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap), the same track as the Terraform AD DC lab, specifically the **VSCode Guide** module under "How To Automate The VM Deployment." Repo path: `phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/vscode-guide/`.

Per the same completion-batching approach used elsewhere in Phase 06, this gets added to the live roadmap site once the full Cloud System Admin Accelerator course is complete, not module-by-module. It also directly supports CYB 405 lab execution going forward, since Remote-SSH into the Kali VM is now the working setup for that coursework too - though its primary home is this course track, not CYB 405.

Related labs:
- **[Lab 01 · Terraform AD DC](../lab-01_terraform-ad-dc)** - the provisioning side of the same course module
- **[Lab 03 · NTFS File Server](../lab-03_ntfs-file-server)** - the next lab, written and run from this editor setup

---

🌐 Full roadmap: [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)

🔗 All labs: [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

---

*CyberJKD - Becoming dangerous through fundamentals. 🔒*
