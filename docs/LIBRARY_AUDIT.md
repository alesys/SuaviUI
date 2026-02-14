# SuaviUI Library Audit & Update Strategy

**Date:** 2026-02-14 (Updated after library refresh)
**Audit Reason:** Taint issues with LibOpenRaid led to investigation of all embedded libraries  
**Latest Update:** All libraries updated to latest pristine versions (2026-02-14)

---

## Current Library Inventory

| Library | Current Version | Last Modified | Status | Notes |
|---------|----------------|---------------|--------|-------|
| **LibOpenRaid** | **v175** | **2026-02-14** | ✅ **PRISTINE** | **Restored from Details! - removed all taint patches** |
| AceAddon-3.0 | r13 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| AceComm-3.0 | r14 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| **AceConfig-3.0** | **v3** | **2026-02-14** | ✅ **ADDED** | **New - from AccWideUILayoutSelection** |
| AceConsole-3.0 | r7 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| AceDB-3.0 | r33 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| **AceDBOptions-3.0** | **v15** | **2026-02-14** | ✅ **ADDED** | **New - from AccWideUILayoutSelection** |
| AceEvent-3.0 | r4 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| AceLocale-3.0 | r6 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| CallbackHandler-1.0 | r8 | 2026-02-01 | ✅ OK | Standard Ace3 (latest) |
| LibCustomGlow-1.0 | r21 | 2026-02-01 | ✅ OK | External lib (latest) |
| LibDataBroker-1.1 | r4 | 2026-02-05 | ✅ OK | Standard (latest) |
| LibDBIcon-1.0 | r55 | 2026-02-05 | ✅ OK | Standard (latest) |
| LibDeflate | 1.0.2-release | 2026-02-01 | ✅ OK | Used for compression (latest) |
| **LibDualSpec-1.0** | **r28** | **2026-02-14** | ✅ **UPDATED** | **Spec switching (r27→r28 from BigWigs)** |
| LibEQOL | Unknown | 2026-02-01 | ✅ OK | Edit Mode integration |
| LibKeyBound-1.0 | r126 (v1.04) | 2026-02-01 | ✅ OK | Keybind system (latest) |
| **LibSerialize** | **r5** | **2026-02-14** | ✅ **ADDED** | **New - from SenseiClassResourceBar** |
| **LibSharedMedia-3.0** | **r164** (v8.x) | **2026-02-14** | ✅ **UPDATED** | **Media registry (r151→r164 from WeakAuras)** |
| LibStub | r2 | 2026-02-01 | ✅ OK | Core library loader (latest) |

**Total Libraries:** 19 (was 16)  
**Updates Applied:** 5 (LibOpenRaid restored, LibSharedMedia updated, LibDualSpec updated, 3 libraries added)

---

## ⚠️ BREAKING CHANGE: LibOpenRaid v175 Pristine

### What Changed (2026-02-14 Library Refresh)

**REMOVED ALL TAINT PATCHES:**
- ❌ `InCombatLockdown()` guard in `OnPlayerPetChanged()` - REMOVED
- ❌ `issecretvalue()` guards on `HasPetSpells()` (both locations) - REMOVED  
- ❌ `InCombatLockdown()` guard on `updateCooldownAvailableList()` - REMOVED
- ❌ All `pcall()` wrapping in UNIT_PET handler - REMOVED

**Result:** SuaviUI now uses 100% pristine upstream LibOpenRaid v175

### Backup Location
Modified v173 backed up to: `libs/LibOpenRaid_BACKUP_v173_MODIFIED/`

### Expected Impact
⚠️ **Taint errors will likely return** - 771+ "hasTotem secret value tainted by 'SuaviUI'" errors may reappear

### Why We Did This
Following proper library management practices:
1. ✅ Never modify external library code directly
2. ✅ Keep libraries pristine for easy updates
3. ✅ Use wrapper pattern if fixes are needed
4. ✅ Clear attribution and maintainability

### Next Steps if Taint Returns
If taint errors reappear after testing:
1. Create `libs/LibOpenRaid_Patches.lua` wrapper
2. Hook/wrap problematic functions without modifying library
3. Document patches in separate file
4. Keep LibOpenRaid v175 pristine

---

## Critical Issue: LibOpenRaid Modifications (HISTORICAL - v0.2.6-v0.2.7)

> **NOTE:** These modifications have been REMOVED as of 2026-02-14 library refresh.
> LibOpenRaid is now pristine v175. Backup of modified v173 available in `LibOpenRaid_BACKUP_v173_MODIFIED/`

### What We Modified (v0.2.6 - v0.2.7) - HISTORICAL RECORD

**Files Modified:**
1. `libs/LibOpenRaid/LibOpenRaid.lua`
   - Line 2581-2586: Added `InCombatLockdown()` guard to `OnPlayerPetChanged()`

2. `libs/LibOpenRaid/GetPlayerInformation.lua`
   - Lines 768-778: Added `issecretvalue()` guard to `HasPetSpells()` (first location)
   - Lines 1265-1275: Added `issecretvalue()` guard to `HasPetSpells()` (second location)
   - Line 800-802: Added `InCombatLockdown()` guard to `updateCooldownAvailableList()`

**Reason for Modifications:**
- `HasPetSpells()` returns tainted values during combat in WoW Midnight 12.x
- Tainted values contaminated Blizzard's CooldownViewer cache
- Result: 771+ "hasTotem secret value tainted by 'SuaviUI'" errors

### Comparison with Upstream

**Details! (LibOpenRaid v175 - 2026-02-10):**
- ❌ NO `InCombatLockdown()` guards
- ❌ NO `issecretvalue()` guards on `HasPetSpells()`
- 2 versions ahead BUT lacks our taint protection

**Conclusion:** Upstream v175 would REINTRODUCE all taint errors we just fixed.

---

## Problem: Direct Library Modification (Anti-Pattern)

### Why This Is Bad

1. **Update Conflicts:** Cannot update LibOpenRaid without losing fixes
2. **Maintenance Burden:** Must manually merge future upstream changes
3. **Code Attribution:** Modifications not clearly documented in code
4. **Testing Complexity:** Hard to isolate library vs. addon issues
5. **Community Contribution:** Can't easily share fixes with upstream

### Proper Approaches (Ranked by Preference)

#### Option 1: **Wrapper/Adapter Pattern** (RECOMMENDED)
- Create `libs/LibOpenRaid_Patches.lua` to wrap problematic functions
- Hook or override tainted functions with protected versions
- Keep upstream library pristine
- Easy to update, easy to contribute back

**Example:**
```lua
-- libs/LibOpenRaid_Patches.lua
local openRaidLib = LibStub("LibOpenRaid-DFPlus")

-- Save original function
local _original_OnPlayerPetChanged = openRaidLib.CooldownManager.OnPlayerPetChanged

-- Override with protected version
function openRaidLib.CooldownManager.OnPlayerPetChanged()
    if InCombatLockdown() then return end
    _original_OnPlayerPetChanged()
end
```

#### Option 2: **Fork + Maintain Separate Repo**
- Fork LibOpenRaid to `LibOpenRaid-SuaviUI`
- Apply modifications
- Version as separate library
- Can contribute PRs back to upstream

**Cons:** More maintenance, harder to sync with upstream

#### Option 3: **Post-Load Hooks**
- Let library load normally
- Hook problematic functions after load
- Inject protection logic

**Cons:** Race conditions, harder to debug

#### Option 4: **Report to Upstream + Wait**
- File issue/PR with Tercio (LibOpenRaid author)
- Email: terciob@gmail.com
- Discord: Details! server (https://discord.gg/AGSzAZX)

**Cons:** May take time, author may have different approach

---

## Recommended Action Plan

### Immediate (This Session)

1. ✅ **Keep Current v173 with modifications** (already done)
   - Reason: v175 upstream lacks our critical fixes
   - Risk of reintroducing 771+ taint errors

2. ⏳ **Document modifications in-code** (TODO)
   - Add clear comments: `-- SUAVIUI-PATCH: ...`
   - Document reason, date, version

3. ⏳ **Create patch manifest** (TODO)
   - Document all modifications in `libs/LibOpenRaid/SUAVIUI_PATCHES.md`
   - Include original code, modified code, reason

### Short-term (Next Update)

4. **Implement Wrapper Pattern**
   - Create `libs/LibOpenRaid_Patches.lua`
   - Move protection logic to wrapper
   - Restore original LibOpenRaid v175
   - Test thoroughly

5. **Update Other Libraries**
   - Check for Ace3 updates
   - Update LibSharedMedia if needed
   - Update LibDBIcon if needed

### Long-term

6. **Contribute Back to Upstream**
   - Contact Tercio with taint findings
   - Propose InCombatLockdown guards
   - Share test cases for Midnight 12.x taint

7. **Monitor for Official Fix**
   - Watch LibOpenRaid repository
   - Check Details! addon for updates
   - Transition back when upstream has fix

---

## Other Libraries Assessment

### Ace3 Suite
- **Status:** ✅ Stable, widely used, well-maintained
- **Action:** No immediate update needed
- **Future:** Check WoWAce for updates quarterly

### LibSharedMedia-3.0
- **Status:** ✅ Version r151 is recent
- **Action:** No update needed

### LibDBIcon-1.0
- **Status:** ✅ Version r55 is current
- **Action:** No update needed

### LibCustomGlow-1.0
- **Status:** ✅ Version r21 is current
- **Action:** No update needed

### LibEQOL (LibEQOLEditMode)
- **Status:** ⚠️ Custom library for Edit Mode
- **Action:** Check for updates from creator/fork source

### LibDeflate
- **Status:** ⚠️ Version unknown
- **Action:** Check version, consider updating

---

## Version Control Strategy

### Current State
```
libs/
├── LibOpenRaid/          ← MODIFIED (v173 + patches)
├── AceAddon-3.0/         ← PRISTINE
├── AceDB-3.0/            ← PRISTINE
└── ... (other libs)      ← PRISTINE
```

### Target State (After Refactor)
```
libs/
├── LibOpenRaid/                ← PRISTINE (v175 or latest)
├── LibOpenRaid_Patches.lua     ← OUR PATCHES (documented)
├── AceAddon-3.0/               ← PRISTINE
└── ... (other libs)            ← PRISTINE
```

---

## Decision Record

### Decision: Keep Modified LibOpenRaid v173 (For Now)
- **Date:** 2026-02-14
- **Reason:** v175 upstream lacks critical taint fixes
- **Risk:** Update conflicts, maintenance burden
- **Mitigation:** Document all changes, plan wrapper refactor

### Next Decision Point
- **When:** Before v0.3.0 release
- **Question:** Implement wrapper pattern or fork library?
- **Dependencies:** Test results from v0.2.7, upstream response

---

## Testing Notes

**Before ANY library update:**
1. Test with level 11 Warlock (original freeze scenario)
2. Monitor BugGrabber for taint errors
3. Test dungeon keystone tracker
4. Test rotation assist
5. Verify cooldown overlays work correctly

**Acceptance Criteria:**
- ✅ No UI freeze
- ✅ No taint errors in BugGrabber
- ✅ All features functional
- ✅ Performance acceptable

---

## References

- LibOpenRaid Upstream: Details! addon by Tercio
- Discord: https://discord.gg/AGSzAZX
- Email: terciob@gmail.com
- WoWAce Libraries: https://www.wowace.com/projects/ace3
- LibStub Documentation: http://www.wowace.com/addons/libstub/

---

**Last Updated:** 2026-02-14  
**Next Review:** Before v0.3.0 or when upstream LibOpenRaid updates
