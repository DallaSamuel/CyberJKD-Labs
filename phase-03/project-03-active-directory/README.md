# Active Directory Lab - Enterprise Identity Environment from Scratch
 
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Platform](https://img.shields.io/badge/Platform-Azure-0078D4?logo=microsoftazure&logoColor=white)
![OS](https://img.shields.io/badge/OS-Windows%20Server%202025-0078D4)
![Phase](https://img.shields.io/badge/CyberJKD-Phase%2003%20·%20Project%2003-8A2BE2)
 
**Author:** Dalla Samuel (CyberJKD)

**Date:** 20th May 2026

**Platform:** Windows Server 2025 · Azure Free Account (Standard_B2s VM)

**Lab Source:** CloudTechExec - 5 Labs To Get You Hired · Lab 1

**Roadmap:** [Phase 03 · Project 03](https://dallasamuel.github.io/CyberJKD-Roadmap)
 
---
 
## Objective
 
Build a complete Active Directory environment from scratch on Azure - promoting a Windows Server 2025 VM to a Domain Controller, structuring departments as Organisational Units, creating users and security groups, enforcing Group Policy, and performing common help desk tasks - using both GUI and PowerShell automation.
 
---
 
## Business Problem This Lab Solves
 
Every organisation running Windows infrastructure relies on Active Directory to answer one fundamental question: **who is allowed to do what?**
 
Active Directory is the identity backbone. It controls which users can log into which machines, which groups access which resources, and which policies apply to which departments. When a new employee joins, IT creates their account and adds them to the right groups - access is granted automatically. When they leave, IT disables one account and every door closes simultaneously.
 
This is not legacy technology. Hybrid environments sync on-premises AD to Microsoft Entra ID in the cloud. Understanding AD is foundational knowledge that transfers directly to cloud roles.
 
---
 
## Environment
 
| Component | Detail |
|---|---|
| Cloud Platform | Microsoft Azure (Free Account) |
| VM Size | Standard_B2s — 2 vCPU, 4GB RAM |
| OS | Windows Server 2025 Datacenter Gen2 |
| Domain | lab.local |
| Cost | $0 - fully within free tier |
 
---
 
## What Was Built
 
### Domain Controller
 
- Promoted Windows Server 2025 to Domain Controller
- Created new Active Directory forest: `lab.local`
- Configured DNS - server is now authoritative DNS for the domain
- Set DSRM password for disaster recovery
---
 
### Organisational Unit Structure
 
5 OUs created to mirror enterprise department structure:
 
| OU | Purpose |
|---|---|
| IT | IT department users and admins |
| Finance | Finance department users |
| HR | Human Resources users |
| Sales | Sales department users |
| Computers | Domain-joined workstations |
 
---
 
### Security Groups
 
Role-based access control through group membership:
 
| Group | OU | Members |
|---|---|---|
| IT_Admins | IT | alice.chen |
| Finance_Users | Finance | bob.patel |
| HR_Users | HR | carol.jones |
| Sales_Users | Sales | david.smith |
 
---
 
### User Accounts
 
4 users created with enterprise naming convention (`firstname.lastname`):
 
| User | Department | UPN |
|---|---|---|
| alice.chen | IT | alice.chen@lab.local |
| bob.patel | Finance | bob.patel@lab.local |
| carol.jones | HR | carol.jones@lab.local |
| david.smith | Sales | david.smith@lab.local |
 
---
 
### Group Policy Object - IT Security Policy
 
Applied to the IT OU - enforces the following settings centrally:
 
| Policy | Setting | Reason |
|---|---|---|
| Minimum password length | 12 characters | Enforces strong passwords |
| Password complexity | Enabled | Requires upper, lower, number, symbol |
| Screen lock inactivity | 900 seconds (15 min) | Auto-locks unattended machines |
| Removable storage access | Deny all | Prevents USB data exfiltration |
 
---
 
### Help Desk Tasks Practised
 
- Password reset with forced change on next login
- Account unlock after lockout
- Account disable for offboarding (preserves audit history)
- Inactive account audit - accounts not logged in for 90 days
- Group membership reporting
---
 
## Key PowerShell Commands Used
 
```powershell
# Install AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
 
# Install Group Policy Management Console
Install-WindowsFeature -Name GPMC
 
# Promote server to Domain Controller
Install-ADDSForest -DomainName 'lab.local' -DomainNetBiosName 'LAB' `
  -InstallDns:$true `
  -SafeModeAdministratorPassword (ConvertTo-SecureString 'YourDSRMPassword!' -AsPlainText -Force) `
  -Force:$true
 
# Create all 5 OUs
New-ADOrganizationalUnit -Name "IT"        -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Finance"   -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "HR"        -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Sales"     -Path "DC=lab,DC=local"
New-ADOrganizationalUnit -Name "Computers" -Path "DC=lab,DC=local"
 
# Create all 4 security groups
New-ADGroup -Name "IT_Admins"     -GroupScope Global -GroupCategory Security -Path "OU=IT,DC=lab,DC=local"
New-ADGroup -Name "Finance_Users" -GroupScope Global -GroupCategory Security -Path "OU=Finance,DC=lab,DC=local"
New-ADGroup -Name "HR_Users"      -GroupScope Global -GroupCategory Security -Path "OU=HR,DC=lab,DC=local"
New-ADGroup -Name "Sales_Users"   -GroupScope Global -GroupCategory Security -Path "OU=Sales,DC=lab,DC=local"
 
# Create all 4 users
$password = ConvertTo-SecureString "Welcome@2026!" -AsPlainText -Force
 
New-ADUser -Name "alice.chen"  -GivenName "Alice" -Surname "Chen" `
  -SamAccountName "alice.chen" -UserPrincipalName "alice.chen@lab.local" `
  -Path "OU=IT,DC=lab,DC=local" -AccountPassword $password -Enabled $true
 
New-ADUser -Name "bob.patel"   -GivenName "Bob" -Surname "Patel" `
  -SamAccountName "bob.patel"  -UserPrincipalName "bob.patel@lab.local" `
  -Path "OU=Finance,DC=lab,DC=local" -AccountPassword $password -Enabled $true
 
New-ADUser -Name "carol.jones" -GivenName "Carol" -Surname "Jones" `
  -SamAccountName "carol.jones" -UserPrincipalName "carol.jones@lab.local" `
  -Path "OU=HR,DC=lab,DC=local" -AccountPassword $password -Enabled $true
 
New-ADUser -Name "david.smith" -GivenName "David" -Surname "Smith" `
  -SamAccountName "david.smith" -UserPrincipalName "david.smith@lab.local" `
  -Path "OU=Sales,DC=lab,DC=local" -AccountPassword $password -Enabled $true
 
# Add each user to their department group
Add-ADGroupMember -Identity "IT_Admins"     -Members "alice.chen"
Add-ADGroupMember -Identity "Finance_Users" -Members "bob.patel"
Add-ADGroupMember -Identity "HR_Users"      -Members "carol.jones"
Add-ADGroupMember -Identity "Sales_Users"   -Members "david.smith"
 
# Reset a password and force change on next login
Set-ADAccountPassword -Identity "bob.patel" -Reset `
  -NewPassword (ConvertTo-SecureString "NewPass@2026!" -AsPlainText -Force)
Set-ADUser -Identity "bob.patel" -ChangePasswordAtLogon $true
 
# Unlock a locked account
Unlock-ADAccount -Identity "carol.jones"
 
# Disable an account (offboarding)
Disable-ADAccount -Identity "david.smith"
 
# Audit accounts inactive for 90 days
$cutoff = (Get-Date).AddDays(-90)
Get-ADUser -Filter {LastLogonDate -lt $cutoff -and Enabled -eq $true} `
  -Properties LastLogonDate | Select-Object Name, LastLogonDate
 
# Check group membership for a user
Get-ADPrincipalGroupMembership -Identity "alice.chen" | Select-Object Name
```
 
---
 
## Verification
 
| Check | Command | Expected Result |
|---|---|---|
| DC running | `Get-ADDomainController` | Returns lab.local DC info |
| OUs exist | `Get-ADOrganizationalUnit -Filter *` | Lists all 5 OUs |
| Users enabled | `Get-ADUser -Filter {Enabled -eq $true}` | Lists 4 accounts |
| Group membership | `Get-ADGroupMember -Identity IT_Admins` | Returns alice.chen |
| GPO linked | `Get-GPInheritance -Target 'OU=IT,DC=lab,DC=local'` | Shows IT Security Policy |
 
---
 
## Key Decisions and Why
 
**Why Azure over VirtualBox for this lab**
Azure runs the VM in Microsoft's data centre - same environment as enterprise deployments. No local hardware requirements. The Standard_B2s VM is covered by the $200 free credit. Stopping the VM when not in use keeps costs near zero.
 
**Why `lab.local` as the domain name**
`.local` is the standard for internal-only domains not exposed to the internet. Enterprise environments use split-DNS - internal domain separate from public DNS.
 
**Why OUs mirror department structure**
OUs are the unit of policy application in AD. Structuring by department means you can apply different GPOs to different departments - IT gets stricter security policies, Finance gets compliance controls - all from one central place.
 
**Why group-based access control over direct user assignment**
Granting access to groups instead of individual users scales to thousands of users. Adding someone to a group grants all group permissions instantly. Removing them revokes all access simultaneously. This is the principle of least privilege applied at enterprise scale.
 
**Why disable accounts instead of delete on offboarding**
Deletion is permanent and removes audit history. Disabled accounts preserve all group memberships and attributes for compliance and audit purposes. Most enterprise security policies mandate disable-then-archive over delete.
 
---
 
## What I Would Change for Production
 
- Use a static private IP for the Domain Controller - dynamic IP breaks DNS
- Add a second Domain Controller for redundancy - single DC is a single point of failure
- Implement fine-grained password policies - different departments may need different password requirements
- Enable AD audit logging and forward to SIEM (Splunk / Microsoft Sentinel) for monitoring authentication events
- Implement LAPS (Local Administrator Password Solution) to randomise local admin passwords on domain-joined machines
---
 
## Connection to Roadmap
 
This lab directly maps to:
 
- **Phase 03 · Project 03** - Provision Active Directory on Azure
- **Phase 02 focus area** - Windows identity management
- **Phase 05** - Entra ID (cloud AD) uses the same concepts: users, groups, roles, conditional access
AD is the most targeted system in ransomware attacks. Understanding how to build it is the foundation of knowing how to defend it.
 
---
 
## References
 
- [CyberJKD Roadmap](https://dallasamuel.github.io/CyberJKD-Roadmap/)
- [CyberJKD Labs on GitHub](https://github.com/DallaSamuel/CyberJKD-Labs)
- [CloudTechExec Community](https://skool.com/cloudtechexec)
- [Microsoft AD DS Documentation](https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/get-started/virtual-dc/active-directory-domain-services-overview)
- [Azure Free Account](https://azure.microsoft.com/free)
