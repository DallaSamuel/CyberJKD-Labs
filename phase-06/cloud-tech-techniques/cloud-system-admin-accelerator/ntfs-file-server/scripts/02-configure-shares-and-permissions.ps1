Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
$domain="LAB"; $basePath="C:\Shares"
New-Item -Path $basePath -ItemType Directory -Force
foreach ($folder in @("Finance","HR","Sales","IT")) {
    New-Item -Path "$basePath\$folder" -ItemType Directory -Force
    New-SmbShare -Name $folder -Path "$basePath\$folder" -FullAccess "Everyone"
}
function Set-FolderPermissions { param($path,$permissions)
    icacls $path /inheritance:d
    icacls $path /remove "BUILTIN\Users"
    icacls $path /remove "Everyone"
    icacls $path /remove "NT AUTHORITY\Authenticated Users"
    foreach ($p in $permissions) { icacls $path /grant "$($p.Identity)`:$($p.Rights)" }
}
Set-FolderPermissions -path "$basePath\Finance" -permissions @(
    @{Identity="$domain\GRP_Finance";Rights="(OI)(CI)M"},
    @{Identity="$domain\GRP_HR";Rights="(OI)(CI)R"},
    @{Identity="$domain\GRP_IT";Rights="(OI)(CI)F"},
    @{Identity="BUILTIN\Administrators";Rights="(OI)(CI)F"})
Set-FolderPermissions -path "$basePath\HR" -permissions @(
    @{Identity="$domain\GRP_HR";Rights="(OI)(CI)M"},
    @{Identity="$domain\GRP_IT";Rights="(OI)(CI)F"},
    @{Identity="BUILTIN\Administrators";Rights="(OI)(CI)F"})
Set-FolderPermissions -path "$basePath\Sales" -permissions @(
    @{Identity="$domain\GRP_Sales";Rights="(OI)(CI)M"},
    @{Identity="$domain\GRP_IT";Rights="(OI)(CI)F"},
    @{Identity="BUILTIN\Administrators";Rights="(OI)(CI)F"})
Set-FolderPermissions -path "$basePath\IT" -permissions @(
    @{Identity="$domain\GRP_IT";Rights="(OI)(CI)F"},
    @{Identity="BUILTIN\Administrators";Rights="(OI)(CI)F"})
Write-Host "`nDone." -ForegroundColor Cyan
