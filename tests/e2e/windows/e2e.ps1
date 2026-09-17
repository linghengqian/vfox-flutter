$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo

foreach ($vfox in @('latest', 'main')) {
    foreach ($flavor in @('official', 'ohos')) {
        Write-Output ("=== vfox {0}, {1} ===" -f $vfox, $flavor)
        & docker run --rm -e "VFOX_VERSION=$vfox" -e "FLAVOR=$flavor" $Image
    }
}
