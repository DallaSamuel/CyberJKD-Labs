Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Write-Host "Installing AD DS..." -ForegroundColor Yellow
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose:$false
$safeModePassword = ConvertTo-SecureString "SAFE_MODE_PASSWORD" -AsPlainText -Force
Import-Module ADDSDeployment
Install-ADDSForest `
    -DomainName "lab.local" `
    -DomainNetbiosName "LAB" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDns: $true `
    -SafeModeAdministratorPassword $safeModePassword `
    -Force: $true `
    -NoRebootOnCompletion: $false
