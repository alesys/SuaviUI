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
- `.claude/` - Claude AI context files
- `.busted` - Busted test runner config
- `spec/` - Test specs
- `mocks/` - Test mocks
- `*_BACKUP*` - Backup folders (e.g., `LibOpenRaid_BACKUP_v173_MODIFIED/`)
- `package.ps1` - Build/packaging script
- `ACE3_UPDATE_REPORT.txt` - Development report
- `SUAVIUI_PATCHES.md` - Internal documentation
- `DEBUG_*.lua` - Debugging scripts

**Files INCLUDED in ZIP:**
- All Lua files (`utils/`, `imports/`, `libs/`, `skinning/`)
- All XML files (`load.xml`, `Bindings.xml`, embeds, etc.)
- All assets (`assets/textures/`, `assets/fonts/`, `assets/cursor/`, etc.)
- Localization files (`Locales/`)
- `SuaviUI.toc` (addon metadata)

#### Step 5: Publish GitHub Release
**IMPORTANT:** Run from the AddOns folder where the ZIP file is located!

```bash
cd "E:\Games\World of Warcraft\_retail_\Interface\AddOns"

# Delete any existing release (to handle re-releases):
gh release delete vX.X.X --repo alesys/SuaviUI --yes 2>/dev/null

# Create new release with ZIP file attached:
gh release create vX.X.X "SuaviUI-vX.X.X.zip" \
  --title "SuaviUI vX.X.X - [Edition Name]" \
  --notes "[Release notes markdown]" \
  --repo alesys/SuaviUI
```

**Key Points:**
- ✅ ZIP file MUST be specified as argument to upload it to the release
- ✅ ZIP file path is RELATIVE to current directory (must be in AddOns folder)
- ✅ Without the ZIP file path, only auto-generated source archives are created (NO addon package!)
- ✅ `--clobber` optional flag if you need to replace an existing asset

**Release Notes Template:**
```markdown
## 🎮 SuaviUI vX.X.X - [Edition Name]

### ✨ Major Features
- **Feature 1**: Description
- **Feature 2**: Description

### 🔧 Fixes & Improvements
- Fixed issue with [component]
- Improved [functionality]
- Added [enhavisible in release assets (not just "Source code" auto-archives)
- ✅ ZIP file size appropriate (~2-3 MB, without docs/ and backup folders)
- ✅ Tag pushed to GitHub: `git tag --list | grep vX.X.X`
- ✅ Commit pushed to master branch: `git log --oneline -1`

**Common Issues:**
- ❌ "Release has no assets" or only "Source code" archives → ZIP file path was wrong in Step 5
- ❌ ZIP file too large (>5 MB) → Backup folders or docs/ were included
- ❌ "release not found" error → Release was created as tag-only, not proper release
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

**IMPORTANT**: Do NOT use `Compress-Archive -Path $files.FullName` — it flattens the
directory structure, losing the `SuaviUI/` root folder and duplicating files at the
top level. Use robocopy staging instead:

```powershell
cd "e:\Games\World of Warcraft\_retail_\Interface\AddOns"

# Remove old ZIP if exists
if (Test-Path "SuaviUI-vX.X.X.zip") { Remove-Item "SuaviUI-vX.X.X.zip" }

# Stage a clean copy via robocopy (preserves folder structure)
$staging = "$env:TEMP\SuaviUI-release"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

# /E = recursive, /XD = exclude dirs, /XF = exclude files
robocopy "SuaviUI" "$staging\SuaviUI" /E /NFL /NDL /NJH /NJS /NC /NS `
    /XD docs .git .github .previews .claude spec mocks "*_BACKUP*" `
    /XF .gitignore .pkgmeta .wowup_ignore .copilot-instructions.md `
        SuaviUI.code-workspace error.log .DS_Store DS_Store .busted `
        package.ps1 ACE3_UPDATE_REPORT.txt SUAVIUI_PATCHES.md DEBUG_*.lua

# Create ZIP from staging (SuaviUI/ is the root folder inside the archive)
Compress-Archive -Path "$staging\SuaviUI" -DestinationPath "SuaviUI-vX.X.X.zip" -Force

# Cleanup staging
Remove-Item $staging -Recurse -Force

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

### ❌ CRITICAL: Release has no addon ZIP file
**Symptoms:** Release page shows only "Source code (zip)" and "Source code (tar.gz)", no `SuaviUI-vX.X.X.zip` asset

**Cause:** ZIP file path was missing or wrong in Step 5 command

**Solution:**
```powershell
cd "E:\Games\World of Warcraft\_retail_\Interface\AddOns"
gh release delete vX.X.X --repo alesys/SuaviUI --yes
gh release create vX.X.X "SuaviUI-vX.X.X.zip" --title "..." --notes "..." --repo alesys/SuaviUI
```

### Release Already Exists
- Delete existing release first: `gh release delete vX.X.X --repo alesys/SuaviUI --yes`
- Then create new release with Step 5 command
- Or increment version number and retry
- [ ] Automated changelog generation from git commits
- [ ] CurseForge CLI integration
- [ ] WowUp automatic upload
- [ ] Version bump automation in .toc file
