# collect-phaseb-evidence.ps1
# Read-only evidence capture for Lab 03 Phase B (steps I-O).
# Changes nothing on the VMs or in Azure, except starting DC01/FS01 if you pass -StartVMs
# (they are deallocated again at the end). Never reads a secret value.
#
# Usage (from the ntfs-lab-terraform folder, after az login):
#   .\collect-phaseb-evidence.ps1            # VMs already running
#   .\collect-phaseb-evidence.ps1 -StartVMs  # start DC01 + FS01, collect, deallocate again

param(
    [string]$ResourceGroup = "RG-FileServerLab",
    [string]$OutDir = ".\evidence",
    [switch]$StartVMs
)

if ((az group exists -n $ResourceGroup) -ne "true") {
    throw "Resource group $ResourceGroup not found - the lab environment no longer exists."
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Save-Evidence([string]$Name, [string]$Text) {
    $path = Join-Path $OutDir $Name
    $Text | Out-File -FilePath $path -Encoding utf8
    Write-Host "  saved $path" -ForegroundColor Green
}

function Invoke-ReadOnly([string]$VMName, [string]$Script) {
    $tmp = [System.IO.Path]::GetTempFileName() + ".ps1"
    $Script | Out-File -FilePath $tmp -Encoding utf8
    try {
        $json = az vm run-command invoke -g $ResourceGroup -n $VMName --command-id RunPowerShellScript `
            --scripts "@$tmp" -o json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "run-command failed on $VMName" }
        $result = ($json -join "`n") | ConvertFrom-Json
        $out = ($result.value | Where-Object { $_.code -like "*StdOut*" }).message
        $err = ($result.value | Where-Object { $_.code -like "*StdErr*" }).message
        if ($err -and $err.Trim()) { $out += "`n--- StdErr ---`n$err" }
        return $out
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

# --- VM power state -------------------------------------------------------
$needed = @("DC01", "FS01")
$started = @()
foreach ($vm in $needed) {
    $state = az vm show -g $ResourceGroup -n $vm -d --query powerState -o tsv
    if ($state -ne "VM running") {
        if (-not $StartVMs) { throw "$vm is '$state'. Re-run with -StartVMs to start it for this collection." }
        Write-Host "Starting $vm..." -ForegroundColor Yellow
        az vm start -g $ResourceGroup -n $vm --only-show-errors | Out-Null
        $started += $vm
    }
}
if ($started -contains "DC01") { Write-Host "Giving AD services 90s to come up..." -ForegroundColor Yellow; Start-Sleep -Seconds 90 }

try {
    # --- 1. Azure side (run locally) --------------------------------------
    Write-Host "`n[1/3] Azure-side evidence" -ForegroundColor Cyan
    $kv = az keyvault list -g $ResourceGroup --query "[0].name" -o tsv
    $azure = @()
    $azure += "Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm') by collect-phaseb-evidence.ps1 (read-only)"
    $azure += "`n== Key Vault '$kv' - secret NAMES and expiry only (values are never read)"
    $azure += (az keyvault secret list --vault-name $kv --query "[].{name:name, expires:attributes.expires, contentType:contentType}" -o table | Out-String)
    $azure += "`n== FS01 managed identity (null = none; the Azure Monitor Agent requires one)"
    $azure += (az vm show -g $ResourceGroup -n FS01 --query identity -o json | Out-String)
    $azure += "`n== FS01 VM extensions"
    $azure += (az vm extension list -g $ResourceGroup --vm-name FS01 --query "[].{name:name, type:typePropertiesType, version:typeHandlerVersion, state:provisioningState}" -o table | Out-String)
    $fs01Id = az vm show -g $ResourceGroup -n FS01 --query id -o tsv
    $azure += "`n== Data Collection Rule associations on FS01"
    $azure += (az monitor data-collection rule association list --resource $fs01Id -o table 2>&1 | Out-String)
    Save-Evidence "01-azure-keyvault-identity-dcr.txt" ($azure -join "`n")

    # --- 2. DC01: AGDLP groups, users, GPOs ---------------------------------
    Write-Host "`n[2/3] DC01 - AD groups, users, GPOs" -ForegroundColor Cyan
    $dcScript = @'
Import-Module ActiveDirectory
"== Domain-local groups (AGDLP) and what is nested in them"
Get-ADGroup -Filter 'Name -like "DL_*"' -Properties Members | Sort-Object Name | ForEach-Object {
    $m = ($_.Members | ForEach-Object { (Get-ADObject $_).Name }) -join ", "
    "{0,-20} [{1}]  members: {2}" -f $_.Name, $_.GroupScope, $m
}
""
"== Global groups and their users"
Get-ADGroup -Filter 'Name -like "GRP_*"' | Sort-Object Name | ForEach-Object {
    $m = (Get-ADGroupMember $_ | Select-Object -ExpandProperty SamAccountName) -join ", "
    "{0,-12} [{1}]  members: {2}" -f $_.Name, $_.GroupScope, $m
}
""
"== Lab users - password metadata only (proves rotation; no secrets)"
Get-ADUser -Filter * -SearchBase "OU=Lab Users,DC=lab,DC=local" -Properties PasswordLastSet, PasswordNeverExpires, whenCreated |
    Sort-Object SamAccountName |
    Format-Table SamAccountName, Enabled, whenCreated, PasswordLastSet, PasswordNeverExpires -AutoSize | Out-String -Width 200
"== GPOs"
Get-GPO -All | Sort-Object DisplayName | Format-Table DisplayName, GpoStatus, ModificationTime -AutoSize | Out-String -Width 200
'@
    Save-Evidence "02-dc01-agdlp-users-gpos.txt" (Invoke-ReadOnly -VMName "DC01" -Script $dcScript)

    # --- 3. FS01: shares, NTFS, ABE, FSRM, auditing ------------------------
    Write-Host "`n[3/3] FS01 - shares, NTFS, ABE, FSRM, auditing" -ForegroundColor Cyan
    $fsScript = @'
$shares = "Finance", "HR", "Sales", "IT"
"== SMB shares - FolderEnumerationMode (AccessBased = ABE on)"
Get-SmbShare | Where-Object { $shares -contains $_.Name } |
    Format-Table Name, Path, FolderEnumerationMode -AutoSize | Out-String -Width 200
"== NTFS ACLs (post-AGDLP: should reference DL_* groups)"
foreach ($s in $shares) { icacls "C:\Shares\$s" }
""
"== Audit SACLs"
foreach ($s in $shares) {
    "[$s]"
    (Get-Acl "C:\Shares\$s" -Audit).Audit |
        Format-Table IdentityReference, FileSystemRights, AuditFlags -AutoSize | Out-String -Width 200
}
"== Audit policy - File System"
auditpol /get /subcategory:"File System"
""
"== FSRM quotas"
Get-FsrmQuota | Format-Table Path, @{n="LimitGB"; e={[math]::Round($_.Size / 1GB, 1)}}, Usage, SoftLimit -AutoSize | Out-String -Width 200
"== FSRM file screens"
Get-FsrmFileScreen | Format-Table Path, Active, IncludeGroup -AutoSize | Out-String -Width 200
"== Latest denied-access audit events (4656 with 'Not granted')"
Get-WinEvent -FilterHashtable @{ LogName = "Security"; Id = 4656 } -MaxEvents 500 -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match "Not granted" } | Select-Object -First 3 | ForEach-Object {
        $lines = ($_.Message -split "`r?`n" | Where-Object { $_ -match "Account Name:|Object Name:|Not granted" }) -join " | "
        "{0}  {1}" -f $_.TimeCreated, ($lines -replace "\s+", " ")
    }
""
"== Monitoring agent services"
Get-Service | Where-Object { $_.Name -like "*Monitor*" -or $_.DisplayName -like "*Azure Monitor*" } |
    Format-Table Name, DisplayName, Status -AutoSize | Out-String -Width 200
'@
    Save-Evidence "03-fs01-shares-ntfs-abe-fsrm-audit.txt" (Invoke-ReadOnly -VMName "FS01" -Script $fsScript)
}
finally {
    foreach ($vm in $started) {
        Write-Host "Deallocating $vm (it was started for this collection)..." -ForegroundColor Yellow
        az vm deallocate -g $ResourceGroup -n $vm --no-wait --only-show-errors
    }
}

Write-Host "`nDone. Evidence files are in $OutDir - review them, then add the folder to the repo." -ForegroundColor Green
