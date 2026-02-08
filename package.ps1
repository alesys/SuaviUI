# SuaviUI Package Builder
# Packages the addon and creates a zip file in the parent directory

param(
    [string]$Version = "v0.1.15-alpha",
    [string]$OutputDir = ".."
)

$addonName = "SuaviUI"
$addonDir = Split-Path -Leaf (Get-Location)

if ($addonDir -ne $addonName) {
    Write-Error "Error: Must run from SuaviUI directory"
    exit 1
}

$parentDir = Resolve-Path $OutputDir
$outputZip = "$parentDir\${addonName}_${Version}.zip"

Write-Host "Building package: $outputZip" -ForegroundColor Green

# Create temp directory
$tempDir = New-TemporaryDirectory
$packageDir = Join-Path $tempDir $addonName

# Copy addon files (excluding things in .pkgmeta ignore list)
Copy-Item . $packageDir -Recurse -Force `
    -Exclude @(
        ".git",
        ".github",
        ".gitignore",
        ".busted",
        ".copilot-instructions.md",
        "docs",
        "README.md",
        ".pkgmeta",
        ".wowup_ignore",
        "spec",
        "error.log",
        "*.ps1"
    )

# Create zip
if (Test-Path $outputZip) {
    Remove-Item $outputZip -Force
    Write-Host "Removed existing zip: $outputZip"
}

Compress-Archive -Path $packageDir -DestinationPath $outputZip
Write-Host "✓ Package created: $outputZip" -ForegroundColor Green

# Cleanup
Remove-Item $tempDir -Recurse -Force

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Upload to CurseForge: https://www.curseforge.com/wow/addons/suaviui"
Write-Host "2. Select file: $outputZip"
Write-Host "3. Mark as release version"
