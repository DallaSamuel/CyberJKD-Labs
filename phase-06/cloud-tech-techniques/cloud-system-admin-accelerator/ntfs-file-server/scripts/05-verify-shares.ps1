Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$basePath="C:\Shares"; $pass=$true
Write-Host "`n=== Share and NTFS Verification ===" -ForegroundColor Cyan
$expectedACLs=@{
    "Finance"=@(@{Identity="LAB\GRP_Finance";Right=[System.Security.AccessControl.FileSystemRights]::Modify}
        @{Identity="LAB\GRP_HR";Right=[System.Security.AccessControl.FileSystemRights]::Read}
        @{Identity="LAB\GRP_IT";Right=[System.Security.AccessControl.FileSystemRights]::FullControl})
    "HR"=@(@{Identity="LAB\GRP_HR";Right=[System.Security.AccessControl.FileSystemRights]::Modify}
        @{Identity="LAB\GRP_IT";Right=[System.Security.AccessControl.FileSystemRights]::FullControl})
    "Sales"=@(@{Identity="LAB\GRP_Sales";Right=[System.Security.AccessControl.FileSystemRights]::Modify}
        @{Identity="LAB\GRP_IT";Right=[System.Security.AccessControl.FileSystemRights]::FullControl})
    "IT"=@(@{Identity="LAB\GRP_IT";Right=[System.Security.AccessControl.FileSystemRights]::FullControl})}
foreach ($share in $expectedACLs.Keys) {
    Write-Host "`n[ $share ]" -ForegroundColor White
    $smb=Get-SmbShare -Name $share -ErrorAction SilentlyContinue
    if ($smb) { Write-Host "  [PASS] SMB share exists" -ForegroundColor Green }
    else { Write-Host "  [FAIL] Share missing" -ForegroundColor Red; $pass=$false; continue }
    $acl=(Get-Acl "$basePath\$share").Access
    foreach ($expected in $expectedACLs[$share]) {
        $ace=$acl|Where-Object{$_.IdentityReference.Value -eq $expected.Identity -and $_.AccessControlType -eq "Allow"}
        if (-not $ace) { Write-Host "  [FAIL] $($expected.Identity) has no entry" -ForegroundColor Red; $pass=$false; continue }
        $hasRight=($ace.FileSystemRights -band $expected.Right) -eq $expected.Right
        if ($hasRight) { Write-Host "  [PASS] $($expected.Identity) -> $($expected.Right)" -ForegroundColor Green }
        else { Write-Host "  [FAIL] $($expected.Identity) wrong rights" -ForegroundColor Red; $pass=$false }
    }
}
Write-Host "`n=== Verification $(if ($pass){"PASSED"}else{"FAILED"}) ===" -ForegroundColor $(if ($pass){"Green"}else{"Red"})
