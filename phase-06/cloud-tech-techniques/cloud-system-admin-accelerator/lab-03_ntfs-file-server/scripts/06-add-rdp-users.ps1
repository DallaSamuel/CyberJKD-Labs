Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$rdpGroup="Remote Desktop Users"; $domainUsers="LAB\Domain Users"
$existing=Get-LocalGroupMember -Group $rdpGroup -ErrorAction SilentlyContinue | Where-Object{$_.Name -eq $domainUsers}
if ($existing) { Write-Host "$domainUsers already in $rdpGroup." -ForegroundColor Yellow }
else { Add-LocalGroupMember -Group $rdpGroup -Member $domainUsers
    Write-Host "Added $domainUsers to $rdpGroup." -ForegroundColor Green }
Get-LocalGroupMember -Group $rdpGroup | Select-Object Name,ObjectClass | Format-Table -AutoSize
