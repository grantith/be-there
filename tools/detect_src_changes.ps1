param(
    [string]$Sha = $env:GITHUB_SHA,
    [string]$OutputPath = $env:GITHUB_OUTPUT
)

if (-not $Sha) {
    $Sha = (git rev-parse HEAD).Trim()
}

try {
    $prevTag = git describe --tags --abbrev=0 "$Sha^" 2>$null
} catch {
    $prevTag = $null
}

if (-not $prevTag) {
    $hasChanges = $true
} else {
    $changed = git diff --name-only $prevTag $Sha | Where-Object { $_ -like "src/*" }
    $hasChanges = $changed.Count -gt 0
}

if ($OutputPath) {
    "has_src_changes=$hasChanges" | Out-File -FilePath $OutputPath -Append
}

Write-Output "has_src_changes=$hasChanges"
