param(
    [string]$Version,
    [string]$Prerelease,
    [string]$GitRefName = $env:GITHUB_REF_NAME,
    [string]$EnvPath = $env:GITHUB_ENV
)

if (-not $Version) {
    $Version = $GitRefName
}

if (-not $Version) {
    throw "Version is required. Provide -Version or set GITHUB_REF_NAME."
}

$pre = $false
if ($Version -match "-rc" -or $Version -match "-beta" -or $Version -match "-alpha") {
    $pre = $true
}

if ($Prerelease) {
    if ($Prerelease -eq "true") {
        $pre = $true
    } elseif ($Prerelease -eq "false") {
        $pre = $false
    }
}

if ($EnvPath) {
    "VERSION=$Version" | Out-File -FilePath $EnvPath -Append
    "PRERELEASE=$pre" | Out-File -FilePath $EnvPath -Append
}

Write-Output "VERSION=$Version"
Write-Output "PRERELEASE=$pre"
