param([Parameter(Mandatory=$true)][string]$KeyVaultName,[string]$ResourceGroup="RG-FileServerLab")

$startTime=Get-Date
Write-Host "`n[$(Get-Date -Format "HH:mm:ss")] Retrieving credentials from Key Vault..." -ForegroundColor Cyan
$AdminPassword=az keyvault secret show --vault-name $KeyVaultName --name "vm-admin-password" --query "value" -o tsv
if (-not $AdminPassword -or $LASTEXITCODE -ne 0) { throw "Could not retrieve password from Key Vault. Run az login first." }
Write-Host "  Credentials retrieved." -ForegroundColor Green

function Invoke-VMScript {
param([string]$VMName,[string]$ScriptPath,[string]$Description,[hashtable]$Replacements=@{})
    Write-Host "`n[$(Get-Date -Format "HH:mm:ss")] >>> $Description" -ForegroundColor Cyan
    $script=Get-Content $ScriptPath -Raw
    foreach ($key in $Replacements.Keys) { $script=$script -replace $key,[regex]::Escape($Replacements[$key]) }
    $tempFile=[System.IO.Path]::GetTempPath()+[System.IO.Path]::GetRandomFileName()+".ps1"
    $script | Out-File -FilePath $tempFile -Encoding UTF8
    try {
        $jsonLines=az vm run-command invoke --resource-group $ResourceGroup --name $VMName --command-id RunPowerShellScript --scripts "@$tempFile" --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) { throw "az vm run-command failed on $VMName" }
        $result=($jsonLines -join "`n") | ConvertFrom-Json
        $stdout=($result.value | Where-Object{$_.code -like "*StdOut*"}).message
        $stderr=($result.value | Where-Object{$_.code -like "*StdErr*"}).message
        if ($stdout) { Write-Host $stdout }
        if ($stderr -and $stderr.Trim() -ne "") { Write-Warning "  VM StdErr: $stderr" }
    } finally { Remove-Item $tempFile -ErrorAction SilentlyContinue }
}

function Wait-VMOnline { param([string]$VMName,[int]$TimeoutSeconds=360)
    Write-Host "  Waiting for $VMName..." -ForegroundColor Yellow
    $elapsed=0
    do { Start-Sleep -Seconds 15; $elapsed+=15
        try { $state=(az vm show -g $ResourceGroup -n $VMName -d --query "powerState" -o tsv --only-show-errors 2>$null).Trim() } catch { $state="" }
        Write-Host "    $VMName -> $state (${elapsed}s)" -ForegroundColor DarkGray
    } while ($state -ne "VM running" -and $elapsed -lt $TimeoutSeconds)
    if ($state -ne "VM running") { throw "Timeout: $VMName did not return within ${TimeoutSeconds}s" }
    Write-Host "  $VMName is online." -ForegroundColor Green
}

Write-Host "`n[STEP 1] Promoting DC01 to Domain Controller" -ForegroundColor Magenta
try { Invoke-VMScript -VMName "DC01" -ScriptPath ".\scripts\00-promote-dc.ps1" -Description "Promoting DC01" -Replacements @{"SAFE_MODE_PASSWORD"=$AdminPassword} }
catch { Write-Host "  DC01 disconnected -- expected after promotion." -ForegroundColor Yellow }
Start-Sleep -Seconds 60; Wait-VMOnline -VMName "DC01"; Start-Sleep -Seconds 90

Write-Host "`n[STEP 2] Creating OUs, Groups, and Users" -ForegroundColor Magenta
Invoke-VMScript -VMName "DC01" -ScriptPath ".\scripts\01-create-ad-users-groups.ps1" -Description "Creating AD objects"

Write-Host "`n[STEP 3] Joining FS01 to lab.local" -ForegroundColor Magenta
Invoke-VMScript -VMName "FS01" -ScriptPath ".\scripts\04-domain-join.ps1" -Description "Joining FS01" -Replacements @{"ADMIN_PASSWORD"=$AdminPassword}
Start-Sleep -Seconds 30; Wait-VMOnline -VMName "FS01"; Start-Sleep -Seconds 30

Write-Host "`n[STEP 4] Configuring shares and NTFS on FS01" -ForegroundColor Magenta
Invoke-VMScript -VMName "FS01" -ScriptPath ".\scripts\02-configure-shares-and-permissions.ps1" -Description "Creating shares and NTFS"

Write-Host "`n[STEP 5] Joining CLIENT01 to lab.local" -ForegroundColor Magenta
Invoke-VMScript -VMName "CLIENT01" -ScriptPath ".\scripts\04-domain-join.ps1" -Description "Joining CLIENT01" -Replacements @{"ADMIN_PASSWORD"=$AdminPassword}
Start-Sleep -Seconds 30; Wait-VMOnline -VMName "CLIENT01"; Start-Sleep -Seconds 30

Write-Host "`n[STEP 5b] Granting Domain Users RDP on CLIENT01" -ForegroundColor Magenta
Invoke-VMScript -VMName "CLIENT01" -ScriptPath ".\scripts\06-add-rdp-users.ps1" -Description "Adding Domain Users to RDP group"

Write-Host "`n[STEP 6] Configuring RDP GPO on DC01" -ForegroundColor Magenta
Invoke-VMScript -VMName "DC01" -ScriptPath ".\scripts\03-configure-rdp-gpo.ps1" -Description "Creating RDP GPO"

Write-Host "`n[STEP 7] Running automated verification" -ForegroundColor Magenta
Invoke-VMScript -VMName "DC01" -ScriptPath ".\scripts\05-verify-ad.ps1" -Description "Verifying AD"
Invoke-VMScript -VMName "FS01" -ScriptPath ".\scripts\05-verify-shares.ps1" -Description "Verifying shares"

$duration=(Get-Date)-$startTime
Write-Host "`n=== LAB FULLY CONFIGURED ($([math]::Round($duration.TotalMinutes,1)) min) ===" -ForegroundColor Green
Write-Host "RDP into CLIENT01 as: LAB\sarah.jones  Password: P@ssw0rd123!"
