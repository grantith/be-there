param(
    [string]$version = "dev",
    [string]$out_dir = "dist",
    [string]$ahk_dir = "ahk"
)

$ErrorActionPreference = "Stop"

# Use the mirror to avoid 403 and not need to mess with useragent
# The alpha releases don't have a reliable mirror for automations currently
# so we created a deps release for 2.1-alpha.18
$ahk_link = "https://github.com/grantith/harken/releases/download/deps/AutoHotkey_2.1-alpha.18.zip"
$ahk_2exe_link = "https://github.com/AutoHotkey/Ahk2Exe/releases/download/Ahk2Exe1.1.37.02a0a/Ahk2Exe1.1.37.02a0.zip"
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = Join-Path $script_dir ".." | Resolve-Path
$ahk_dir = "./dist"
$ahk_path = Join-Path $repo_root $ahk_dir
$out_path = Join-Path $repo_root $out_dir

New-Item -ItemType Directory -Force -Path $ahk_path | Out-Null

##
# Download AHK Prereqs
##

# First, AHK
if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading Ahkv2 from $ahk_link"
    $ahk_zip_path = Join-Path $ahk_path "ahk.zip"
    Invoke-WebRequest -Uri $ahk_link -OutFile $ahk_zip_path
    Expand-Archive -Path $ahk_zip_path -DestinationPath $ahk_path -Force
    Remove-Item $ahk_zip_path -Force
} else {
    Write-Host "./dist/Ahk2Exe.exe already exists, skipping download"
}

# Second, Ahk2Exe
if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter Ahk2Exe.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading Ahk2Exe from $ahk_2exe_link"
    $ahk_2xe_zip_path = Join-Path $ahk_path "ahk2exe.zip"
    Invoke-WebRequest -Uri $ahk_2exe_link -OutFile $ahk_2xe_zip_path
    Expand-Archive -Path $ahk_2xe_zip_path -DestinationPath $ahk_path -Force
    Remove-Item $ahk_2xe_zip_path -Force
} else {
    Write-Host "./dist/Ahk2Exe.exe already exists, skipping download"
}

$compiler_item = Get-ChildItem -Path $ahk_path -Recurse -Filter Ahk2Exe.exe | Select-Object -First 1
$base_item = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkeySC.bin | Select-Object -First 1
if (!$base_item) { $base_item = Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe | Select-Object -First 1 }

if (!$compiler_item -or !$base_item) {
    throw "Ahk2Exe.exe or AutoHotkeySC.bin/AutoHotkey64.exe not found under $ahk_path. Install AutoHotkey or copy the base file into $ahk_path."
}

##
# Build
##

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

$null = Start-Process -FilePath $compiler -ArgumentList $main_args -NoNewWindow -Wait -PassThru
if (!(Test-Path $exe_path)) {
    throw "Ahk2Exe did not produce harken.exe. Check the logs and try again."
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
