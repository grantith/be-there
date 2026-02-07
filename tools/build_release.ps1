param(
    [string]$version = "dev",
    [string]$out_dir = "dist",
    [string]$ahk_dir = "ahk"
)

$ErrorActionPreference = "Stop"

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = Join-Path $script_dir ".." | Resolve-Path
$ahk_path = Join-Path $repo_root $ahk_dir
$out_path = Join-Path $repo_root $out_dir

New-Item -ItemType Directory -Force -Path $ahk_path | Out-Null

function Get-AssetUrl($repo, $pattern) {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (!$asset) { throw "Release asset not found for $repo" }
    return $asset.browser_download_url
}

function Get-AlphaAssetUrl($repo, $pattern) {
    if ($repo -eq "AutoHotkey/AutoHotkey") {
        $version = Invoke-RestMethod -Uri "https://www.autohotkey.com/download/2.1/version.txt"
        $version = $version.Trim()
        if (!$version) { throw "Alpha version not found at autohotkey.com" }
        return "https://www.autohotkey.com/download/2.1/AutoHotkey_$version.zip"
    }

    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases?per_page=100"
    $alpha = $releases | Where-Object { $_.tag_name -match "alpha" } | Select-Object -First 1
    if (!$alpha) { throw "Alpha release not found for $repo" }
    $asset = $alpha.assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
    if (!$asset) { throw "Alpha release asset not found for $repo" }
    return $asset.browser_download_url
}

function Download-And-Extract($url, $dest_dir) {
    $zip_path = Join-Path $dest_dir "download.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip_path
    Expand-Archive -Path $zip_path -DestinationPath $dest_dir -Force
    Remove-Item $zip_path -Force
}

function Test-AhkAlpha($path) {
    if (!(Test-Path $path)) { return $false }
    try {
        $ver = (Get-Item $path).VersionInfo.FileVersion
        $parsed = [version]$ver
        return ($parsed.Major -ge 2 -and $parsed.Minor -ge 1)
    } catch {
        return $false
    }
}

if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter Ahk2Exe.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading Ahk2Exe (v2.1 alpha if available)..."
    try {
        $url = Get-AlphaAssetUrl "AutoHotkey/Ahk2Exe" "^Ahk2Exe.*\.zip$"
    } catch {
        $url = Get-AssetUrl "AutoHotkey/Ahk2Exe" "^Ahk2Exe.*\.zip$"
    }
    Download-And-Extract $url $ahk_path
}

if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkeySC.bin -ErrorAction SilentlyContinue) -and !(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe -ErrorAction SilentlyContinue) -and !(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey32.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Searching for AutoHotkey base bin in installed locations..."
    $install_paths = @()
    if ($env:ProgramFiles) { $install_paths += Join-Path $env:ProgramFiles "AutoHotkey\\Compiler" }
    if (${env:ProgramFiles(x86)}) { $install_paths += Join-Path ${env:ProgramFiles(x86)} "AutoHotkey\\Compiler" }

    foreach ($path in $install_paths) {
        $bin = Join-Path $path "AutoHotkeySC.bin"
        if (Test-Path $bin) {
            Copy-Item -Path $bin -Destination (Join-Path $ahk_path "AutoHotkeySC.bin") -Force
            break
        }
    }
}

$existing_ahk64 = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$existing_ahk32 = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey32.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$needs_alpha = $true
if ($existing_ahk64 -and (Test-AhkAlpha $existing_ahk64.FullName)) { $needs_alpha = $false }
elseif ($existing_ahk32 -and (Test-AhkAlpha $existing_ahk32.FullName)) { $needs_alpha = $false }

if ($needs_alpha) {
    Write-Host "Downloading AutoHotkey v2.1 alpha base bin..."
    $url = Get-AlphaAssetUrl "AutoHotkey/AutoHotkey" "^AutoHotkey_2\.1-alpha.*\.zip$"
    Download-And-Extract $url $ahk_path
}

$compiler_item = Get-ChildItem -Path $ahk_path -Recurse -Filter Ahk2Exe.exe | Select-Object -First 1
$base_item = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkeySC.bin | Select-Object -First 1
if (!$base_item) { $base_item = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe | Select-Object -First 1 }
if (!$base_item) { $base_item = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey32.exe | Select-Object -First 1 }

if (!$compiler_item -or !$base_item) {
    throw "Ahk2Exe.exe or AutoHotkeySC.bin/AutoHotkey64.exe not found under $ahk_path. Install AutoHotkey or copy the base file into $ahk_path."
}

$compiler = $compiler_item.FullName
$base = $base_item.FullName

New-Item -ItemType Directory -Force -Path $out_path | Out-Null

$exe_path = Join-Path $out_path "harken.exe"
if (Test-Path $exe_path) {
    Remove-Item $exe_path -Force
}

$main_args = @(
    "/in", "$repo_root/harken.ahk",
    "/out", "$exe_path",
    "/base", "$base",
    "/silent", "verbose"
)


$stdout_path = Join-Path $out_path "ahk2exe.stdout.log"
$stderr_path = Join-Path $out_path "ahk2exe.stderr.log"
if (Test-Path $stdout_path) { Remove-Item $stdout_path -Force }
if (Test-Path $stderr_path) { Remove-Item $stderr_path -Force }

$proc = Start-Process -FilePath $compiler -ArgumentList $main_args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout_path -RedirectStandardError $stderr_path
if (!(Test-Path $exe_path)) {
    $stdout = ""
    $stderr = ""
    if (Test-Path $stdout_path) { $stdout = Get-Content $stdout_path -Raw }
    if (Test-Path $stderr_path) { $stderr = Get-Content $stderr_path -Raw }
    throw "Ahk2Exe did not produce harken.exe (exit $($proc.ExitCode)).`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
}
Write-Host "Compiled: $exe_path"

$source_zip = "$out_path/harken-source-$version.zip"

$source_files = @(
    "harken.ahk",
    "src",
    "tools",
    "config/config.example.toml",
    "README.md",
    "LICENSE",
    "LICENSES",
    "docs"
)

Compress-Archive -Path $source_files -DestinationPath $source_zip -Force

$compiled_files = @(
    "$out_path/harken.exe",
    "tools",
    "config/config.example.toml",
    "README.md",
    "LICENSE",
    "LICENSES",
    "docs"
)

Write-Host "Built: $source_zip"

$default_config = Join-Path $out_path "config.example.toml"
Get-Content "$repo_root/config/config.example.toml" -Raw | Out-File -FilePath $default_config -Encoding UTF8
Write-Host "Exported: $default_config"
