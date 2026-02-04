# SuaviUI Release Process

## Overview
This document describes the complete automated release workflow for SuaviUI. The entire process is handled by AI assistant commands - no manual steps required.

## Release Workflow

### 1. Pre-Release
- Ensure all code changes are tested and ready
- Version number should be updated in `SuaviUI.toc` (line 9: `## Version: X.X.X`)
- Review changes with `git status` to verify what will be committed

### 2. Automated Release Steps
The AI assistant performs the following steps in order:

#### Step 1: Git Commit
```bash
git add .
git commit -m "Release vX.X.X: [brief description of changes]"
```

#### Step 2: Create Git Tag
```bash
git tag -a vX.X.X -m "Release vX.X.X"
```

#### Step 3: Push to GitHub
```bash
git push origin master
git push origin vX.X.X
```

#### Step 4: Create Release ZIP
- Location: Parent folder of addon (`e:\Games\World of Warcraft\_retail_\Interface\AddOns\`)
- Filename: `SuaviUI-vX.X.X.zip`
- Size: ~5-6 MB (clean package without dev files)

**Files EXCLUDED from ZIP:**
- `docs/` - All development documentation
- `.git/`, `.github/` - Git metadata
- `.gitignore`, `.pkgmeta`, `.wowup_ignore` - Config files
- `.copilot-instructions.md` - AI instructions
- `SuaviUI.code-workspace` - VS Code workspace
- `error.log` - Runtime error log
- `.DS_Store` - macOS metadata
- `DS_Store` - macOS metadata (without dot)
- `.previews/` - Screenshot previews

**Files INCLUDED in ZIP:**
- All Lua files (`utils/`, `imports/`, `libs/`, `skinning/`)
- All XML files (`load.xml`, `Bindings.xml`, embeds, etc.)
- All assets (`assets/textures/`, `assets/fonts/`, `assets/cursor/`, etc.)
- Localization files (`Locales/`)
- `SuaviUI.toc` (addon metadata)

#### Step 5: Publish GitHub Release
```bash
gh release create vX.X.X "..\SuaviUI-vX.X.X.zip" \
  --title "SuaviUI vX.X.X - [Edition Name]" \
  --notes "[Release notes markdown]" \
  --repo alesys/SuaviUI
```

**Release Notes Template:**
```markdown
## 🎮 SuaviUI vX.X.X - [Edition Name]

### ✨ Major Features
- **Feature 1**: Description
- **Feature 2**: Description

### 🔧 Fixes & Improvements
- Fixed issue with [component]
- Improved [functionality]
- Added [enhancement]

### 📦 Package Notes
- Excludes development documentation (docs/ folder)
- Clean release with only runtime files
- Compatible with The War Within (Interface 120000-120001)

### 🙏 Credits
Special thanks to our testers: Vela, Pataz, and Ñora for their feedback and testing!
```

### 3. Verification
After release, verify:
- ✅ GitHub release published: `https://github.com/alesys/SuaviUI/releases/tag/vX.X.X`
- ✅ ZIP file created in parent folder with correct size (~5-6 MB)
- ✅ Tag pushed to GitHub
- ✅ Commit pushed to master branch

## File Exclusion System

### .pkgmeta (CurseForge Packaging)
```yaml
package-as: SuaviUI
enable-nolib-creation: no

ignore:
    - .git
    - .github
    - .gitignore
    - .copilot-instructions.md
    - docs
    - README.md
    - .pkgmeta
    - .wowup_ignore
```

### .wowup_ignore (WowUp Packaging)
```
.git/
.github/
docs/
README.md
.copilot-instructions.md
.gitignore
.wowup_ignore
```

### .gitignore (Development)
```
# VS Code workspace
SuaviUI.code-workspace

# Release artifacts
SuaviUI.zip

# macOS metadata files
.DS_Store
**/.DS_Store
```

## PowerShell Command Reference

### Create Release ZIP (Manual)
```powershell
cd "e:\Games\World of Warcraft\_retail_\Interface\AddOns"

# Remove old ZIP if exists
if (Test-Path "SuaviUI-vX.X.X.zip") { Remove-Item "SuaviUI-vX.X.X.zip" }

# Define exclusions
$exclude = @('docs', '.git', '.github', '.gitignore', '.pkgmeta', '.wowup_ignore', 
             '.copilot-instructions.md', 'SuaviUI.code-workspace', 'error.log', 
             '.DS_Store', 'DS_Store', '.previews')

# Get files excluding specified paths
$files = Get-ChildItem -Path "SuaviUI" -Recurse | Where-Object { 
    $skip = $false
    foreach ($ex in $exclude) { 
        if ($_.FullName -like "*\$ex\*" -or $_.Name -eq $ex) { 
            $skip = $true
            break 
        } 
    }
    -not $skip 
}

# Create ZIP
Compress-Archive -Path $files.FullName -DestinationPath "SuaviUI-vX.X.X.zip" -Force

# Verify
if (Test-Path "SuaviUI-vX.X.X.zip") { 
    Write-Host "✓ Release ZIP created successfully" -ForegroundColor Green
    Write-Host "Size: $([math]::Round((Get-Item 'SuaviUI-vX.X.X.zip').Length / 1MB, 2)) MB"
}
```

## Version History

### v0.1.5 - Edit Mode Edition (February 2, 2026)
- Edit Mode Integration with LibEQOLEditMode
- Castbar Mixin System for in-place updates
- Action Bar improvements (EAB/Zone Ability)
- Size: 5.79 MB

## Notes for AI Assistant

When user requests a release:
1. Check git status
2. Add all changes
3. Commit with descriptive message
4. Create annotated tag
5. Push commit + tag to origin
6. Create ZIP in parent folder with exclusions
7. Publish GitHub release with formatted notes
8. Verify all steps completed successfully

**Do not ask for confirmation** - execute the full workflow automatically.

## Troubleshooting

### ZIP Creation Fails
- Ensure parent directory exists
- Check PowerShell execution policy
- Verify file permissions

### Git Push Fails
- Check GitHub authentication
- Verify remote repository URL: `git remote -v`
- Ensure network connectivity

### Release Already Exists
- Delete existing release on GitHub first
- Or increment version number and retry

## Future Enhancements
- [ ] Automated changelog generation from git commits
- [ ] CurseForge CLI integration
- [ ] WowUp automatic upload
- [ ] Version bump automation in .toc file
