# Azure Active Directory Domain Controller - Terraform Deployment

![Terraform](https://img.shields.io/badge/Terraform-v1.16.2-844FBA?style=flat-square&logo=terraform)
![Azure](https://img.shields.io/badge/Azure-eastus2-0078D4?style=flat-square&logo=microsoftazure)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2022%20Datacenter-00A4EF?style=flat-square&logo=windows)
![Checkov](https://img.shields.io/badge/Checkov-9%20passed%20%C2%B7%205%20failed-D29922?style=flat-square)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=flat-square)

| | |
|---|---|
| **Author** | Dalla Samuel (CyberJKD) |
| **Date** | September 15, 2026 |
| **Platform** | Microsoft Azure |
| **Course** | Cloud System Admin Accelerator - Azure Administrator (AZ-104) Labs, Cloud Tech Techniques |
| **Roadmap** | Phase 06 · Cloud Tech Techniques · Cloud System Admin Accelerator |
| **Video Walkthrough** | [I Deployed a Full Active Directory Domain Controller with One Terraform Command](https://youtu.be/rVksbVzXgRA) |
| **Viewer Guide** | [CyberJKD-AD-DC-Viewer-Guide.pdf](CyberJKD-AD-DC-Viewer-Guide.pdf) |

---

## Objective

Deploy a Windows Server 2022 virtual machine on Azure and automatically configure it as an Active Directory Domain Controller - role installation and forest promotion included - in a single `terraform apply`, using a Custom Script Extension rather than any manual Server Manager clicking.

## Business Problem

Every organization running Windows workloads needs a centralized identity and authentication service. Without one, every server manages its own local accounts, every password change happens machine-by-machine, and there's no way to enforce consistent access policy. Active Directory Domain Services solves this: one directory of users, computers, and groups, with policy flowing outward from the domain controller to every joined machine.

This lab builds that foundation entirely through code - VM provisioning, AD DS role installation, and forest promotion, all from one Terraform configuration.

| Role | How this applies |
|---|---|
| Azure Administrator (AZ-104) | Provisioning VMs, networking and extensions from code is core AZ-104 work |
| Cloud Security Engineer | Reviewing IaC for exposed secrets and open ports before it ships (see Review Notes) |
| Systems Administrator | A domain controller rebuilt from one command instead of an afternoon of wizards |
| DevOps / Platform Engineer | Terraform state, provider behaviour and failure recovery - the hard parts of IaC |

## Environment

| Component | Value |
|---|---|
| Terraform | v1.16.2 (azurerm provider v3.117.1) |
| Azure CLI | 2.90.0 |
| Subscription | `cyberjkd-labs` |
| Region | `eastus2` (switched from `eastus` - see Troubleshooting Log) |
| VM Size | `Standard_D2s_v7` |
| OS Image | Windows Server 2022 Datacenter, **Gen2** (`2022-datacenter-g2`) |
| Resource Group | `rg-ad-cyberjkd` |
| Domain | `corp.cyberjkd.com` |
| NetBIOS Name | `CYBERJKD` |
| Admin Username | `adadmin` |
| DC private IP | `10.0.1.4` (static) |

## Key Concepts

- **Active Directory Domain Services (AD DS)** - centralized identity, authentication, and policy enforcement
- **Custom Script Extension** - runs a PowerShell command against the VM as part of the Terraform apply itself, no manual post-deploy steps
- **Infrastructure as Code (IaC)** - the entire environment (network, VM, role installation) defined declaratively and reproducibly
- **Terraform state** - what Terraform uses to track what it's actually deployed, and where things go wrong when that tracking drifts from reality (see Troubleshooting)
- **Public vs protected extension settings** *(added in review)* - a Custom Script Extension has two places to put the command: `settings` (sent to the VM in clear text) and `protected_settings` (encrypted with a key only Azure and the VM hold). Anything containing a password belongs in the protected one - see [Review Note 2](#review-notes-october-2026).
- **Forced replacement** *(added in review)* - some arguments can't be changed in place (a resource's `location`, for example), so Terraform destroys and recreates the resource. Resources that don't have that argument aren't replaced, even if Azure deletes them as a side-effect - see [Review Note 3](#review-notes-october-2026).

## Architecture

![Terraform Active Directory - Domain Controller Architecture](images/23-architecture-diagram.png)

```
Terraform (local)
   │
   ▼
Azure Subscription (cyberjkd-labs)
   └── rg-ad-cyberjkd (eastus2)
        ├── vnet-ad-cyberjkd (10.0.0.0/16)
        │    └── snet-ad (10.0.1.0/24)
        ├── nsg-ad-cyberjkd  → allow RDP :3389 inbound
        ├── pip-ad-cyberjkd  → static public IP
        ├── nic-ad-cyberjkd  → private IP 10.0.1.4
        └── vm-ad-cyberjkd (Standard_D2s_v7, Windows Server 2022 Datacenter g2)
             └── Custom Script Extension
                  ├── Install-WindowsFeature AD-Domain-Services
                  └── Install-ADDSForest -DomainName corp.cyberjkd.com
                       └── triggers automatic reboot
```

**Reviewed diagram (October 2026)** - redrawn from `main.tf`. The NSG is attached to the **NIC**, not the subnet (diagram 23 draws it inside the subnet), and it shows where each password ends up:

![Terraform AD DC architecture - reviewed](images/24-architecture-diagram-reviewed.png)

## Exercises

**A. Prerequisites** - Installed Azure CLI (`winget install -e --id Microsoft.AzureCLI`) and Terraform (`winget install -e --id Hashicorp.Terraform`) on a Windows 11 host. Neither was present at the start.

![Azure CLI install](images/01-azure-cli-install.png)
![Azure CLI version confirmed](images/02-azure-cli-version.png)
![Terraform install](images/05-terraform-install.png)
![Terraform version confirmed](images/06-terraform-version.png)

**B. Azure Authentication** - `az login`, selected the correct tenant, confirmed via `az account show`.

![Tenant and subscription selection](images/03-az-login-tenant-select.png)
![az account show output](images/04-az-account-show.png)

**C. Scaffold the Project** - Created `~/repos/az-ad-vm` and four empty Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars`).

![Project scaffold - four empty files](images/07-scaffold-files-created.png)

**D. Terraform Configuration** - Populated all four files. `terraform.tfvars` customized with project-specific values (`yourname = "cyberjkd"`, domain `corp.cyberjkd.com`, NetBIOS `CYBERJKD`).

![terraform.tfvars populated](images/08-terraform-tfvars-populated.png)

> ⚠️ [Review Note 1](#review-notes-october-2026): this screenshot shows the real admin and DSRM passwords in plain text.

![terraform init success](images/09-terraform-init-success.png)

**E. Deploy** - `terraform init` → `terraform plan` → `terraform apply`. Went through multiple size and region iterations before a clean apply (see Troubleshooting Log).

![terraform plan summary](images/10-terraform-plan-summary.png)

Four real failures happened here before a clean apply - full detail in the Troubleshooting Log below:

![SkuNotAvailable error](images/11-error-sku-not-available.png)
![Zero quota error](images/12-error-zero-quota.png)
![State drift error](images/13-error-state-drift.png)
![Gen1/Gen2 mismatch error](images/14-error-gen1-gen2-mismatch.png)

![terraform apply success](images/15-terraform-apply-success.png)

**F. Connect via RDP** - Waited 5–10 minutes post-apply for the automatic AD DS reboot, then connected using `CORP\adadmin` (domain-prefixed credential, not local-account syntax).

*(The NetBIOS domain set in this lab is `CYBERJKD`, so the down-level form is `CYBERJKD\adadmin`; `adadmin@corp.cyberjkd.com` also works.)*

![Server Manager - AD DS and DNS roles installed](images/16-server-manager-roles.png)

**G. Verify AD DS** - Confirmed via `Get-Service NTDS`, `Get-ADDomain`, `Get-ADDomainController -Filter *`, and `Resolve-DnsName corp.cyberjkd.com` - all passed clean.

![NTDS status + Get-ADDomain output](images/17-verify-ntds-addomain.png)
![Get-ADDomainController output](images/18-verify-addomaincontroller.png)
![DNS resolution confirmed](images/19-verify-dns-resolve.png)

**H. Extend with Real Identity Objects** - Rather than stop at "the service is running," created an Organizational Unit, a test user, and a security group, and added the user to the group - demonstrating the full identity → structure → access chain, not just role installation.

![OU containing the test user and security group](images/20-ou-user-group-proof.png)

**I. Teardown** - `terraform destroy` to remove all 9 resources and confirm zero ongoing cost via `az resource list`.

![terraform destroy complete](images/21-terraform-destroy-complete.png)
![az resource list - clean, zero cost](images/22-az-resource-list-clean.png)

## Terraform Configuration

The actual, working `.tf` files this lab deployed are in [`terraform/`](terraform/) in this same folder - `main.tf`, `variables.tf`, `outputs.tf`, and `terraform.tfvars.example`. Copy the `.example` file to `terraform.tfvars` and fill in your own values; don't retype from the screenshots above, and don't reconstruct from an AI - use these files directly, since they're the exact, tested, single-line-corrected version (see Troubleshooting Log #1 for why that matters).

> The files are unchanged by this review. Suggested changes are described in the [Review Notes](#review-notes-october-2026) only.

## Command Reference

```powershell
# Prerequisites
winget install -e --id Microsoft.AzureCLI
winget install -e --id Hashicorp.Terraform
az login --tenant <TENANT_ID>
az account show

# Scaffold
New-Item -ItemType Directory -Force -Path "$HOME\repos\az-ad-vm" | Out-Null
cd "$HOME\repos\az-ad-vm"
New-Item -ItemType File main.tf, variables.tf, outputs.tf, terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply

# Verify (on the deployed VM, PowerShell as Administrator)
Get-Service NTDS | Select-Object Name, Status
Get-ADDomain
Get-ADDomainController -Filter *
Resolve-DnsName corp.cyberjkd.com

# Extend
New-ADOrganizationalUnit -Name "CyberJKD-Lab" -Path "DC=corp,DC=cyberjkd,DC=com"
New-ADUser -Name "Test User" -SamAccountName "testuser" -Path "OU=CyberJKD-Lab,DC=corp,DC=cyberjkd,DC=com" -AccountPassword (ConvertTo-SecureString "********" -AsPlainText -Force) -Enabled $true
New-ADGroup -Name "CyberJKD-Lab-Users" -GroupScope Global -Path "OU=CyberJKD-Lab,DC=corp,DC=cyberjkd,DC=com"
Add-ADGroupMember -Identity "CyberJKD-Lab-Users" -Members "testuser"

# Teardown
terraform destroy
az resource list --output table
```

**Added in review** - commands from the Troubleshooting Log and the October 2026 checks:

| Command | Purpose |
|---|---|
| `az vm list-usage --location eastus2 --output table` | Quota per VM family before choosing a size (Troubleshooting #4) |
| `az vm list-skus --location eastus2 --size Standard_D --all --output table` | Sizes and their `Restrictions` - pick one showing `None` (Troubleshooting #7) |
| `terraform validate` / `terraform fmt -check` | Catch syntax errors like Troubleshooting #1 before `plan` |
| `terraform plan -out tfplan` then `terraform apply tfplan` | Apply exactly what was reviewed (the plan screenshot shows Terraform's warning about skipping `-out`) |
| `terraform state list` | See what Terraform believes exists - the first step when an apply references something missing |
| `terraform apply -replace="azurerm_subnet.main"` | Force a resource Terraform wouldn't replace on its own (Review Note 3) |
| `az vm extension show -g rg-ad-cyberjkd --vm-name vm-ad-cyberjkd -n install-ad-ds --query settings` | Shows what's in the extension's **public** settings (Review Note 2) |
| `checkov -d terraform/ --compact` | Static security scan of the Terraform - results in Review Note 5 |

## Verification Checklist

- [x] `terraform apply` completes with 0 errors
- [x] `NTDS` service status: `Running`
- [x] `Get-ADDomain` returns full domain object (`corp.cyberjkd.com`, forest `corp.cyberjkd.com`, mode `Windows2016Domain`)
- [x] `Get-ADDomainController -Filter *` shows the DC enabled, holding all Operation Master roles, correct OS version
- [x] `Resolve-DnsName corp.cyberjkd.com` resolves to the DC's own private IP (`10.0.1.4`)
- [x] `CyberJKD-Lab` OU visible in `dsa.msc`, containing `Test User` and `CyberJKD-Lab-Users`
- [x] `terraform destroy` completes cleanly - `Resources: 9 destroyed`
- [x] `az resource list` post-teardown shows only Azure's own auto-created NetworkWatcher resources, nothing billable remaining
- [x] Terraform files parse cleanly and Checkov scans them (October 2026 - 9 passed, 5 failed, see Review Note 5)
- [ ] No secrets visible in committed screenshots or the viewer guide: **no - see Review Note 1**
- [ ] Every secret passed to Azure through an encrypted channel: **no - DSRM password in public extension settings, see Review Note 2**

## Troubleshooting Log

**1. Multi-line string syntax error in `main.tf`.** Copy-pasting the `AutoLogon` content block and the Custom Script Extension's `commandToExecute` string from the PDF carried over hard line breaks. Terraform requires quoted strings on a single line unless using heredoc syntax. Fixed by rewriting both blocks as true single lines (soft-wrapped in the editor, but one logical line).

**2. MFA authentication failure on `az login`.** First login attempt failed with `AADSTS50076` - the tenant required multi-factor authentication that the initial browser flow didn't complete. Resolved by re-running `az login --tenant <TENANT_ID>` explicitly and completing the MFA challenge fully before closing the browser tab.

**3. `SkuNotAvailable: Standard_D2s_v3` in `eastus`.** The original lab spec's VM size had no capacity in that region at the time of deployment - a regional stock issue, not a configuration error.

**4. Zero quota on `Standard_D2s_v5` and `Standard_B2s`.** Both failed with `OperationNotAllowed` - `Current Limit: 0` for those VM families on this subscription. Ran `az vm list-usage --location eastus --output table` to inspect actual quota across every family rather than guessing sizes one at a time.

**5. Region switch to `eastus2`.** Since total regional vCPU quota was tight in `eastus`, switched `location` to `eastus2` for broader headroom. This required Terraform to destroy and recreate the six already-provisioned network resources, since they were tied to the original region.

**6. Terraform state drift after the region switch.** Mid-apply, resource group and network resources were destroyed and recreated, but the NIC's `subnet_id` reference briefly pointed at a subnet that had just been destroyed - `InvalidResourceReference` / `400 Bad Request`. Resolved with a full `terraform destroy` to clear the drifted state, followed by a single clean `terraform apply` from scratch in `eastus2`. *(Root cause in [Review Note 3](#review-notes-october-2026).)*

**7. `SkuNotAvailable: Standard_B2s` in `eastus2` as well.** Even the fallback burstable size had no regional capacity. Rather than guess further, ran `az vm list-skus --location eastus2 --size Standard_D --all --output table` and filtered for `Restrictions: None` to find a size guaranteed deployable - landed on `Standard_D2s_v7`.

**8. Hypervisor Generation mismatch on `Standard_D2s_v7`.** That size only boots Gen2 images, but the lab's default image reference (`2022-Datacenter`) is Gen1. Fixed by switching the `source_image_reference.sku` to `2022-datacenter-g2` - same OS, correct generation.

**9. Azure portal briefly showed "no subscriptions."** After several sign-in prompts across the session, the portal switched to a different, empty tenant directory. The Azure CLI confirmed the real subscription (`cyberjkd-labs`) was active and unaffected throughout - a portal display issue, not an actual account problem. Resolved via the portal's "Switch directories" link.

## Review Notes (October 2026)

I came back to this lab and re-checked it three ways: every screenshot, the committed Terraform (parsed and scanned with **Checkov 3.3.30**), and Microsoft's documentation for the Custom Script Extension. The deployment, verification and teardown all hold up. The DC came up exactly as claimed (domain, forest mode, FSMO roles, DNS at 10.0.1.4), and the static private IP fixes the "dynamic IP breaks DNS" point from the [Phase 03 AD lab](../../../../phase-03/project-02-active-directory). The notes are about secrets and one Terraform behaviour, because those are what an IaC reviewer checks first.

**1. The real admin and DSRM passwords are visible in a committed screenshot - and in the viewer guide.** `images/08-terraform-tfvars-populated.png` shows `terraform.tfvars` open in Notepad with both passwords in plain text, and the [viewer guide PDF](CyberJKD-AD-DC-Viewer-Guide.pdf) embeds the same image on page 9 (the video walkthrough likely shows it too). The `.gitignore` did its job and the file itself was never committed; the screenshot published its contents anyway. The lab was torn down, so these credentials no longer protect anything, but:
- they must never be reused anywhere;
- they reveal a pattern a guesser could try elsewhere;
- they undercut the README's own "Secrets live in plaintext" production point.

For future labs, blur or crop secrets before screenshotting. Replacing this image now would need a new image file and an updated PDF, and the old versions would still be in git history. That's a decision for me to make, so this review doesn't change either file.

**2. The DSRM password is sent through the extension's public `settings`, in clear text.** `main.tf` builds `commandToExecute` - including `Install-ADDSForest ... -SafeModeAdministratorPassword (ConvertTo-SecureString '${var.dsrm_password}' ...)` - inside the extension's `settings` block. Microsoft's [Custom Script Extension documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows) says public settings "are sent in clear text to the VM," while protected settings are encrypted, and it specifically says to use protected settings when the command "includes secrets such as a password." `sensitive = true` on the variable only hides it from `plan` output; it doesn't change where Azure stores it. The fix is a one-word change: move the same JSON from `settings` into `protected_settings`. Both passwords also sit in `terraform.tfstate` regardless, which is one more reason for the remote, access-controlled state backend already on the production list.

**3. The "state drift" error was a subnet Terraform never planned to replace.** Screenshot 13 shows exactly what happened. Changing `location` forced Terraform to destroy and recreate everything that has a location: the NSG association, NIC, NSG, public IP, VNet and resource group. `azurerm_subnet` has no `location` argument, and its name, VNet name and resource group name didn't change, so Terraform planned **no change** for it - there is no subnet line anywhere in that destroy/create list. When Azure deleted the old VNet, the subnet went with it; Terraform's state still recorded it as existing, so the new NIC was created against a subnet ID that no longer existed → `InvalidResourceReference`. It wasn't a mid-apply race. The full destroy-then-apply worked because it cleared state. For next time, either of these does it in one step:
- `terraform apply -replace="azurerm_subnet.main"`;
- `lifecycle { replace_triggered_by = [azurerm_virtual_network.main.id] }` on the subnet.

**4. Diagram 23 places the NSG on the subnet; the code puts it on the NIC.** `azurerm_network_interface_security_group_association` attaches `nsg-ad-cyberjkd` to `nic-ad-cyberjkd` only. The subnet has no NSG, and Checkov reports exactly that (CKV2_AZURE_31). With one VM the effect is the same, but any second VM dropped into `snet-ad` would have no NSG at all. The [reviewed diagram](#architecture) shows the real attachment point.

**5. Checkov results on `terraform/`: 9 passed, 5 failed.**

| Check | Finding | Note |
|---|---|---|
| CKV_AZURE_9 | RDP (3389) open to `*` | Already in What I'd Change for Production |
| CKV_AZURE_151 | Encryption at host not enabled | Fixed in [Lab 03](../lab-03_ntfs-file-server) |
| CKV_AZURE_119 | NIC has a public IP | Bastion or Just-In-Time access instead |
| CKV2_AZURE_31 | Subnet has no NSG | Review Note 4 |
| CKV_AZURE_50 | VM extension installed | Expected - the extension *is* this lab's design |

**6. The AutoLogon block isn't needed and adds one more copy of the admin password.** The Custom Script Extension runs as SYSTEM through the VM agent and needs no interactive logon. The `additional_unattend_content` AutoLogon block writes the admin password into the VM's unattend configuration and signs `adadmin` in once on first boot. Dropping it removes both the extra copy and Troubleshooting #1's other multi-line string.

**7. Smaller points.**
- **"Single `terraform apply`":** the successful apply in screenshot 15 shows `2 added`, the VM and extension, on top of seven resources left from the attempt that hit the Gen1/Gen2 error (screenshot 14, `Plan: 2 to add`). The committed code does build everything in one apply from scratch; the run on the day took several.
- **`.terraform.lock.hcl` is gitignored**, but Terraform's own init message (screenshot 09) says to commit it. Committing it pins the provider version - `~> 3.0` would otherwise pick up any newer 3.x on a fresh init.
- **RDP login:** the NetBIOS name set in this lab is `CYBERJKD`, so the down-level login is `CYBERJKD\adadmin`, not `CORP\adadmin` (Exercise F).
- **DNS for future domain members:** the VNet still uses Azure's default DNS. A second VM couldn't find `corp.cyberjkd.com` to join it until the VNet's `dns_servers` points at `10.0.1.4`.
- **Repo path:** the Connection to Roadmap section gives the path as `.../terraform-ad-dc/`; the folder is `lab-01_terraform-ad-dc/`.
- **Credit where due:** the production list says tfvars "would be gitignored, never committed" - in this repo it already is.

## What I'd Change for Production

- **NSG rule is wide open.** `source_address_prefix = "*"` allows RDP from any IP. Production would restrict this to a specific management IP range or route RDP through a bastion host instead of exposing port 3389 directly.
- **Secrets live in plaintext in `terraform.tfvars`.** `admin_password` and `dsrm_password` are stored unencrypted in a file that's easy to accidentally commit. Production would pull these from Azure Key Vault via a data source, and `terraform.tfvars` would be gitignored, never committed.
- **No remote state backend.** State was tracked locally on one machine - exactly what caused the drift issue in this lab. Production would use an Azure Storage Account backend with state locking, so state can't be edited by two people (or two terminal sessions) at once.
- **Single domain controller, no redundancy.** One DC is a single point of failure. Production would deploy at least two DCs across availability zones for forest resilience.
- **DSRM password has no recovery path.** It's a plaintext value with no retrieval option post-deployment. Production would store it in Key Vault immediately, not just note it down manually.

Added after the October 2026 review:

| Lab setup | Production reality |
|---|---|
| Command with the DSRM password in extension `settings` | Same command in `protected_settings`, password read from Key Vault (Review Note 2) |
| Screenshots taken with secrets on screen | Secrets blurred or never displayed; secret scanning on the repo (Review Note 1) |
| NSG on the NIC only | NSG on the subnet as the baseline, NIC rules only for exceptions (Review Note 4) |
| Region change handled by destroy + re-apply | `-replace` / `replace_triggered_by` for dependent resources, plans saved with `-out` (Review Note 3) |
| No IaC scanning | Checkov (or similar) in CI, failing the build on high-severity findings (Review Note 5) |
| VNet on Azure default DNS | VNet `dns_servers` set to the DCs so members can join the domain (Review Note 7) |

## Connection to Roadmap

This lab sits under **Phase 06 - Cloud Tech Techniques (CTT) - Cloud System Admin Accelerator** of the [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap), a dedicated track for labs completed through Jhante Charles's CTT community, tracked separately from the personal project phases (01 - 03) and the CYB 405 university coursework. Repo path: `phase-06/cloud-tech-techniques/cloud-system-admin-accelerator/terraform-ad-dc/`.

Not to be confused with Phase 03's **Portfolio Triad I - Infrastructure & Automation (Terraform)**, a larger planned personal project (multi-subnet VNet, least-privilege NSGs, remote state in Azure Blob) that this lab is intentionally scoped narrower than.

Per the same completion-batching approach used for CYB 405, Phase 06 will be added to the live roadmap site once the full Cloud System Admin Accelerator course is complete, not lab-by-lab. This is the first entry in that set - infrastructure, AD DS role installation, and identity object creation (OU, user, group) all from one Terraform configuration, torn down clean with zero lingering cost.

Related labs:
- **[Phase 03 · Active Directory on Azure](../../../../phase-03/project-02-active-directory)** - the same AD build done by hand
- **[Lab 02 · VS Code Remote-SSH](../lab-02_vscode-remote-ssh-setup)** - the editor setup for the rest of the course
- **[Lab 03 · NTFS File Server](../lab-03_ntfs-file-server)** - builds on this DC pattern and fixes several of the Checkov findings above

---

🌐 Full roadmap: [dallasamuel.github.io/CyberJKD-Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap)

🔗 All labs: [github.com/DallaSamuel/CyberJKD-Labs](https://github.com/DallaSamuel/CyberJKD-Labs)

---

*CyberJKD - Becoming dangerous through fundamentals. 🔒*
