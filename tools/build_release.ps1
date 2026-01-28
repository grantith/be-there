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

function Download-And-Extract($url, $dest_dir) {
    $zip_path = Join-Path $dest_dir "download.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip_path
    Expand-Archive -Path $zip_path -DestinationPath $dest_dir -Force
    Remove-Item $zip_path -Force
}

if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter Ahk2Exe.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading Ahk2Exe (latest release)..."
    $url = Get-AssetUrl "AutoHotkey/Ahk2Exe" "^Ahk2Exe.*\.zip$"
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

if (!(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkeySC.bin -ErrorAction SilentlyContinue) -and !(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey64.exe -ErrorAction SilentlyContinue) -and !(Get-ChildItem -Path $ahk_path -Recurse -Filter AutoHotkey32.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Downloading AutoHotkey base bin (latest release)..."
    $url = Get-AssetUrl "AutoHotkey/AutoHotkey" "^AutoHotkey_.*\.zip$"
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

$exe_path = Join-Path $out_path "be-there.exe"
if (Test-Path $exe_path) {
    Remove-Item $exe_path -Force
}

$main_args = @(
    "/in", "$repo_root/be-there.ahk",
    "/out", "$exe_path",
    "/base", "$base",
    "/silent", "verbose"
)


$null = Start-Process -FilePath $compiler -ArgumentList $main_args -NoNewWindow -Wait -PassThru
if (!(Test-Path $exe_path)) {
    throw "Ahk2Exe did not produce be-there.exe. Check the compiler base file and try again."
}
Write-Host "Compiled: $exe_path"

$source_zip = "$out_path/be-there-source-$version.zip"
$compiled_zip = "$out_path/be-there-$version-win64.zip"

$source_files = @(
    "be-there.ahk",
    "src",
    "tools",
    "config/config.example.json",
    "README.md",
    "LICENSE",
    "LICENSES",
    "docs"
)

Compress-Archive -Path $source_files -DestinationPath $source_zip -Force

$compiled_files = @(
    "$out_path/be-there.exe",
    "tools",
    "config/config.example.json",
    "README.md",
    "LICENSE",
    "LICENSES",
    "docs"
)

Compress-Archive -Path $compiled_files -DestinationPath $compiled_zip -Force

Write-Host "Built: $compiled_zip"
Write-Host "Built: $source_zip"

$default_config = Join-Path $out_path "config.example.json"
Get-Content "$repo_root/config/config.example.json" -Raw | Out-File -FilePath $default_config -Encoding UTF8
Write-Host "Exported: $default_config"
