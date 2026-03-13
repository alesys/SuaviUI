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
- Size: ~2 MB (clean package without dev files, .venv, docs, spec)

**Files EXCLUDED from ZIP:**
- `docs/` - All development documentation
- `dev/` - All development scripts, debug files, and backups (`package.ps1`, `DEBUG_*.lua`, `TEST_*.lua`, `*_backup.lua`, `ACE3_UPDATE_REPORT.txt`, `error.log`, etc.)
- `spec/` - Test specs (and `spec/mocks/`)
- `.git/`, `.github/` - Git metadata
- `.venv/` - Python virtual environment (development tooling)
- `.vscode/` - VS Code workspace settings
- `.claude/` - Claude AI context files
- `.previews/` - Screenshot previews
- `.gitignore`, `.pkgmeta`, `.wowup_ignore` - Packaging/CI config files
- `.copilot-instructions.md` - AI instructions
- `.busted` - Busted test runner config
- `SuaviUI.code-workspace` - VS Code workspace file
- `.DS_Store`, `DS_Store` - macOS metadata
- `*_BACKUP*` - Backup folders (e.g., `LibOpenRaid_BACKUP_v173_MODIFIED/`)
- `SUAVIUI_PATCHES.md` - Internal documentation

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
- ✅ ZIP file size appropriate (~2 MB, without docs/, dev/, .venv/, spec/, and backup folders)
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
- ✅ ZIP file created in parent folder with correct size (~2 MB)
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
    - .busted
    - .venv
    - .vscode
    - .claude
    - .previews
    - docs
    - dev
    - spec
    - README.md
    - .pkgmeta
    - .wowup_ignore
    - SuaviUI.code-workspace
    - SUAVIUI_PATCHES.md
```

### .wowup_ignore (WowUp Packaging)
```
.git/
.github/
.venv/
.vscode/
.claude/
.previews/
docs/
dev/
spec/
README.md
.copilot-instructions.md
.gitignore
.wowup_ignore
.busted
SuaviUI.code-workspace
SUAVIUI_PATCHES.md
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
    /XD docs dev .git .github .previews .claude spec .venv .vscode "*_BACKUP*" `
    /XF .gitignore .pkgmeta .wowup_ignore .copilot-instructions.md `
        SuaviUI.code-workspace .DS_Store DS_Store .busted SUAVIUI_PATCHES.md

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

### v0.3.15 - Taint Fix Edition (March 13, 2026)
- CDM taint fix: replaced all HookScript on CDM viewers with hooksecurefunc (taint-safe)
- CDM taint fix: removed HookScript("OnUpdate/OnShow/OnSizeChanged") from buff bar/icon viewers
- CDM taint fix: separate addon-owned polling frame for legacy skinning (50ms interval)
- CDM taint fix: restored SetSize with InCombatLockdown + Edit Mode guards
- Fixed pcall multi-return bug: GetBuffBarFrames only returned first child (all bars after first unskinned)
- Same pcall fix applied to cooldownmanager.lua ViewerAdapters and CooldownManagerCentered
- Combat lockdown guards: EnableMouse, SetFrameLevel, SetFrameStrata, extraActionButton Hide
- Deferred pending table for extraActionButton combat hide (processed on PLAYER_REGEN_ENABLED)
- Added automated release script (dev/release.sh)
- Size: ~2 MB

### v0.3.14 - Character Flyout Edition (March 9, 2026)
- Character flyout ilvl overlay: item level on Alt-hover equipment flyout buttons
- Rewrote flyout ilvl lookup (hook UpdateItems, GetContainerItemInfo hyperlink) — no more cache misses
- Buffbar combat taint fix: guard EnableMouse calls with InCombatLockdown()
- GUI form widget labels: SetJustifyH("LEFT") across all widget types
- Character stats: showTooltips default (off)
- Size: ~2.06 MB

### v0.3.13 - Edit Mode Settings Edition (March 6, 2026)
- Settings migrated from Options GUI to Edit Mode panels (CDM, Action Bars, Minimap, Unit Frames)
- GUI builder pattern refactor (WrapBuilder, lazy page builders)
- New Pill/Circle UI widgets, character panel accent pips and section backgrounds
- Size: ~2 MB

### v0.3.12 - Legacy Skinning Edition (March 6, 2026)
- Tracked bars: legacy path (USE_CUSTOM_BARS=false), skin Blizzard viewers in place
- Tracked icons: legacy path (USE_CUSTOM_ICONS=false), remove ForcePopulate taint, show stack counts
- Size: ~2 MB

### v0.3.11 - Taint Purge Edition (March 5, 2026)
- CDM frame-field taint purge complete
- Action bars re-enabled after full weak-table migration
- C API data pipeline for tracked bars
- Size: 2.05 MB (after correcting .venv/.vscode/dev/ exclusions)

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
