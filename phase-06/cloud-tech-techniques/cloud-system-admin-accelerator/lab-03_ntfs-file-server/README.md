# NTFS File Server Lab - Hardened Windows File Server on Azure

![Terraform](https://img.shields.io/badge/Terraform-v1.16.2-844FBA?style=flat-square&logo=terraform)
![Azure](https://img.shields.io/badge/Azure-centralus-0078D4?style=flat-square&logo=microsoftazure)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2022%20Datacenter-00A4EF?style=flat-square&logo=windows)
![Checkov](https://img.shields.io/badge/Checkov-31%20passed%20%2F%200%20failed-brightgreen?style=flat-square)
![Checkov repo](https://img.shields.io/badge/Checkov%20(repo%20as%20committed)-30%20passed%20%2F%201%20failed-D29922?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel (CyberJKD) |
| **Date** | September 21 - 24, 2026 |
| **Platform** | Microsoft Azure |
| **Course** | Cloud System Admin Accelerator - Cloud Tech Techniques |
| **Roadmap** | Phase 06 · Cloud Tech Techniques · Cloud System Admin Accelerator |

---

## Objective

Deploy a three-tier Windows file server environment (domain controller, file server, client workstation) entirely through Terraform, then take it past the standard lab spec: replace the shared test password with per-user Key Vault secrets, rebuild the NTFS permission model on the AGDLP pattern instead of granting global groups directly, hide shares from users with no access to them, add storage quotas and file-type screens, map network drives automatically by group membership, and turn on object-access auditing so denied attempts are logged, not just silently blocked.

## Business Problem

Every organization running Windows file shares needs the same three things: users only see and reach the data their role requires, that access is enforced by AD group membership rather than by hand-editing ACLs machine by machine, and someone can prove after the fact who tried to touch what. A file server with permissions granted straight to project groups gets the first part right and stops there — it doesn't scale cleanly across many resources, doesn't hide what people can't use, and doesn't leave an audit trail. This lab builds the full version: Account → Global group → Domain-Local group → Permission (AGDLP), Access-Based Enumeration so denied shares don't even appear, storage governance via FSRM, and Security-log auditing on every denied attempt.

| Role | How this applies |
|---|---|
| Systems / Azure Administrator | File shares, NTFS, AD groups, GPO and FSRM are day-one Windows admin work |
| Cloud Security Engineer | Least-privilege access, secrets in Key Vault, IaC scanning, audit trails |
| SOC Analyst | 4656 failure events and the KQL in `detection-query.md` are the detection side of this lab |
| IAM / Identity Engineer | AGDLP is the standard pattern for scalable, auditable group-based access |

## Environment

| Component | Value |
|---|---|
| Terraform | v1.16.2 |
| Azure CLI | current, `cyberjkd-labs` subscription |
| Region | `Central US` |
| VM Size | `Standard_D2s_v7` (see Troubleshooting Log #2 - `Standard_Basv2` had zero quota; `Standard_B2s` and `Standard_D2s_v3` weren't offered in this region for this subscription) |
| DC01 / FS01 | Windows Server 2022 Datacenter (Azure Edition), no public IP |
| CLIENT01 | Windows 11 Pro (`win11-25h2-pro` - see Troubleshooting Log #1), single public IP, locked to admin `/32` |
| Resource Group | `RG-FileServerLab` |
| Domain | `lab.local` (NetBIOS `LAB`) |
| Key Vault | `kv-fslab-xxxxxxxx`, RBAC-enabled, purge protection on |
| Log Analytics | `law-fslab`, 1 GB/day ingestion cap |

## Key Concepts

- **AGDLP** - Account into Global group, Global group nested into Domain-Local group, permission granted to the Domain-Local group. The textbook Windows permission pattern; scales past a handful of shares in a way that granting global groups directly does not.
- **Access-Based Enumeration (ABE)** - hides folders and shares a user has no access to, instead of showing them and returning Access Denied on open.
- **File Server Resource Manager (FSRM)** - storage quotas and file-type screens enforced at the file-server level, independent of NTFS permissions.
- **GPO logon scripts** - the reliable way to map network drives by group membership; Group Policy Preferences drive maps look simpler but depend on version-stamp metadata that hand-writing the preference XML into SYSVOL silently skips (see Troubleshooting Log #7).
- **Object-access auditing (SACL)** - a permission grants or denies access; a SACL is the separate setting that makes Windows *log* the attempt to the Security event log.
- **Infrastructure-as-Code hardening** - using a static analysis tool (Checkov) against the Terraform itself, not just the deployed resources, and documenting every exception in code rather than fixing or silently ignoring it.
- **Variable defaults decide the scan** *(added in review)* - Checkov evaluates the values Terraform would actually use, including a local `terraform.tfvars` if one is present. A safe value that lives only in a gitignored tfvars file means the scan on your machine and the scan on the repo can disagree - see [Review Note 1](#review-notes-october-2026).
- **Azure reserved addresses** *(added in review)* - Azure keeps the first four addresses of every subnet (`.0`-`.3`) for itself, so `.4` is the first address any dynamic NIC is given. That's the real reason DC01's static `10.0.1.4` collided - see [Review Note 6](#review-notes-october-2026).

## Architecture

![NTFS Lab Architecture](images/26-architecture-diagram.png)

```
Terraform (local)
   │
   ▼
Azure Subscription (cyberjkd-labs)
   └── RG-FileServerLab (Central US)
        ├── VNET-FileServerLab (10.0.0.0/16)
        │    └── Subnet-Servers (10.0.1.0/24) — NSG attached at subnet level
        │         ├── DC01   - 10.0.1.4 (static), no public IP
        │         ├── FS01   - dynamic private IP, no public IP
        │         └── CLIENT01 - dynamic private IP + public IP (RDP, locked to admin /32)
        ├── NAT Gateway - outbound internet for DC01 / FS01 (no public IP needed)
        ├── Key Vault (RBAC) - admin password + 5x per-user passwords
        ├── Log Analytics workspace - Data Collection Rule filters EventID 4656/4663/4660
        ├── Consumption Budget - $25/month, 80% and 100% email alerts
        └── Auto-shutdown schedules — all 3 VMs, 23:00 daily
```

DC01 runs Active Directory, DNS, Group Policy, and the AGDLP group structure. FS01 hosts the four SMB shares, their NTFS permissions, Access-Based Enumeration, FSRM quotas and file screens, and the audit SACLs. CLIENT01 is the domain-joined workstation the five test users log into to exercise the full permission chain.

## Exercises

### Phase A - Base Deployment and Terraform Hardening

**A. Pre-flight checks.** Windows 11's default VM image SKU (`win11-23h2-pro`) had been retired from the marketplace. Checked quota and regional availability across several VM families before picking a size rather than guessing size by size - `Standard_Basv2` came back at zero quota; `Standard_D2s_v3` and `Standard_B2s` were both ruled out next, not for quota but because neither was offered in this region for this subscription; `Standard_D2s_v7` had both quota and no restrictions, so that's what was used.

![Quota and SKU check](images/01-preflight-quota-and-sku-check.png)

**B. Terraform scaffold.** Six `.tf` files - `backend.tf`, `versions.tf`, `variables.tf`, `main.tf`, `keyvault.tf`, `outputs.tf` - plus the `scripts/` folder holding the eight PowerShell scripts the orchestration script pushes to the VMs. (`hardening.tf` was added later, in Phase A step H.)

![Terraform files created](images/02-terraform-files-created.png)

**C. Deploy.** `terraform init` → `terraform plan` (24 resources) → `terraform apply`. Hit a genuine race condition on the first attempt — Azure allocated DC01's intended static IP (`10.0.1.4`) to FS01's dynamic NIC because all three NICs were created in parallel with no ordering between them.

![Terraform plan summary](images/03-terraform-plan-summary.png)
![Subnet race condition error](images/04-error-subnet-race-condition.png)
![Apply retry after fix](images/05-apply-retry-after-race-fix.png)

**D. Run the orchestration script.** `configure-lab.ps1` pushes each stage to the right VM via `az vm run-command`, no manual RDP required for setup. First attempt blocked by the local PowerShell execution policy - a client-side setting, unrelated to the `Set-ExecutionPolicy` lines already inside each pushed script.

![Execution policy fix](images/06-execution-policy-fix.png)
![DC promotion success](images/07-dc-promotion-success.png)
![Full verification passed](images/08-verification-passed-lab-configured.png)

**E. Verify the base permission model (Step 9).** RDP'd in as each of the five test users and confirmed the SOP's intended access matrix - Finance/HR/Sales/IT shares, each with the correct read/write/full-control/denied combination per department.

![Lisa White - Finance read-only, write denied](images/09-lisa-white-finance-readonly-denied.png)
![Lisa White - HR write succeeds](images/10-lisa-white-hr-write-success.png)
![John Smith - IT full control](images/11-john-smith-it-full-control.png)
![John Smith - Finance full control](images/12-john-smith-finance-full-control.png)
![John Smith - HR, Security tab open](images/13-john-smith-hr-security-tab.png)
![Tom Davis - confirmed identity](images/14-tom-davis-startmenu-confirmed.png)
![Tom Davis - Finance denied](images/15-tom-davis-finance-denied.png)
![Tom Davis - HR denied](images/16-tom-davis-hr-denied.png)
![Tom Davis - Sales access granted](images/17-tom-davis-sales-access-granted.png)

**F. Baseline the NTFS permissions before hardening.** Ran `icacls` against all four shares to capture the "before" state - each share's ACL held only its own department's global group, plus SYSTEM and Administrators.

> [Review Note 5](#review-notes-october-2026): the captured baseline shows `GRP_IT` (Full) on every share and `GRP_HR` (Read) on Finance as well - only `IT` holds a single department group.

![icacls baseline, all shares](images/18-icacls-baseline-all-shares.png)

**G. Scan the Terraform with Checkov.** Baseline scan: **19 passed, 17 failed**. Ten failures were straightforward fixes (Key Vault purge protection, secret expiry and content type, encryption at host, moving the NSG to the subnet instead of per-NIC, removing public IPs from DC01/FS01). Seven were deliberate, documented exceptions - Key Vault network isolation would lock out a rotating home IP; the VM extensions are required for `run-command` automation and the monitoring agent; CLIENT01 keeps its single public IP as the one RDP entry point.

**H. Apply the hardening.** Rebuilding `main.tf` to drop the server public IPs and add a NAT gateway hit a genuine Terraform ordering problem: flipping the subnet's `default_outbound_access_enabled` flag forced a delete-and-recreate of the subnet, but the subnet couldn't be deleted while the NICs still referenced it, and the NIC updates that would detach them were scheduled *after* the new subnet - a dependency deadlock. Resolved by dropping that flag once the NAT gateway made it redundant, and splitting the public-IP removal into two separate applies so the NIC-detach step ran before the IP-delete step instead of racing it.

![Encryption at host feature registered](images/19-encryption-at-host-registered.png)
![Checkov after Key Vault fix](images/20-checkov-keyvault-fixed.png)
![Terraform validate and plan](images/21-terraform-validate-plan-quoted.png)
![Hardening apply - NSG and VM updates](images/22-hardening-apply-nsg-vm-updates.png)
![Checkov final - 31 passed, 0 failed, 7 skipped](images/23-checkov-31-0-7-final.png)
![Encryption at host plan confirmed](images/24-encryption-at-host-plan-confirmed.png)
![Final clean verification](images/25-final-verification-all-clean.png)

Final Checkov result: **31 passed, 0 failed, 7 skipped with a written reason on each.**

> [Review Note 1](#review-notes-october-2026): that result depends on the local, gitignored `terraform.tfvars`. Scanning the repo exactly as committed gives **30 passed / 1 failed** (`CKV_AZURE_9` - RDP open to the internet).

### Phase B - Active Directory and File Server Hardening

> [Review Note 2](#review-notes-october-2026): the scripts in this folder are the Phase A versions, and Phase B (steps I-O) has no committed scripts or screenshots - its evidence is the text below and the captured event in [`detection-query.md`](detection-query.md).

**I. Per-user passwords.** Replaced the SOP's single shared test password with five independently generated 18-character random passwords, one per user, stored only in Key Vault - nothing hardcoded in any script from this point forward.

**J. AGDLP.** Created five domain-local groups (`DL_Finance_Modify`, `DL_Finance_Read`, `DL_HR_Modify`, `DL_Sales_Modify`, `DL_IT_FullControl`), nested the existing global groups into them, then re-pointed every share's NTFS ACL from the global groups onto the domain-local groups. Verified via `gpresult /r` that a user's token correctly carries both the global and domain-local group membership.

**K. Access-Based Enumeration.** Turned on `FolderEnumerationMode: AccessBased` on all four shares - confirmed via `Get-SmbShare`. A user with no access to a share no longer sees it in the browse list at all.

**L. FSRM.** 5 GB quota on each of the four shares, plus a file screen on Finance and HR blocking executable file types (`.exe`, `.bat`, `.cmd`, `.ps1`, `.vbs`).

**M. GPO drive mapping.** First attempt used Group Policy Preferences drive maps, hand-written directly into SYSVOL - `gpresult` showed the GPO as "Applied," but the drive never mapped. Root cause: GPP requires the GPO's `GPT.INI` version stamp and AD `versionNumber` attribute to be bumped, which only happens automatically through the GPMC editor; writing the XML by hand skipped that step. Switched to a GPO-deployed logon script (`net use`, gated by `whoami /groups`) instead - the older, more universally reliable mechanism. Confirmed working: `F:` mapped to `\\FS01\Finance` for a Finance-group user.

**N. Object-access auditing.** Enabled File System object-access auditing (Success and Failure) and added a SACL to all four shares. Confirmed the pipeline works by testing Tom Davis's denied Finance attempt and pulling the actual event directly from the Security log with `Get-WinEvent` — `Account Name: tom.davis`, `Object Name: C:\Shares\Finance`, `ReadData (or ListDirectory): Not granted`.

**O. Log Analytics shipping - partial.** Installed the Azure Monitor Agent extension on FS01 (reported `provisioningState: Succeeded`) and created a Data Collection Rule filtering EventID 4656/4663/4660 to the workspace. The extension's success report did not reflect reality: the agent's Windows service never actually registered on FS01 (`Get-Service` found no Azure Monitor Agent service at all), so no event ever shipped to Log Analytics. The underlying audit event is real and captured directly from the Security log (step N); the Azure-side ingestion is a documented, unresolved gap - see What I'd Change for Production.

## Terraform Configuration

The working `.tf` files are in [`terraform/`](terraform/) - `backend.tf`, `versions.tf`, `variables.tf`, `main.tf`, `keyvault.tf`, `hardening.tf`, `outputs.tf`. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your own values - don't retype from the screenshots above. The Checkov reports (`checkov-baseline.txt`, `checkov-after.txt`, `checkov-final.txt`) and the pre-hardening `icacls-baseline.txt` are included in the same folder as evidence.

*Added in review:* Phase B evidence lives alongside - [`dcr-payload.json`](dcr-payload.json) (the Data Collection Rule used in step O), [`evidence/`](evidence/) (Azure-side state captured 21 Oct 2026) and [`collect-phaseb-evidence.ps1`](collect-phaseb-evidence.ps1), the read-only script that captured it. See Review Notes 2 and 4.

## Command Reference

```powershell
# Deploy
terraform init
terraform plan
terraform apply
.\configure-lab.ps1 -KeyVaultName "kv-fslab-xxxxxxxx"

# Verify base permissions (per user)
whoami
Get-PSDrive -PSProvider FileSystem

# AGDLP verification
gpresult /r /scope:user

# ABE verification
Get-SmbShare | Select-Object Name, FolderEnumerationMode

# FSRM verification
Get-FsrmQuota
Get-FsrmFileScreen

# Audit event lookup (fallback when Log Analytics ingestion is broken)
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4656,4663; StartTime=(Get-Date).AddHours(-2)} |
  Where-Object { $_.Message -match 'tom.davis' } | Select-Object TimeCreated, Id, Message

# Cost control - pause between sessions
az vm deallocate -g RG-FileServerLab -n CLIENT01 --no-wait
az vm deallocate -g RG-FileServerLab -n FS01 --no-wait
az vm deallocate -g RG-FileServerLab -n DC01 --no-wait

# Teardown (only after Lab 2 / RBAC lab, which depends on FS01, is also done)
terraform destroy
```

**Added in review:**

| Command | Purpose |
|---|---|
| `checkov -d terraform/ --compact` (in a clean clone, no tfvars) | What the repo scans as on anyone else's machine (Review Note 1) |
| `az vm list-usage -l centralus -o table \| Select-String asv2` | Quota check that avoids PowerShell's JMESPath quoting trap (screenshot 01) |
| `az vm identity assign -g RG-FileServerLab -n FS01` | Give FS01 the managed identity the Azure Monitor Agent requires (Review Note 4) |
| `Get-Service *Monitor*` | Look for the agent service by wildcard rather than one exact display name |
| `icacls C:\Shares\Finance` | Prove the post-AGDLP ACL references only `DL_*` groups (Review Note 2) |
| `Get-SmbShare \| Select Name, FolderEnumerationMode` · `Get-FsrmQuota` · `Get-FsrmFileScreen` | Screenshots worth committing as Phase B evidence |
| `$script.Replace('ADMIN_PASSWORD', $value)` | Literal placeholder substitution - the fix for Review Note 3 |
| `Get-ADObject "CN={GPO-GUID},CN=Policies,CN=System,DC=lab,DC=local" -Properties gPCUserExtensionNames, versionNumber` | Inspect the attributes that decide whether a GPP extension runs (Review Note 7) |

## Verification Checklist

- [x] `terraform apply` completes with 0 errors (post subnet-race fix)
- [x] Checkov: 31 passed / 0 failed / 7 documented exceptions
- [x] All 5 test users' base access matches the SOP's intended design (Step 9)
- [x] `icacls` baseline captured pre-hardening
- [x] 5x per-user passwords rotated into Key Vault; no shared credential remains anywhere
- [x] AGDLP: `gpresult` confirms domain-local group membership on user tokens; `icacls` confirms ACLs reference only `DL_*` groups
- [x] Access-Based Enumeration: `AccessBased` confirmed on all 4 shares
- [x] FSRM: 4x 5 GB quotas active; 2x executable file screens active on Finance/HR
- [x] GPO logon script confirmed mapping `F:` to `\\FS01\Finance` for a Finance-group user
- [x] Audit policy + SACL confirmed logging Tom Davis's denied Finance access (4656, `Not granted`)
- [ ] Log Analytics ingestion — Data Collection Rule created and associated, but the Azure Monitor Agent service never registered on FS01; no event shipped. **Known, documented gap** — see below.
- [ ] Checkov clean on the repo as committed: **no - 30 passed / 1 failed without the local tfvars, see Review Note 1**
- [ ] Phase B changes (per-user passwords, AGDLP, ABE, FSRM, logon script, SACL) committed as code: **no - see Review Note 2**
- [x] Per-user passwords exist in Key Vault - five `user-*-password` secrets, confirmed from Azure on 21 Oct 2026 ([evidence](evidence/01-azure-keyvault-identity-dcr.txt))
- [x] Root cause of the Log Analytics gap identified - FS01 has no managed identity ([evidence](evidence/01-azure-keyvault-identity-dcr.txt), Review Note 4)
- [ ] Orchestration script safe for any password: **no - placeholder substitution corrupts several special characters, see Review Note 3**

## Troubleshooting Log

**1. `win11-23h2-pro` retired from the marketplace.** The Windows 11 image SKU used by earlier labs in this series was no longer offered. Checked the current SKU list (`az vm image list-skus`) and switched to `win11-25h2-pro`.

**2. `Standard_Basv2` at zero quota; `Standard_D2s_v3` and `Standard_B2s` not offered in this region.** The Basv2 family (which covers the SOP's default `Standard_B2as_v2`) returned an actual `0` quota limit for this subscription. The next two candidates, `Standard_D2s_v3` and `Standard_B2s`, weren't a quota problem at all - `az vm list-skus --size <name>` returned nothing for either, meaning Azure doesn't offer them in this region for this subscription. Pulled the full quota table (`az vm list-usage`) and cross-checked against `az vm list-skus -o table` for a size with both known quota and no `Restrictions` flag - landed on `Standard_D2s_v7`.

**3. Subnet IP race condition.** All three NICs were created in parallel with no explicit ordering, so Azure handed DC01's intended static address (`10.0.1.4`) to FS01's dynamic NIC. Fixed by adding an explicit `depends_on` from the dynamic NICs to DC01's NIC, then destroying and recreating just the pieces that had grabbed the wrong address.

**4. PowerShell execution policy blocked the orchestration script.** `configure-lab.ps1` failed to run locally with "running scripts is disabled on this system" - a client-side policy on the operator's own machine, separate from the `Set-ExecutionPolicy` calls already inside each script that gets pushed to the VMs. Fixed with `Set-ExecutionPolicy -Scope Process -Force` in the local session.

**5. Subnet replacement deadlock during hardening.** Setting `default_outbound_access_enabled = false` on the subnet forces Terraform to delete and recreate it in place, but the existing NICs still referenced the old subnet, and the plan tried to destroy the subnet *before* those NICs were updated to detach - a dependency cycle Terraform couldn't resolve on its own. Resolved by removing that setting once the NAT gateway (added separately) made the subnet-level flag redundant for outbound connectivity.

**6. Public IP deletion raced against NIC detachment.** Even after fixing #5, a single `terraform apply` tried to delete `dc01-pip`/`fs01-pip` in the same operation as detaching them from their NICs, and Azure rejected the delete because the NIC still held a reference at that instant. Split into two applies: detach first (`-target` on the two NICs), then a full apply to handle the rest.

**7. GPO drive maps silently no-opped.** Group Policy Preferences drive-map XML, written directly into SYSVOL by hand, showed the GPO as "Applied" in `gpresult` but never actually mapped a drive. Root cause: GPP relies on the GPO's `GPT.INI` version number and the AD object's `versionNumber` attribute to signal that new preference content exists; both are normally bumped automatically by the GPMC editor, and hand-writing the XML skipped that step entirely. After two attempts to fix the version stamps directly, switched to a GPO-deployed logon script instead, which has no such dependency and worked immediately.

**8. Azure Monitor Agent extension reported success without actually installing.** `az vm extension set` for `AzureMonitorWindowsAgent` returned `provisioningState: Succeeded`, but `Get-Service` on FS01 found no matching service at all. The extension deployment and the in-guest service registration are evidently not the same guarantee. Confirmed the underlying audit data was real by pulling it directly from the Windows Security log instead of relying on the broken shipping path.

**9. Data Collection Rule schema - `Microsoft-SecurityEvent` table unavailable.** The DCR initially targeted the `Microsoft-SecurityEvent` stream, which requires the destination workspace to already have Sentinel or the Security Events connector enabled - a brand-new workspace doesn't have that table. Switched the stream to `Microsoft-Event` (the generic Windows Event Log stream, always available), which would have written to the standard `Event` table had the agent actually been running (see #8).

## Review Notes (October 2026)

I came back to this lab and checked it four ways: every screenshot, a **Checkov 3.3.30** scan of `terraform/` in a fresh clone, the orchestration logic run under **PowerShell 7.4**, and Microsoft's documentation for the Azure Monitor Agent. This is the strongest lab in the repo. The design choices hold up (AGDLP, ABE, FSRM, SACLs, Key Vault, remote state, inline-documented Checkov exceptions, the admin password passed as an environment variable in screenshot 23), and the Troubleshooting Log is honest and specific. The notes are about the gap between what the README says and what someone cloning the repo would actually get.

**1. Checkov's 31/0 depends on a file that isn't in the repo.** `variables.tf` gives `rdp_source` a default of `"*"`. On my machine a scan of the committed `terraform/` folder returns **30 passed / 1 failed / 7 skipped**, failing `CKV_AZURE_9` (RDP open to the internet). Adding a `terraform.tfvars` with a `/32` reproduces the README's **31 / 0 / 7** exactly. So the screenshots are genuine, but the safe value lives in the gitignored tfvars (screenshot 20 shows it being written), and anyone who runs this without one gets RDP open to `*`. The fix belongs in `variables.tf`:
- remove the default, so the variable becomes required;
- add a `validation` block that rejects `"*"` and `0.0.0.0/0`.

**2. The committed scripts are the Phase A versions - Phase B isn't in the repo.** Phase B says "nothing hardcoded in any script from this point forward", and the checklist says "no shared credential remains anywhere". But:
- `scripts/01-create-ad-users-groups.ps1` still creates all five users with `P@ssw0rd123!` and `-PasswordNeverExpires $true`;
- `configure-lab.ps1` ends by printing `LAB\sarah.jones Password: P@ssw0rd123!`.

No script for steps I-O (Key Vault per-user passwords, the `DL_*` groups and re-pointed ACLs, ABE, FSRM, the logon-script GPO, the SACLs) is committed, and none of the 26 screenshots shows them. The only Phase B evidence is the text and the `Get-WinEvent` output in `detection-query.md`. If the rotation happened as described, `P@ssw0rd123!` no longer works on these accounts, but a rebuild from this repo recreates it. Committing the Phase B scripts, plus `icacls` showing only `DL_*` groups, `Get-SmbShare` showing `AccessBased`, and `Get-FsrmQuota`, would make the strongest part of the lab provable.

*Update - evidence collected 21 October 2026.* My laptop's working folder confirmed no Phase B scripts were ever saved: steps I-O were run interactively. So instead of writing scripts after the fact, I added a read-only collector, [`collect-phaseb-evidence.ps1`](collect-phaseb-evidence.ps1), and ran it against the live environment. By then the Azure subscription had been **disabled (read-only)**, so DC01 and FS01 could no longer be started, but the Azure-side metadata could still be read ([`evidence/01-azure-keyvault-identity-dcr.txt`](evidence/01-azure-keyvault-identity-dcr.txt)). It proves part of the claim:
- **Step I is confirmed.** The vault holds `user-john-smith-password`, `user-lisa-white-password`, `user-mike-brown-password`, `user-sarah-jones-password` and `user-tom-davis-password` next to `vm-admin-password` - five per-user secrets, as described. They were created outside Terraform, so unlike `vm-admin-password` they have no expiry date or content type (the two Key Vault checks Checkov enforced on the Terraform-managed secret).
- **Step O's configuration is committed** as [`dcr-payload.json`](dcr-payload.json), the Data Collection Rule actually used - `Microsoft-Event` stream, XPath filter on 4656/4663/4660, destination `law-fslab`.
- **Steps J-N** (AGDLP, ABE, FSRM, logon-script GPO, SACLs) remain described but unproven from the repo; the collector's DC01 and FS01 sections would capture them if the subscription is re-enabled.

**3. The password substitution in `configure-lab.ps1` corrupts some passwords.** `Invoke-VMScript` does `$script -replace $key, [regex]::Escape($value)`. `[regex]::Escape` adds backslashes, but the *replacement* side of `-replace` isn't a regex, so those backslashes land in the pushed script literally - inside a double-quoted string, where PowerShell also expands `$`. Tested under PowerShell 7.4 with the exact logic:

| Password | What the VM receives | Result |
|---|---|---|
| `Cyberjkd2026!Lab` | `Cyberjkd2026!Lab` | OK |
| `My.Pass#2026` | `My\.Pass\#2026` | Mismatch |
| `Pa$sword2026!` | `Pa\!` | Mismatch |
| `Tab(1)+Sun` | `Tab\(1\)\+Sun` | Mismatch |

Passwords with only letters, digits and `!` survive, which is why this run worked. With `.` `#` `(` `)` `+` `$` and similar characters, `00-promote-dc.ps1` would silently set a **different DSRM password** from the one in Key Vault, and the domain join would fail. The fix is two changes:
- literal replacement (`$script.Replace($key, $value)`);
- single-quoted placeholders in the templates.

Passing values with `az vm run-command invoke --parameters` avoids string surgery altogether.

**4. The Azure Monitor Agent gap has a likely cause: no managed identity.** Microsoft's [AMA requirements](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-requirements) state that a managed identity "must be enabled on Azure virtual machines". None of the three `azurerm_windows_virtual_machine` resources has an `identity` block, and the agent was added later with `az vm extension set`. Unless an identity was assigned separately, that alone stops any data reaching `law-fslab`. It's the first thing to check before calling the extension's success report false. It's also worth searching with a wildcard (`Get-Service *Monitor*`) rather than one exact display name. The README's "documented, unresolved gap" framing is the right call either way.

*Update - confirmed 21 October 2026.* The [evidence file](evidence/01-azure-keyvault-identity-dcr.txt) shows FS01's `identity` is **empty** (no system- or user-assigned managed identity), while the `AzureMonitorWindowsAgent` extension (v1.45) reports `Succeeded`. That matches the symptom exactly: the extension installs, but the agent has no identity to authenticate to the Data Collection Rule and workspace with, so nothing ships. The fix is `az vm identity assign -g RG-FileServerLab -n FS01` - or, better, an `identity { type = "SystemAssigned" }` block on each VM in `main.tf`, with the agent, DCR and association moved into Terraform.

**5. The baseline text doesn't match the captured baseline.** Step F says each share's ACL "held only its own department's global group". `terraform/icacls-baseline.txt` and screenshot 18 show:
- `GRP_IT` with Full Control on **all four** shares;
- `GRP_Finance` (Modify) **and** `GRP_HR` (Read) on Finance.

That's exactly what `02-configure-shares-and-permissions.ps1` sets, and it matches the access matrix (Lisa White reading Finance, John Smith with Full Control everywhere). Only `IT` fits the sentence.

**6. The NIC race has a more exact root cause.** Azure reserves the first four addresses of a subnet, so `.4` is the first address a dynamic NIC is handed. Putting DC01's *static* IP at `10.0.1.4` guarantees a collision whenever FS01 or CLIENT01 wins the race (screenshot 04: `PrivateIPAddressIsAllocated`). The `depends_on` fix works. Two options are more robust:
- give DC01 an address clear of the dynamic start, e.g. `10.0.1.10`;
- make all three IPs static.

**7. GPP drive maps: the missing piece was very likely the extension list, not only the version.** The Group Policy client only runs the client-side extensions listed in a GPO's `gPCUserExtensionNames` attribute. GPMC adds the Drive Maps extension's GUID there when you create a drive map. Hand-writing `Drives.xml` into SYSVOL doesn't, so even correct version stamps wouldn't make the drive-maps extension run, which fits "two attempts to fix the version stamps" failing. The logon-script fallback was a sound decision; this just explains it.

**8. `detection-query.md`: event 4663 never carries "Not granted".** Microsoft documents 4663 ("An attempt was made to access an object") as a **success-only** event, while 4656 ("A handle to an object was requested") covers both success and failure - which is why the captured denial is a 4656. Including 4663 in the "Not granted" queries is harmless but never matches, and Query 3's count is 4656-only in practice. The note on 4660 already shows the right instinct.

**9. Same secret everywhere.** `var.admin_password` is the local admin on all three VMs, becomes the domain administrator when DC01 is promoted, and is reused as the DSRM password (`SAFE_MODE_PASSWORD` is replaced with the admin password). One leaked value unlocks every tier. A separate DSRM secret in Key Vault and distinct local-admin passwords (LAPS) split that.

**10. Housekeeping.**
- **Screenshot 01** ("Quota and SKU check") shows the `az vm list-usage --query` command failing four times on PowerShell quoting (`].{n:name.value was unexpected`) - no quota table appears. The SKU findings in Troubleshooting #2 aren't shown.
- **Screenshot 13** ("HR, Security tab open") shows the General tab.
- **Screenshot 20** ("Checkov after Key Vault fix") shows `terraform.tfvars` being rewritten with `rdp_source` and `alert_email`.
- **Screenshots 21 and 22** both show the same 27 / 7 / 4 Checkov run and a `terraform plan` error ("Too many command line arguments" - the unquoted `-out` in PowerShell); neither is the hardening apply its caption describes. Screenshot 23 shows the quoted fix.
- **The Checkov `.txt` reports are UTF-16** (Windows PowerShell's `Tee-Object` default), so GitHub can't display them as text; `checkov-after.txt` and `checkov-final.txt` are identical.
- **Diagram 26** lists "5x global groups" - there are four (`GRP_Finance`, `GRP_HR`, `GRP_Sales`, `GRP_IT`). It also shows drive letters `F:/H:/S:/I:`, while only `F:` is confirmed.
- **DNS:** `04-domain-join.ps1` sets DNS to `10.0.1.4` inside each guest. Setting the VNet's `dns_servers` to DC01 in Terraform is the Azure-native way, and it survives redeploys.
- **`.terraform.lock.hcl` is gitignored** - Terraform recommends committing it to pin provider versions.

## What I'd Change for Production

- **Fix or replace the Log Analytics shipping path.** The AMA extension's false-success report is the one unresolved gap in this lab. Production would need to actually validate the in-guest service state post-deployment (not just trust the ARM provisioning state), or fall back to a Windows Event Forwarding subscription as a more transparent alternative.
- **Azure Bastion instead of a public IP on CLIENT01.** The lab still exposes one RDP entry point, locked to a single `/32`, but a home IP that rotates as often as this one did means re-touching the NSG rule constantly. Bastion removes the public IP and the rotating-IP maintenance entirely.
- **Per-user Key Vault access policies**, not one shared deployer identity with `Key Vault Secrets Officer` on the whole vault. Production would scope each service or operator to only the secrets it actually needs.
- **GPO drive maps done through GPMC**, not hand-authored SYSVOL XML - the logon-script fallback works, but a real Windows environment should just use the tooling as intended, which sidesteps the version-stamp trap entirely.
- **Enable Microsoft Sentinel** once the ingestion path is fixed, and build the actual KQL detection rule as an alert, not just a query run manually after the fact.
- **A NAT gateway is a recurring cost** worth toggling off between sessions on a lab subscription; production would size it against real egress volume rather than leaving it always-on by default.

Added after the October 2026 review:

| Lab setup | Production reality |
|---|---|
| Safe `rdp_source` only in a gitignored tfvars | Required variable with a `validation` block; Checkov run in CI against the repo itself (Review Note 1) |
| Hardening done by hand after the scripted build | Every change committed as code, so a rebuild reproduces the hardened state (Review Note 2) |
| Passwords spliced into script text | Values passed as run-command parameters or read from Key Vault on the VM via managed identity (Review Note 3) |
| VMs without managed identities | System-assigned identity on every VM; AMA, DCR and association defined in Terraform (Review Note 4) |
| One admin password for local admin, domain admin and DSRM | Separate secrets per role; Windows LAPS for local admin accounts (Review Note 9) |
| DC static IP at the first address of the subnet | Reserved static range for infrastructure, dynamic range for clients (Review Note 6) |

## Connection to Roadmap

This lab sits under **Phase 06 - Cloud Tech Techniques - Cloud System Admin Accelerator** of the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap). Repo path: `phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/lab-03_ntfs-file-server/`.

Per the same completion-batching approach used elsewhere in this series, Phase 06 is added to the live roadmap site once the full Cloud System Admin Accelerator course is complete, not lab-by-lab.

Related labs:
- **[Lab 01 · Terraform AD DC](../lab-01_terraform-ad-dc)** - the single-DC build this lab extends; several of its Checkov findings are fixed here
- **[Lab 02 · VS Code Remote-SSH](../lab-02_vscode-remote-ssh-setup)** - the editor setup this lab was written in
- **[Phase 03 · Active Directory on Azure](../../../../phase-03/project-02-active-directory)** - the same OU / group / GPO concepts done by hand
- **[Phase 02 · Splunk SIEM](../../../../phase-02/project-01-splunk-siem-lab)** - the log-to-detection pattern `detection-query.md` applies to file access

---

🌐 Full roadmap: [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)

🔗 All labs: [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

---

*CyberJKD - Becoming dangerous through fundamentals. 🔒*
