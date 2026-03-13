#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SuaviUI Release Script
# Automates: git commit + tag + push + ZIP creation + GitHub release
# Usage: ./dev/release.sh <version> <edition> [notes-file]
# Example: ./dev/release.sh 0.3.15 "Taint Fix Edition" dev/RELEASE_NOTES.md
# =============================================================================

REPO="alesys/SuaviUI"
ADDON_NAME="SuaviUI"

# Resolve paths (script is in dev/, addon root is parent)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADDONS_DIR="$(cd "${ADDON_DIR}/.." && pwd)"

# Exclusion lists (must match RELEASE_PROCESS.md)
EXCLUDE_DIRS=(docs dev .git .github .previews .claude spec .venv .vscode '*_BACKUP*')
EXCLUDE_FILES=(.gitignore .pkgmeta .wowup_ignore .copilot-instructions.md SuaviUI.code-workspace .DS_Store DS_Store .busted SUAVIUI_PATCHES.md)

# =============================================================================
# Helper functions
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

error() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
warn()  { echo -e "${YELLOW}WARNING: $1${NC}"; }
info()  { echo -e "${GREEN}$1${NC}"; }
step()  { echo -e "\n${CYAN}${BOLD}==> $1${NC}"; }

confirm() {
    local prompt="$1"
    local reply
    echo -en "${BOLD}${prompt} [y/N]: ${NC}"
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Convert Unix path to Windows path for PowerShell
win_path() {
    if command -v cygpath &>/dev/null; then
        cygpath -w "$1"
    else
        echo "$1" | sed 's|^/\([a-zA-Z]\)/|\1:\\|; s|/|\\|g'
    fi
}

# =============================================================================
# Parse arguments
# =============================================================================

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <version> <edition> [notes-file]"
    echo ""
    echo "  version    Semantic version (e.g., 0.3.15 or v0.3.15)"
    echo "  edition    Edition name (e.g., \"Taint Fix Edition\")"
    echo "  notes-file Optional: path to release notes markdown file"
    echo ""
    echo "Examples:"
    echo "  $0 0.3.15 \"Taint Fix Edition\""
    echo "  $0 0.3.15 \"Taint Fix Edition\" dev/RELEASE_NOTES.md"
    exit 1
fi

# Strip leading 'v' if present
VERSION="${1#v}"
EDITION="$2"
NOTES_FILE="${3:-}"

# Validate version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Invalid version format: '$VERSION'. Expected X.Y.Z (e.g., 0.3.15)"
fi

TAG="v${VERSION}"
ZIP_NAME="${ADDON_NAME}-${TAG}.zip"
RELEASE_TITLE="${ADDON_NAME} ${TAG} - ${EDITION}"

# =============================================================================
# Environment checks
# =============================================================================

step "Checking environment"

command -v git &>/dev/null || error "git not found. Install git first."
command -v gh &>/dev/null || error "gh CLI not found. Install from https://cli.github.com/"
command -v powershell.exe &>/dev/null || error "powershell.exe not found (required for ZIP creation on Windows)."

# Verify gh authentication
if ! gh auth status &>/dev/null 2>&1; then
    error "GitHub CLI not authenticated. Run: gh auth login"
fi
info "gh authenticated"

# Verify we're in the right directory
if [[ ! -f "${ADDON_DIR}/SuaviUI.toc" ]]; then
    error "SuaviUI.toc not found in ${ADDON_DIR}. Run this script from the addon directory."
fi

# Check branch
BRANCH=$(git -C "${ADDON_DIR}" branch --show-current)
if [[ "$BRANCH" != "master" ]]; then
    warn "Currently on branch '${BRANCH}', not 'master'."
    confirm "Continue anyway?" || exit 0
fi

info "Environment OK (branch: ${BRANCH})"

# =============================================================================
# State validation
# =============================================================================

step "Validating release state"

# 1. TOC version must match
TOC_VERSION=$(grep '## Version:' "${ADDON_DIR}/SuaviUI.toc" | sed 's/.*## Version:[[:space:]]*//' | tr -d '[:space:]')
if [[ "$TOC_VERSION" != "$VERSION" ]]; then
    error "TOC version mismatch: SuaviUI.toc says '${TOC_VERSION}' but you requested '${VERSION}'.\nUpdate SuaviUI.toc line 9 first."
fi
info "TOC version matches: ${VERSION}"

# 2. Local tag must not exist
if git -C "${ADDON_DIR}" tag --list "${TAG}" | grep -q "${TAG}"; then
    error "Local tag '${TAG}' already exists. Delete with: git tag -d ${TAG}"
fi

# 3. Remote tag must not exist
if git -C "${ADDON_DIR}" ls-remote --tags origin "${TAG}" 2>/dev/null | grep -q "${TAG}"; then
    error "Remote tag '${TAG}' already exists on origin. Use a different version or delete it first."
fi
info "Tag ${TAG} is available"

# 4. Check for existing GitHub release
if gh release view "${TAG}" --repo "${REPO}" &>/dev/null 2>&1; then
    warn "GitHub release '${TAG}' already exists."
    if confirm "Delete existing release and recreate?"; then
        gh release delete "${TAG}" --repo "${REPO}" --yes
        info "Deleted existing release ${TAG}"
    else
        error "Cannot create release — ${TAG} already exists on GitHub."
    fi
fi

# 5. Check working tree
CHANGES=$(git -C "${ADDON_DIR}" status --porcelain)
if [[ -z "$CHANGES" ]]; then
    warn "Working tree is clean — nothing new to commit."
    confirm "Continue with tag-only release?" || exit 0
    SKIP_COMMIT=true
else
    SKIP_COMMIT=false
    echo "Files to commit:"
    echo "$CHANGES" | sed 's/^/  /'
fi

# 6. Check for existing ZIP
WIN_ADDONS_DIR=$(win_path "${ADDONS_DIR}")
if [[ -f "${ADDONS_DIR}/${ZIP_NAME}" ]]; then
    warn "ZIP file already exists: ${ZIP_NAME}"
    # Will be overwritten during build
fi

# 7. Resolve release notes
if [[ -n "$NOTES_FILE" ]]; then
    if [[ ! -f "${ADDON_DIR}/${NOTES_FILE}" ]] && [[ ! -f "$NOTES_FILE" ]]; then
        error "Notes file not found: ${NOTES_FILE}"
    fi
    # Resolve to absolute path
    if [[ -f "${ADDON_DIR}/${NOTES_FILE}" ]]; then
        NOTES_FILE="${ADDON_DIR}/${NOTES_FILE}"
    fi
    NOTES_SOURCE="file: ${NOTES_FILE}"
elif [[ -f "${ADDON_DIR}/dev/RELEASE_NOTES.md" ]]; then
    NOTES_FILE="${ADDON_DIR}/dev/RELEASE_NOTES.md"
    NOTES_SOURCE="file: dev/RELEASE_NOTES.md (auto-detected)"
else
    NOTES_FILE=""
    NOTES_SOURCE="auto-generated from git log"
fi

# =============================================================================
# Summary
# =============================================================================

step "Release Summary"
echo -e "  Version:     ${BOLD}${VERSION}${NC}"
echo -e "  Tag:         ${BOLD}${TAG}${NC}"
echo -e "  Edition:     ${BOLD}${EDITION}${NC}"
echo -e "  Title:       ${RELEASE_TITLE}"
echo -e "  Branch:      ${BRANCH}"
echo -e "  TOC version: ${TOC_VERSION} (verified)"
echo -e "  ZIP output:  ${ADDONS_DIR}/${ZIP_NAME}"
echo -e "  Notes:       ${NOTES_SOURCE}"
echo -e "  Repo:        ${REPO}"
echo ""

# =============================================================================
# Step 1: Git commit + tag
# =============================================================================

if [[ "$SKIP_COMMIT" == false ]]; then
    step "Step 1: Git commit + tag"
    confirm "Create commit and tag?" || exit 0

    cd "${ADDON_DIR}"
    # Stage all tracked modifications (safe — won't add untracked files)
    git add -u
    git commit -m "$(cat <<EOF
Release ${TAG}: ${EDITION}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
    info "Commit created: $(git log --oneline -1)"
else
    step "Step 1: Tag only (no new commit)"
fi

cd "${ADDON_DIR}"
git tag -a "${TAG}" -m "Release ${TAG}"
info "Tag created: ${TAG}"

# =============================================================================
# Step 2: Push to origin
# =============================================================================

step "Step 2: Push to origin"
if confirm "Push commit and tag to origin/${BRANCH}?"; then
    git push origin "${BRANCH}"
    git push origin "${TAG}"
    info "Pushed to origin/${BRANCH} + ${TAG}"
else
    warn "Skipped push. Run manually later:"
    echo "  git push origin ${BRANCH} && git push origin ${TAG}"
fi

# =============================================================================
# Step 3: Create release ZIP
# =============================================================================

step "Step 3: Create release ZIP"

WIN_ADDON_DIR=$(win_path "${ADDON_DIR}")
WIN_ADDONS_DIR=$(win_path "${ADDONS_DIR}")

# Build robocopy /XD arguments
XD_ARGS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    XD_ARGS+=" $dir"
done

# Build robocopy /XF arguments
XF_ARGS=""
for file in "${EXCLUDE_FILES[@]}"; do
    XF_ARGS+=" $file"
done

info "Building ZIP via robocopy + Compress-Archive..."

powershell.exe -NoProfile -Command "
    \$ErrorActionPreference = 'Stop'
    \$staging = Join-Path \$env:TEMP 'SuaviUI-release'
    if (Test-Path \$staging) { Remove-Item \$staging -Recurse -Force }

    # robocopy: exit codes 0-7 are success, 8+ are errors
    robocopy '${WIN_ADDON_DIR}' \"\$staging\\SuaviUI\" /E /NFL /NDL /NJH /NJS /NC /NS /XD${XD_ARGS} /XF${XF_ARGS}
    if (\$LASTEXITCODE -ge 8) {
        Write-Error \"robocopy failed with exit code \$LASTEXITCODE\"
        exit 1
    }

    \$zipPath = '${WIN_ADDONS_DIR}\\${ZIP_NAME}'
    if (Test-Path \$zipPath) { Remove-Item \$zipPath -Force }
    Compress-Archive -Path \"\$staging\\SuaviUI\" -DestinationPath \$zipPath -Force
    Remove-Item \$staging -Recurse -Force

    if (Test-Path \$zipPath) {
        \$size = [math]::Round((Get-Item \$zipPath).Length / 1MB, 2)
        Write-Host \"ZIP created: \$zipPath (\${size} MB)\"
        if (\$size -gt 5) { Write-Warning 'ZIP is >5MB — check exclusions!' }
        if (\$size -lt 0.5) { Write-Warning 'ZIP is <500KB — something may be missing!' }
    } else {
        Write-Error 'ZIP creation failed!'
        exit 1
    }
" || error "ZIP creation failed"

# Verify ZIP exists from bash side
if [[ ! -f "${ADDONS_DIR}/${ZIP_NAME}" ]]; then
    error "ZIP file not found at: ${ADDONS_DIR}/${ZIP_NAME}"
fi
ZIP_SIZE=$(powershell.exe -NoProfile -Command "[math]::Round((Get-Item '${WIN_ADDONS_DIR}\\${ZIP_NAME}').Length / 1MB, 2)")
info "ZIP ready: ${ZIP_NAME} (${ZIP_SIZE} MB)"

# =============================================================================
# Step 4: Publish GitHub release
# =============================================================================

step "Step 4: Publish GitHub release"

# Generate release notes if no file provided
if [[ -z "$NOTES_FILE" ]]; then
    GENERATED_NOTES=$(cat <<NOTES_EOF
## SuaviUI ${TAG} - ${EDITION}

### Changes
$(git -C "${ADDON_DIR}" log --oneline "$(git -C "${ADDON_DIR}" describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo HEAD~10)..HEAD~1" | sed 's/^/- /')

### Credits
Special thanks to our testers: Vela, Pataz, and Nora for their feedback and testing!
NOTES_EOF
)
    echo "Generated release notes:"
    echo "---"
    echo "$GENERATED_NOTES"
    echo "---"
fi

confirm "Publish GitHub release with ZIP?" || {
    warn "Skipped publish. You can publish manually:"
    echo "  cd \"${ADDONS_DIR}\" && gh release create ${TAG} \"${ZIP_NAME}\" --title \"${RELEASE_TITLE}\" --repo ${REPO}"
    exit 0
}

cd "${ADDONS_DIR}"

# Delete pre-existing release (just in case)
gh release delete "${TAG}" --repo "${REPO}" --yes 2>/dev/null || true

if [[ -n "$NOTES_FILE" ]]; then
    gh release create "${TAG}" "${ZIP_NAME}" \
        --title "${RELEASE_TITLE}" \
        --notes-file "${NOTES_FILE}" \
        --repo "${REPO}"
else
    gh release create "${TAG}" "${ZIP_NAME}" \
        --title "${RELEASE_TITLE}" \
        --notes "${GENERATED_NOTES}" \
        --repo "${REPO}"
fi

info "GitHub release published!"

# =============================================================================
# Step 5: Verification
# =============================================================================

step "Verification"

# Check release exists and has the ZIP asset
RELEASE_INFO=$(gh release view "${TAG}" --repo "${REPO}" 2>&1 || true)
if echo "$RELEASE_INFO" | grep -q "${ZIP_NAME}"; then
    info "ZIP asset verified in release"
else
    warn "Could not verify ZIP asset in release. Check manually."
fi

RELEASE_URL="https://github.com/${REPO}/releases/tag/${TAG}"

echo ""
echo -e "${GREEN}${BOLD}=== Release ${TAG} complete! ===${NC}"
echo -e "  Release: ${RELEASE_URL}"
echo -e "  ZIP:     ${ADDONS_DIR}/${ZIP_NAME} (${ZIP_SIZE} MB)"
echo -e "  Commit:  $(git -C "${ADDON_DIR}" log --oneline -1)"
echo ""
