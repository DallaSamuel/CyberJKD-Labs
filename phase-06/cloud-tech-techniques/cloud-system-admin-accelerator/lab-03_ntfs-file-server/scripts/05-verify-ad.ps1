Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
Import-Module ActiveDirectory
$pass=$true
Write-Host "`n=== Active Directory Verification ===" -ForegroundColor Cyan
foreach ($ou in @("Lab Users","Lab Groups","Lab Computers")) {
    $exists=[bool](Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue)
    if ($exists) { Write-Host "  [PASS] OU: $ou" -ForegroundColor Green }
    else { Write-Host "  [FAIL] OU missing: $ou" -ForegroundColor Red; $pass=$false }
}
foreach ($g in @("GRP_Finance","GRP_HR","GRP_Sales","GRP_IT")) {
    $exists=[bool](Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue)
    if ($exists) { Write-Host "  [PASS] Group: $g" -ForegroundColor Green }
    else { Write-Host "  [FAIL] Group missing: $g" -ForegroundColor Red; $pass=$false }
}
$expectedUsers=@(
    @{Username="john.smith";Group="GRP_IT"},@{Username="sarah.jones";Group="GRP_Finance"},
    @{Username="mike.brown";Group="GRP_Finance"},@{Username="lisa.white";Group="GRP_HR"},
    @{Username="tom.davis";Group="GRP_Sales"})
foreach ($u in $expectedUsers) {
    $user=Get-ADUser -Filter "SamAccountName -eq '$($u.Username)'" -ErrorAction SilentlyContinue
    if (-not $user) { Write-Host "  [FAIL] User missing: $($u.Username)" -ForegroundColor Red; $pass=$false; continue }
    $members=Get-ADGroupMember -Identity $u.Group | Select-Object -ExpandProperty SamAccountName
    if ($members -contains $u.Username) { Write-Host "  [PASS] $($u.Username) -> $($u.Group)" -ForegroundColor Green }
    else { Write-Host "  [FAIL] $($u.Username) not in $($u.Group)" -ForegroundColor Red; $pass=$false }
}
Write-Host "`n=== AD Verification $(if ($pass){"PASSED"}else{"FAILED"}) ===" -ForegroundColor $(if ($pass){"Green"}else{"Red"})
