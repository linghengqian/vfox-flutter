param(
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
Add-Content -Path $PROFILE -Value 'Invoke-Expression "$(vfox activate pwsh)"'

$setup = @'
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
vfox install flutter@{0}
vfox use --global flutter@{0}
. $PROFILE
'@
& pwsh -NoLogo -Command ($setup -f $Version)
