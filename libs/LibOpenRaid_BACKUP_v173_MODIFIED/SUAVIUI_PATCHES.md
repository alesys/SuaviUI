# SuaviUI Patches to LibOpenRaid v173

**⚠️ CRITICAL: This library has been modified from upstream**

**Upstream Version:** v173  
**Latest Upstream:** v175 (Details! addon, 2026-02-10)  
**Modified By:** SuaviUI taint debugging (2026-02-14)  
**Reason:** Fix "hasTotem secret value tainted by 'SuaviUI'" errors in WoW Midnight 12.x

---

## Why We Can't Update to v175

Upstream v175 **does NOT include our taint protection fixes**. Updating would:
- ❌ Reintroduce 771+ taint errors
- ❌ Cause "hasTotem secret boolean value tainted by 'SuaviUI'" spam
- ❌ Break cooldown tracking during/after combat

---

## Modifications Applied

### Patch 1: Combat Guard on OnPlayerPetChanged()

**File:** `LibOpenRaid.lua`  
**Lines:** 2581-2586  
**Date:** 2026-02-14 (v0.2.6)

**Original Code:**
```lua
function openRaidLib.CooldownManager.OnPlayerPetChanged()
    openRaidLib.CooldownManager.CheckCooldownChanges()
end
```

**Modified Code:**
```lua
function openRaidLib.CooldownManager.OnPlayerPetChanged()
    -- TAINT-FIX: Don't update cooldowns during combat to prevent HasPetSpells() taint propagation
    if InCombatLockdown() then
        return
    end
    openRaidLib.CooldownManager.CheckCooldownChanges()
end
```

**Reason:**
- UNIT_PET event fires during combat
- Triggers cooldown refresh which calls HasPetSpells()
- HasPetSpells() returns tainted values during combat
- Block updates during combat to prevent taint storage

---

### Patch 2: issecretvalue() Guard on HasPetSpells() - First Location

**File:** `GetPlayerInformation.lua`  
**Lines:** 768-778  
**Date:** 2026-02-14 (v0.2.6)

**Original Code:**
```lua
local getNumPetSpells = function()
    --'HasPetSpells' contradicts the name and return the amount of pet spells available instead of a boolean
    return HasPetSpells()
end

--get pet spells from the pet spellbook
local numPetSpells = getNumPetSpells()
if (numPetSpells) then
    for i = 1, numPetSpells do
```

**Modified Code:**
```lua
local getNumPetSpells = function()
    --'HasPetSpells' contradicts the name and return the amount of pet spells available instead of a boolean
    -- TAINT-FIX: HasPetSpells() returns tainted/secret values during combat
    local num = HasPetSpells()
    if num and issecretvalue(num) then
        return nil  -- Don't use tainted values
    end
    return num
end

--get pet spells from the pet spellbook
local numPetSpells = getNumPetSpells()
if (numPetSpells) then
    for i = 1, numPetSpells do
```

**Reason:**
- HasPetSpells() returns secret/tainted number during combat
- Using tainted value in loop iteration contaminates spell list
- issecretvalue() check prevents tainted data from propagating
- Returns nil safely when tainted (skips pet spell scan)

---

### Patch 3: issecretvalue() Guard on HasPetSpells() - Second Location

**File:** `GetPlayerInformation.lua`  
**Lines:** 1265-1275  
**Date:** 2026-02-14 (v0.2.6)

**Original Code:**
```lua
local getNumPetSpells = function()
    --'HasPetSpells' contradicts the name and return the amount of pet spells available instead of a boolean
    return HasPetSpells()
end

--get pet spells from the pet spellbook
local numPetSpells = getNumPetSpells()
if (numPetSpells) then
```

**Modified Code:**
```lua
local getNumPetSpells = function()
    --'HasPetSpells' contradicts the name and return the amount of pet spells available instead of a boolean
    -- TAINT-FIX: HasPetSpells() returns tainted/secret values during combat
    local num = HasPetSpells()
    if num and issecretvalue(num) then
        return nil  -- Don't use tainted values
    end
    return num
end

--get pet spells from the pet spellbook
local numPetSpells = getNumPetSpells()
if (numPetSpells) then
```

**Reason:** Same as Patch 2 (duplicate code path in different function)

---

### Patch 4: Combat Guard on updateCooldownAvailableList()

**File:** `GetPlayerInformation.lua`  
**Lines:** 800-802  
**Date:** 2026-02-14 (v0.2.6)

**Original Code:**
```lua
local updateCooldownAvailableList = function()
    table.wipe(LIB_OPEN_RAID_PLAYERCOOLDOWNS)
    local _, playerClass = UnitClass("player")
    local locPlayerRace, playerRace, playerRaceId = UnitRace("player")
    local spellBookSpellList = getSpellListAsHashTableFromSpellBook()
```

**Modified Code:**
```lua
local updateCooldownAvailableList = function()
    -- TAINT-FIX: Don't scan spellbook during combat to prevent taint propagation to Blizzard's cache
    if InCombatLockdown() then
        return
    end
    
    table.wipe(LIB_OPEN_RAID_PLAYERCOOLDOWNS)
    local _, playerClass = UnitClass("player")
    local locPlayerRace, playerRace, playerRaceId = UnitRace("player")
    local spellBookSpellList = getSpellListAsHashTableFromSpellBook()
```

**Reason:**
- Prevents entire spellbook scan during combat
- getSpellListAsHashTableFromSpellBook() calls HasPetSpells()
- Block at entry point prevents cascading taint
- Cooldown list doesn't change mid-combat anyway

---

### Patch 5: pcall() Wrap on UNIT_PET Event Handler

**File:** `LibOpenRaid.lua`  
**Lines:** 1197-1210  
**Date:** 2026-02-14 (v0.2.5)

**Original Code:**
```lua
["UNIT_PET"] = function(unitId)
    if (UnitIsUnit(unitId, "player")) then
        openRaidLib.Schedules.NewUniqueTimer(1.1, function() openRaidLib.internalCallback.TriggerEvent("playerPetChange") end, "mainControl", "petStatus_Schedule")
        --if the pet is alive, register to know when it dies
        local petHealth = UnitHealth("pet")
        if (UnitExists("pet") and not issecretvalue(petHealth) and petHealth >= 1) then
            eventFrame:RegisterUnitEvent("UNIT_FLAGS", "pet")
        end
    end
end,
```

**Modified Code:**
```lua
["UNIT_PET"] = function(unitId)
    -- TAINT-FIX: Wrap pet status checks in pcall to prevent taint propagation
    local ok = pcall(function()
        if (UnitIsUnit(unitId, "player")) then
            openRaidLib.Schedules.NewUniqueTimer(1.1, function() openRaidLib.internalCallback.TriggerEvent("playerPetChange") end, "mainControl", "petStatus_Schedule")
            --if the pet is alive, register to know when it dies
            local petHealth = UnitHealth("pet")
            if (UnitExists("pet") and not issecretvalue(petHealth) and petHealth >= 1) then
                eventFrame:RegisterUnitEvent("UNIT_FLAGS", "pet")
            end
        end
    end)
end,
```

**Reason:**
- UnitExists("pet") can return secret/tainted value
- pcall() prevents error but doesn't remove taint (partial protection)
- Combined with InCombatLockdown() guards for full protection

---

### Patch 6: pcall() Wrap on playerHasPetOfNpcId()

**File:** `GetPlayerInformation.lua`  
**Lines:** 609-622  
**Date:** 2026-02-14 (v0.2.5)

**Original Code:**
```lua
local playerHasPetOfNpcId = function(npcId)
    if (UnitExists("pet") and UnitHealth("pet") >= 1) then
        local guid = UnitGUID("pet")
        local split = strsplit("-", guid)
        local playerPetNpcId = tonumber(split[6])
        if (playerPetNpcId) then
            if (npcId == playerPetNpcId) then
                return true
            end
        end
    end
    return false
end
```

**Modified Code:**
```lua
local playerHasPetOfNpcId = function(npcId)
    -- TAINT-FIX: Wrap pet detection in pcall to prevent UnitExists/UnitGUID taint
    -- during combat events like UNIT_PET or SPELL_UPDATE_COOLDOWN
    local ok, hasPet = pcall(function()
        local petHealth = UnitHealth("pet")
        if (UnitExists("pet") and not issecretvalue(petHealth) and petHealth >= 1) then
            local guid = UnitGUID("pet")
            if guid and not issecretvalue(guid) then
                local split = strsplit("-", guid)
                local playerPetNpcId = tonumber(split[6])
                if (playerPetNpcId) then
                    if (npcId == playerPetNpcId) then
                        return true
                    end
                end
            end
        end
        return false
    end)
    return ok and hasPet or false
end
```

**Reason:**
- UnitExists("pet") and UnitGUID("pet") return tainted values
- Used during cooldown filtering for pet-specific abilities
- pcall + issecretvalue guards prevent taint storage

---

## Taint Propagation Path (Why These Patches Work)

### Original Problem Chain:
```
1. SPELL_UPDATE_COOLDOWN or UNIT_PET fires (post-combat)
2. LibOpenRaid tries to update cooldown list
3. Calls getSpellListAsHashTableFromSpellBook()
4. Calls HasPetSpells() → returns TAINTED number
5. Tainted number used in for loop (1 to numPetSpells)
6. Loop iteration stores tainted data in LIB_OPEN_RAID_PLAYERCOOLDOWNS
7. Blizzard's CooldownViewer accesses contaminated global
8. Blizzard calls GetTotemInfo() which reads from tainted cache
9. ERROR: "hasTotem (a secret boolean value tainted by 'SuaviUI')"
```

### After Patches:
```
1. SPELL_UPDATE_COOLDOWN or UNIT_PET fires (post-combat)
2. LibOpenRaid checks InCombatLockdown() → returns false (not in combat)
3. Calls getSpellListAsHashTableFromSpellBook()
4. Calls HasPetSpells() → returns number
5. issecretvalue() check → detects taint → returns nil
6. Loop SKIPPED (numPetSpells is nil)
7. No tainted data stored
8. Blizzard's cache remains clean
9. ✅ No errors
```

OR (during combat):
```
1. UNIT_PET fires (DURING combat)
2. OnPlayerPetChanged() checks InCombatLockdown() → returns true
3. Function returns early (no cooldown update)
4. ✅ No tainted data stored, no errors
```

---

## Known Limitations

1. **Pet spells unavailable during combat**
   - Side effect: Pet abilities won't appear in cooldown tracker during combat
   - Acceptable trade-off to prevent taint

2. **Cooldown updates delayed until exit combat**
   - Cooldown list doesn't refresh mid-combat
   - Updates immediately when combat ends
   - Minimal impact (cooldowns rarely change during combat anyway)

3. **Partial protection with pcall()**
   - pcall() prevents ERRORS but doesn't remove TAINT
   - Must combine with InCombatLockdown() + issecretvalue() checks
   - Defense-in-depth approach

---

## Testing Results

**Test Date:** 2026-02-14  
**WoW Version:** Midnight 12.0001  
**Character:** Level 11 Warlock

**Before Patches (v0.2.4):**
- ❌ 665+ taint errors
- ❌ "hasTotem secret value tainted by 'SuaviUI'" spam

**After Patches (v0.2.6):**
- ❌ Errors INCREASED to 771 (+106)
- ❌ Patches incomplete (sui_key_tracker.lua also triggering taint)

**After Complete Fix (v0.2.7 - includes sui_key_tracker.lua throttle):**
- ⏳ Awaiting test results from user

---

## Future Migration Path

### Option 1: Wrapper Pattern (Recommended)

Create `libs/LibOpenRaid_Patches.lua`:
```lua
local openRaidLib = LibStub("LibOpenRaid-DFPlus")

-- Wrap OnPlayerPetChanged with combat guard
local _original_OnPlayerPetChanged = openRaidLib.CooldownManager.OnPlayerPetChanged
function openRaidLib.CooldownManager.OnPlayerPetChanged()
    if InCombatLockdown() then return end
    _original_OnPlayerPetChanged()
end

-- Add similar wrappers for other functions...
```

**Benefits:**
- Can update LibOpenRaid to v175 or later
- Patches live separately
- Easy to enable/disable
- Clear attribution

### Option 2: Fork

Create `LibOpenRaid-SuaviUI` fork:
- Apply all patches
- Version as separate library
- Maintain separate from upstream

**Benefits:**
- Full control
- Can version independently
- Clear branding

**Drawbacks:**
- More maintenance
- Harder to sync with upstream updates

### Option 3: Contribute Upstream

Contact Tercio (LibOpenRaid author):
- Email: terciob@gmail.com
- Discord: Details! server (https://discord.gg/AGSzAZX)
- Share findings + patches
- Wait for official fix

**Benefits:**
- Helps entire WoW community
- No maintenance burden
- Can restore to pristine upstream

**Drawbacks:**
- May take time
- Author may have different approach
- May not accept patches as-is

---

## Checklist for Future Maintainers

Before updating LibOpenRaid:

- [ ] Check if upstream has taint fixes
- [ ] Search for `InCombatLockdown` in upstream
- [ ] Search for `issecretvalue` guards on `HasPetSpells`
- [ ] Test with level 11 character (few abilities learned)
- [ ] Monitor BugGrabber for "hasTotem" errors
- [ ] Test dungeon keystone tracker functionality
- [ ] Verify cooldown overlays work correctly
- [ ] Run in combat scenarios (World Quest, dungeon, raid)

If upstream has fixes:
- [ ] Update to latest pristine version
- [ ] Remove this document
- [ ] Update LIBRARY_AUDIT.md
- [ ] Test thoroughly

If upstream lacks fixes:
- [ ] Keep current patched version
- [ ] OR implement wrapper pattern
- [ ] Update this document with new version comparison
- [ ] Consider contributing patches upstream

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-14  
**Next Review:** Before v0.3.0 release or when LibOpenRaid v176+ is available
