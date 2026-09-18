$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Repo = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Image = 'vfox-flutter-e2e:windows'

& docker build --pull -f "$PSScriptRoot\Dockerfile" -t $Image $Repo

$foxes = if ($env:VFOX_VERSION) { @($env:VFOX_VERSION) } else { @('latest', 'main') }
$flavours = if ($env:FLAVOR) { @($env:FLAVOR) } else { @('official', 'ohos') }

foreach ($vfox in $foxes) {
    foreach ($flavor in $flavours) {
        Write-Output ("=== vfox {0}, {1} ===" -f $vfox, $flavor)
        $passed = $false
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            try {
                & docker run --rm -e "VFOX_VERSION=$vfox" -e "FLAVOR=$flavor" $Image
                $passed = $true
            } catch {
                Write-Output ("attempt {0} of 2 failed" -f $attempt)
            }
            if ($passed) { break }
        }
        if (-not $passed) {
            throw ("vfox {0}, {1} failed twice" -f $vfox, $flavor)
        }
    }
}
