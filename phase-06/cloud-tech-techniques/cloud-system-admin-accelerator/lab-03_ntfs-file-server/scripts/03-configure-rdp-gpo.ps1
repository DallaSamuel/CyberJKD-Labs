Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$gpoName="Lab - Allow RDP for Domain Users"; $ouPath="OU=Lab Computers,DC=lab,DC=local"
New-GPO -Name $gpoName | Out-Null
New-GPLink -Name $gpoName -Target $ouPath
Set-GPRegistryValue -Name $gpoName -Key "HKLM\System\CurrentControlSet\Control\Terminal Server" -ValueName "fDenyTSConnections" -Type DWord -Value 0
$computer=Get-ADComputer -Filter { Name -eq "CLIENT01" } -ErrorAction SilentlyContinue
if ($computer) { $computer | Move-ADObject -TargetPath $ouPath; Write-Host "Moved CLIENT01 to Lab Computers OU." -ForegroundColor Cyan }
else { Write-Warning "CLIENT01 not yet in AD -- may still be joining." }
Write-Host "`nGPO configuration complete." -ForegroundColor Green
