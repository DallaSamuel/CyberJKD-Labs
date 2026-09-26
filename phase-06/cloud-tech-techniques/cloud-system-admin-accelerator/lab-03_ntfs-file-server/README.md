# NTFS File Server Lab — Hardened Windows File Server on Azure

![Terraform](https://img.shields.io/badge/Terraform-v1.16.2-844FBA?style=flat-square&logo=terraform)
![Azure](https://img.shields.io/badge/Azure-centralus-0078D4?style=flat-square&logo=microsoftazure)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2022%20Datacenter-00A4EF?style=flat-square&logo=windows)
![Checkov](https://img.shields.io/badge/Checkov-31%20passed%20%2F%200%20failed-brightgreen?style=flat-square)
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

Every organization running Windows file shares needs the same three things: users only see and reach the data their role requires, that access is enforced by AD group membership rather than by hand-editing ACLs machine by machine, and someone can prove after the fact who tried to touch what. A file server with permissions granted straight to project groups gets the first part right and stops there - it doesn't scale cleanly across many resources, doesn't hide what people can't use, and doesn't leave an audit trail. This lab builds the full version: Account → Global group → Domain-Local group → Permission (AGDLP), Access-Based Enumeration so denied shares don't even appear, storage governance via FSRM, and Security-log auditing on every denied attempt.

## Environment

| Component | Value |
|---|---|
| Terraform | v1.16.2 |
| Azure CLI | current, `cyberjkd-labs` subscription |
| Region | `Central US` |
| VM Size | `Standard_D2s_v7` (see Troubleshooting Log #2 - B-series and Basv2 had zero quota) |
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
        └── Auto-shutdown schedules - all 3 VMs, 23:00 daily
```

DC01 runs Active Directory, DNS, Group Policy, and the AGDLP group structure. FS01 hosts the four SMB shares, their NTFS permissions, Access-Based Enumeration, FSRM quotas and file screens, and the audit SACLs. CLIENT01 is the domain-joined workstation the five test users log into to exercise the full permission chain.

## Exercises

### Phase A - Base Deployment and Terraform Hardening

**A. Pre-flight checks.** Windows 11's default VM image SKU (`win11-23h2-pro`) had been retired from the marketplace. Checked quota across every VM family before picking a size rather than guessing size by size - `Standard_Basv2` came back at zero, and the next candidate, `Standard_B2s`, turned out to be zero too, both ruled out before settling on `Standard_D2s_v7`.

![Quota and SKU check](images/01-preflight-quota-and-sku-check.png)

**B. Terraform scaffold.** Six `.tf` files - `backend.tf`, `versions.tf`, `variables.tf`, `main.tf`, `keyvault.tf`, `outputs.tf` - plus the `scripts/` folder holding the eight PowerShell scripts the orchestration script pushes to the VMs. (`hardening.tf` was added later, in Phase A step H.)

![Terraform files created](images/02-terraform-files-created.png)

**C. Deploy.** `terraform init` → `terraform plan` (24 resources) → `terraform apply`. Hit a genuine race condition on the first attempt - Azure allocated DC01's intended static IP (`10.0.1.4`) to FS01's dynamic NIC because all three NICs were created in parallel with no ordering between them.

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

### Phase B - Active Directory and File Server Hardening

**I. Per-user passwords.** Replaced the SOP's single shared test password with five independently generated 18-character random passwords, one per user, stored only in Key Vault - nothing hardcoded in any script from this point forward.

**J. AGDLP.** Created five domain-local groups (`DL_Finance_Modify`, `DL_Finance_Read`, `DL_HR_Modify`, `DL_Sales_Modify`, `DL_IT_FullControl`), nested the existing global groups into them, then re-pointed every share's NTFS ACL from the global groups onto the domain-local groups. Verified via `gpresult /r` that a user's token correctly carries both the global and domain-local group membership.

**K. Access-Based Enumeration.** Turned on `FolderEnumerationMode: AccessBased` on all four shares - confirmed via `Get-SmbShare`. A user with no access to a share no longer sees it in the browse list at all.

**L. FSRM.** 5 GB quota on each of the four shares, plus a file screen on Finance and HR blocking executable file types (`.exe`, `.bat`, `.cmd`, `.ps1`, `.vbs`).

**M. GPO drive mapping.** First attempt used Group Policy Preferences drive maps, hand-written directly into SYSVOL - `gpresult` showed the GPO as "Applied," but the drive never mapped. Root cause: GPP requires the GPO's `GPT.INI` version stamp and AD `versionNumber` attribute to be bumped, which only happens automatically through the GPMC editor; writing the XML by hand skipped that step. Switched to a GPO-deployed logon script (`net use`, gated by `whoami /groups`) instead - the older, more universally reliable mechanism. Confirmed working: `F:` mapped to `\\FS01\Finance` for a Finance-group user.

**N. Object-access auditing.** Enabled File System object-access auditing (Success and Failure) and added a SACL to all four shares. Confirmed the pipeline works by testing Tom Davis's denied Finance attempt and pulling the actual event directly from the Security log with `Get-WinEvent` - `Account Name: tom.davis`, `Object Name: C:\Shares\Finance`, `ReadData (or ListDirectory): Not granted`.

**O. Log Analytics shipping - partial.** Installed the Azure Monitor Agent extension on FS01 (reported `provisioningState: Succeeded`) and created a Data Collection Rule filtering EventID 4656/4663/4660 to the workspace. The extension's success report did not reflect reality: the agent's Windows service never actually registered on FS01 (`Get-Service` found no Azure Monitor Agent service at all), so no event ever shipped to Log Analytics. The underlying audit event is real and captured directly from the Security log (step N); the Azure-side ingestion is a documented, unresolved gap - see What I'd Change for Production.

## Terraform Configuration

The working `.tf` files are in [`terraform/`](terraform/) - `backend.tf`, `versions.tf`, `variables.tf`, `main.tf`, `keyvault.tf`, `hardening.tf`, `outputs.tf`. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your own values — don't retype from the screenshots above. The Checkov reports (`checkov-baseline.txt`, `checkov-after.txt`, `checkov-final.txt`) and the pre-hardening `icacls-baseline.txt` are included in the same folder as evidence.

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

# Cost control — pause between sessions
az vm deallocate -g RG-FileServerLab -n CLIENT01 --no-wait
az vm deallocate -g RG-FileServerLab -n FS01 --no-wait
az vm deallocate -g RG-FileServerLab -n DC01 --no-wait

# Teardown (only after Lab 2 / RBAC lab, which depends on FS01, is also done)
terraform destroy
```

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

## Troubleshooting Log

**1. `win11-23h2-pro` retired from the marketplace.** The Windows 11 image SKU used by earlier labs in this series was no longer offered. Checked the current SKU list (`az vm image list-skus`) and switched to `win11-25h2-pro`.

**2. Zero quota on `Standard_B2as_v2` and `Standard_B2s`.** Both returned a 0 limit for this subscription in Central US. Rather than guess further, pulled the full quota table (`az vm list-usage`) and cross-checked against `az vm list-skus --size <name> -o table` for a size with both known quota and no `Restrictions` flag - landed on `Standard_D2s_v7`.

**3. Subnet IP race condition.** All three NICs were created in parallel with no explicit ordering, so Azure handed DC01's intended static address (`10.0.1.4`) to FS01's dynamic NIC. Fixed by adding an explicit `depends_on` from the dynamic NICs to DC01's NIC, then destroying and recreating just the pieces that had grabbed the wrong address.

**4. PowerShell execution policy blocked the orchestration script.** `configure-lab.ps1` failed to run locally with "running scripts is disabled on this system" - a client-side policy on the operator's own machine, separate from the `Set-ExecutionPolicy` calls already inside each script that gets pushed to the VMs. Fixed with `Set-ExecutionPolicy -Scope Process -Force` in the local session.

**5. Subnet replacement deadlock during hardening.** Setting `default_outbound_access_enabled = false` on the subnet forces Terraform to delete and recreate it in place, but the existing NICs still referenced the old subnet, and the plan tried to destroy the subnet *before* those NICs were updated to detach - a dependency cycle Terraform couldn't resolve on its own. Resolved by removing that setting once the NAT gateway (added separately) made the subnet-level flag redundant for outbound connectivity.

**6. Public IP deletion raced against NIC detachment.** Even after fixing #5, a single `terraform apply` tried to delete `dc01-pip`/`fs01-pip` in the same operation as detaching them from their NICs, and Azure rejected the delete because the NIC still held a reference at that instant. Split into two applies: detach first (`-target` on the two NICs), then a full apply to handle the rest.

**7. GPO drive maps silently no-opped.** Group Policy Preferences drive-map XML, written directly into SYSVOL by hand, showed the GPO as "Applied" in `gpresult` but never actually mapped a drive. Root cause: GPP relies on the GPO's `GPT.INI` version number and the AD object's `versionNumber` attribute to signal that new preference content exists; both are normally bumped automatically by the GPMC editor, and hand-writing the XML skipped that step entirely. After two attempts to fix the version stamps directly, switched to a GPO-deployed logon script instead, which has no such dependency and worked immediately.

**8. Azure Monitor Agent extension reported success without actually installing.** `az vm extension set` for `AzureMonitorWindowsAgent` returned `provisioningState: Succeeded`, but `Get-Service` on FS01 found no matching service at all. The extension deployment and the in-guest service registration are evidently not the same guarantee. Confirmed the underlying audit data was real by pulling it directly from the Windows Security log instead of relying on the broken shipping path.

**9. Data Collection Rule schema - `Microsoft-SecurityEvent` table unavailable.** The DCR initially targeted the `Microsoft-SecurityEvent` stream, which requires the destination workspace to already have Sentinel or the Security Events connector enabled - a brand-new workspace doesn't have that table. Switched the stream to `Microsoft-Event` (the generic Windows Event Log stream, always available), which would have written to the standard `Event` table had the agent actually been running (see #8).

## What I'd Change for Production

- **Fix or replace the Log Analytics shipping path.** The AMA extension's false-success report is the one unresolved gap in this lab. Production would need to actually validate the in-guest service state post-deployment (not just trust the ARM provisioning state), or fall back to a Windows Event Forwarding subscription as a more transparent alternative.
- **Azure Bastion instead of a public IP on CLIENT01.** The lab still exposes one RDP entry point, locked to a single `/32`, but a home IP that rotates as often as this one did means re-touching the NSG rule constantly. Bastion removes the public IP and the rotating-IP maintenance entirely.
- **Per-user Key Vault access policies**, not one shared deployer identity with `Key Vault Secrets Officer` on the whole vault. Production would scope each service or operator to only the secrets it actually needs.
- **GPO drive maps done through GPMC**, not hand-authored SYSVOL XML - the logon-script fallback works, but a real Windows environment should just use the tooling as intended, which sidesteps the version-stamp trap entirely.
- **Enable Microsoft Sentinel** once the ingestion path is fixed, and build the actual KQL detection rule as an alert, not just a query run manually after the fact.
- **A NAT gateway is a recurring cost** worth toggling off between sessions on a lab subscription; production would size it against real egress volume rather than leaving it always-on by default.

## Connection to Roadmap

This lab sits under **Phase 06 - Cloud Tech Techniques - Cloud System Admin Accelerator** of the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap). Repo path: `phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/lab-03_ntfs-file-server/`.

Per the same completion-batching approach used elsewhere in this series, Phase 06 is added to the live roadmap site once the full Cloud System Admin Accelerator course is complete, not lab-by-lab.

---

🌐 Full roadmap: [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)

🔗 All labs: [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

---

*CyberJKD - Becoming dangerous through fundamentals. 🔒*
