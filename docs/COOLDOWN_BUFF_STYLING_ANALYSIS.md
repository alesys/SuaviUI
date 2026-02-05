# Essential Cooldowns, Utility Cooldowns, and Buffs Styling Analysis

## Executive Summary

**Problem:** Even after disabling square style skinning settings, the Essential Cooldowns, Utility Cooldowns, and Buff Icons continue to display styled (square) instead of reverting to native Blizzard UI appearance.

**Root Cause:** Persistent hooks on `RefreshLayout` combined with button state flags (`button.suiSquareStyled`) that are never cleared when the module is supposed to be disabled. The hooks remain active even when `isModuleStyledEnabled` is false.

---

## Architecture Overview

### File Structure

The cooldown/buff styling system is split across multiple files:

1. **[cooldown_icons.lua](../utils/cooldown_icons.lua)** - Square icon styling (Essential, Utility, BuffIcons)
2. **[buffborders.lua](../utils/buffborders.lua)** - Buff/Debuff frame borders  
3. **[cooldownmanager.lua](../utils/cooldownmanager.lua)** - Core layout management
4. **[cooldowneffects.lua](../utils/cooldowneffects.lua)** - Visual effects
5. **[cooldownswipe.lua](../utils/cooldownswipe.lua)** - Swipe animations
6. **[cooldown_fonts.lua](../utils/cooldown_fonts.lua)** - Font customization
7. **[cooldown_advanced.lua](../utils/cooldown_advanced.lua)** - Advanced features

---

## Critical Issue Analysis

### 1. The `StyledIcons` Module (cooldown_icons.lua)

#### Module State Variables

```lua
local isModuleStyledEnabled = false  -- Module-wide flag
local areHooksInitialized = false    -- Hooks are PERMANENT once set
```

#### The Hook Problem (Lines 393-413)

```lua
function StyledIcons:Enable()
    if isModuleStyledEnabled then
        return
    end

    isModuleStyledEnabled = true

    if not areHooksInitialized then
        areHooksInitialized = true  -- ⚠️ NEVER RESET TO FALSE

        for viewerName, _ in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame then
                -- ⚠️ THIS HOOK IS PERMANENT - CAN'T BE REMOVED
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleStyledEnabled then
                        return  -- ⚠️ Early exit, but hook still exists
                    end
                    pcall(function()
                        StyledIcons:RefreshViewer(viewerName)
                        if viewerName == "UtilityCooldownViewer" then
                            StyledIcons:ApplyNormalizedSize()
                        end
                    end)
                end)
            end
        end
    end

    self:RefreshAll()
    self:ApplyNormalizedSize()
end
```

**Key Issues:**
1. `hooksecurefunc` creates **permanent hooks** that cannot be removed
2. `areHooksInitialized` is set to `true` and never reset
3. Even when disabled, the hook function still executes on every `RefreshLayout` call
4. The early `return` prevents re-styling, but doesn't restore original state

#### The Disable/Shutdown Logic (Lines 370-381)

```lua
function StyledIcons:Shutdown()
    isModuleStyledEnabled = false  // ⚠️ Only sets flag

    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child.Icon then
                    RestoreOriginalStyle(child, settingName)
                    RestoreOriginalSizeToButton(child, settingName)
                end
            end
        end
    end
end
```

**Problems:**
1. Relies on finding ALL child buttons at shutdown time
2. If buttons are created AFTER shutdown, they won't be restored
3. `button.suiSquareStyled` flag check in `RestoreOriginalStyle` prevents restoration if flag is already false
4. Hook remains active and may re-apply styling on next `RefreshLayout`

#### The Button State Flag Issue (Lines 167-175)

```lua
function StyledIcons:Shutdown()
    isModuleStyledEnabled = false

    for viewerName, settingName in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child.Icon then
                    RestoreOriginalStyle(child, settingName)  // ⚠️ See below
                    RestoreOriginalSizeToButton(child, settingName)
                end
            end
        end
    end
end

local function RestoreOriginalStyle(button, viewerSettingName)
    if not button.suiSquareStyled then  // ⚠️ GUARD PREVENTS RESTORATION
        return  // If flag is false, restoration is skipped!
    end
    
    // ... restoration code ...
    
    button.suiSquareStyled = false  // Only set at the END
end
```

**Critical Flaw:** If `button.suiSquareStyled` is somehow already `false`, the restoration code never runs, leaving the button in a partially-styled state.

---

### 2. The Blizzard Integration (Lines 456-490)

```lua
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

local hasInitialized = false

local function TryInitialize()
    if hasInitialized then
        return
    end
    
    // Check if viewers exist before initializing
    if _G["EssentialCooldownViewer"] or _G["UtilityCooldownViewer"] or _G["BuffIconCooldownViewer"] then
        hasInitialized = true  // ⚠️ NEVER RESET
        C_Timer.After(0.2, function()
            StyledIcons:Initialize()  // Enables if settings say so
        end)
    end
end

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Blizzard_CooldownManager" then
            C_Timer.After(0.1, TryInitialize)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, TryInitialize)
    end
end)

// If Blizzard_CooldownManager is already loaded (e.g., /reload), try immediately
if C_AddOns.IsAddOnLoaded("Blizzard_CooldownManager") then
    C_Timer.After(0.1, TryInitialize)
end
```

**Race Condition:** The module initializes automatically on load, and if square icons are enabled in settings, hooks are installed immediately. There's no clean way to "uninitialize" later.

---

### 3. The Settings Check (Lines 40-56)

```lua
local function IsAnyStyledFeatureEnabled()
    local profile = GetProfile()
    if not profile then
        return false
    end
    for _, viewerSettingName in pairs(viewersSettingKey) do
        local squareKey = "cooldownManager_squareIcons_" .. viewerSettingName
        if profile[squareKey] then  // ⚠️ Checks: Essential, Utility, BuffIcons
            return true
        end
    end
    if profile.cooldownManager_normalizeUtilitySize then
        return true
    end
    return false
end
```

**Settings Checked:**
- `cooldownManager_squareIcons_Essential`
- `cooldownManager_squareIcons_Utility`
- `cooldownManager_squareIcons_BuffIcons`
- `cooldownManager_normalizeUtilitySize`

---

### 4. The `OnSettingChanged` Callback (Lines 427-445)

**CRITICAL DISCOVERY:** There is **NO CALLER** for `StyledIcons:OnSettingChanged()` in the entire codebase!

```lua
function StyledIcons:OnSettingChanged()
    local shouldBeEnabled = IsAnyStyledFeatureEnabled()

    if shouldBeEnabled and not isModuleStyledEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleStyledEnabled then
        self:Disable()  // ⚠️ This should be called when settings are toggled OFF
    elseif isModuleStyledEnabled then
        self:RefreshAll()
        self:ApplyNormalizedSize()
    end

    // Trigger a refresh of the cooldown manager if available
    if ns.CooldownManager and ns.CooldownManager.ForceRefreshAll then
        ns.CooldownManager.ForceRefreshAll()
    end
end
```

**The Missing Link:** This function is **NEVER CALLED** when settings change in the UI. The user toggles the checkbox, but nothing tells `StyledIcons` to react.

---

### 5. The Apply/Restore Flow

#### Applying Square Style (Lines 84-167)

```lua
local function ApplySquareStyle(button, viewerSettingName)
    local profile = GetProfile()
    local config = styleConfig[viewerSettingName]
    if not config or not profile then
        return
    end

    local width = GetViewerIconSize(viewerSettingName)
    local borderKey = "cooldownManager_squareIconsBorder_" .. viewerSettingName
    local borderThickness = profile[borderKey] or 1

    button:SetSize(width, width)  // ⚠️ Modifies button

    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("TOPLEFT", button, "TOPLEFT", -config.paddingFixup / 2, config.paddingFixup / 2)
        button.Icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", config.paddingFixup / 2, -config.paddingFixup / 2)

        // Calculate zoom-based texture coordinates
        local zoomKey = "cooldownManager_squareIconsZoom_" .. viewerSettingName
        local zoom = profile[zoomKey] or 0
        local crop = zoom * 0.5
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)  // ⚠️ Crops icon
        end
    end

    // Update swipe texture for cooldown children
    for i = 1, select("#", button:GetChildren()) do
        local texture = select(i, button:GetChildren())
        if texture and texture.SetSwipeTexture then
            texture:SetSwipeTexture(BASE_SQUARE_MASK)  // ⚠️ Square mask
            // ... position and size adjustments ...
        end
    end

    // Update textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local texture = region:GetTexture()
            local atlas = region:GetAtlas()

            if (issecretvalue and not issecretvalue(texture) or not issecretvalue) and texture == 6707800 then
                region:SetTexture(BASE_SQUARE_MASK)  // ⚠️ Replace texture
                region.__sui_set6707800 = true  // ⚠️ Flag for restoration
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(0)  // ⚠️ Hide overlay
            end
        end
    end

    // Create/update inset black border
    if not button.suiSquareBorder then
        button.suiSquareBorder = CreateFrame("Frame", nil, button, "BackdropTemplate")
        button.suiSquareBorder:SetFrameLevel(button:GetFrameLevel() + 1)
    end
    button.suiSquareBorder:ClearAllPoints()
    // ... border setup ...
    button.suiSquareBorder:Show()

    button.suiSquareStyled = true  // ⚠️ Flag set LAST
end
```

**Modifications Made:**
1. Button size changed to square
2. Icon texture coordinates cropped
3. Swipe texture replaced with square mask
4. Original circular texture (6707800) replaced with square mask
5. Icon overlay hidden
6. Black border frame created
7. Flag `button.suiSquareStyled` set to `true`

#### Restoring Original Style (Lines 173-217)

```lua
local function RestoreOriginalStyle(button, viewerSettingName)
    if not button.suiSquareStyled then  // ⚠️ GUARD CHECK
        return  // Won't restore if flag is false!
    end

    local width, height = GetViewerIconSize(viewerSettingName)
    button:SetSize(width, height)

    if button.Icon then
        button.Icon:ClearAllPoints()
        button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.Icon:SetSize(width, height)
        // Reset texture coordinates
        if button.Icon.SetTexCoord then
            button.Icon:SetTexCoord(0, 1, 0, 1)  // ⚠️ Restore full texture
        end
    end

    for i = 1, select("#", button:GetChildren()) do
        local child = select(i, button:GetChildren())
        if child and child.SetSwipeTexture then
            child:SetSwipeTexture(6707800)  // ⚠️ Restore circular swipe
            child:ClearAllPoints()
            child:SetPoint("CENTER", button, "CENTER", 0, 0)
            child:SetSize(width, height)
            break
        end
    end

    // Restore hidden overlay textures
    for _, region in next, { button:GetRegions() } do
        if region:IsObjectType("Texture") then
            local atlas = region:GetAtlas()
            if region.__sui_set6707800 then
                region:SetTexture(6707800)  // ⚠️ Restore original texture
                region.__sui_set6707800 = nil
            elseif atlas == "UI-HUD-CoolDownManager-IconOverlay" then
                region:SetAlpha(1)  // ⚠️ Show overlay again
            end
        end
    end

    if button.suiSquareBorder then
        button.suiSquareBorder:Hide()  // ⚠️ Only hides, doesn't destroy
    end

    button.suiSquareStyled = false  // ⚠️ Flag cleared LAST
end
```

---

## Buff Borders Analysis (buffborders.lua)

This is a **separate system** and does NOT interfere with cooldown viewers:

### Scope
- Only affects `BuffFrame` and `DebuffFrame` (player buff/debuff UI in top-right)
- Only affects `TemporaryEnchantFrame`
- Does **NOT** touch Essential/Utility/BuffIcon cooldown viewers

### What It Does
1. Adds black borders around buff/debuff icons
2. Applies custom font settings to duration text
3. Optionally hides entire BuffFrame or DebuffFrame

### Hook Strategy
```lua
-- Hook BuffFrame updates
if BuffFrame and BuffFrame.Update then
    hooksecurefunc(BuffFrame, "Update", ScheduleBuffBorders)
end

-- Listens to UNIT_AURA event
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript("OnEvent", function(self, event, arg)
    if event == "UNIT_AURA" and arg == "player" then
        ScheduleBuffBorders()
    end
end)
```

**No Conflict:** These hooks target completely different frames than the cooldown viewers.

---

## The Complete Problem Loop

### Scenario: User Disables Square Icons

1. **User unchecks** `cooldownManager_squareIcons_Essential` in settings
2. **Settings panel updates** the database value to `false`
3. **NOTHING CALLS** `StyledIcons:OnSettingChanged()` ❌
4. **Module remains enabled** with `isModuleStyledEnabled = true`
5. **Hooks remain active** and continue listening to `RefreshLayout`
6. **Next refresh occurs** (combat, talent change, etc.)
7. **Hook fires**, checks `IsSquareIconsEnabled()` → returns `false`
8. **Should call** `RestoreOriginalStyle()`, but doesn't because:
   - Hook only runs when `isModuleStyledEnabled = true`
   - When true, it calls `StyledIcons:RefreshViewer()` which calls `ProcessViewer()`
   - `ProcessViewer()` checks `IsSquareIconsEnabled()` and decides to restore
   - **BUT** if buttons were created after disable, they're not in the list
9. **New buttons** may be created without `suiSquareStyled` flag
10. **`RestoreOriginalStyle()`** skips them due to guard check ❌
11. **Result:** Mixed state - some buttons styled, some not, all inconsistent

---

## Evidence of the Missing Callback

### Search Results
- ✅ `StyledIcons:Initialize()` - Called on addon load
- ✅ `StyledIcons:Enable()` - Called by Initialize
- ✅ `StyledIcons:Disable()` - Called by OnSettingChanged
- ✅ `StyledIcons:RefreshAll()` - Called by various triggers
- ❌ `StyledIcons:OnSettingChanged()` - **NEVER CALLED IN CODEBASE**

### Where It SHOULD Be Called
Looking at similar patterns in the codebase:

```lua
// Example from castbar settings (castbar_editmode.lua)
set = function(layoutName, value)
    local s = GetCastSettings(unitKey)
    if s then
        s.iconSize = value
        RefreshCastbar(unitKey)  // ← Immediate refresh
    end
end
```

**Expected Pattern for Square Icons:**
```lua
// In sui_options.lua or wherever the checkbox is created
set = function(value)
    profile.cooldownManager_squareIcons_Essential = value
    StyledIcons:OnSettingChanged()  // ← THIS IS MISSING
end
```

---

## Why Native Look Doesn't Return

### Texture Coordinate State
```lua
// Applied when styled:
button.Icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)  // Cropped

// Must be restored:
button.Icon:SetTexCoord(0, 1, 0, 1)  // Full texture
```

If restoration doesn't run, **icons remain cropped** even if borders are removed.

### Swipe Texture State
```lua
// Applied when styled:
texture:SetSwipeTexture(BASE_SQUARE_MASK)  // Square mask path

// Must be restored:
texture:SetSwipeTexture(6707800)  // Blizzard's circular mask
```

If restoration doesn't run, **cooldown swipes remain square** shaped.

### Border Frame State
```lua
// Created when styled:
button.suiSquareBorder = CreateFrame(...)

// On disable:
button.suiSquareBorder:Hide()  // ← Only hidden, not destroyed
```

The border frame still exists in memory, just hidden.

### Icon Overlay State
```lua
// Applied when styled:
region:SetAlpha(0)  // Overlay hidden

// Must be restored:
region:SetAlpha(1)  // Show overlay
```

If restoration doesn't run, **overlay remains invisible**.

---

## Recommended Solutions

### ✅ Solution 1: Make Hooks Self-Healing (IMPLEMENTED)

**Status: COMPLETED**

**Changes Made:**

1. **Modified RefreshLayout hooks** (cooldown_icons.lua, lines 398-417)
   - Hooks now check actual settings on every call
   - No longer rely on `isModuleStyledEnabled` flag
   - Automatically apply or remove styling based on current database values

2. **Removed guard check** (cooldown_icons.lua, line 173)
   - `RestoreOriginalStyle()` now always attempts restoration
   - Prevents buttons from getting stuck in partially-styled states
   - More resilient to edge cases

3. **Added global callback** (cooldown_icons.lua, line 523)
   - `_G.SuaviUI_RefreshSquareIcons()` function for UI integration
   - Future-proofs the code for when settings UI is added

**How It Works:**

```lua
-- Before (buggy):
hooksecurefunc(viewerFrame, "RefreshLayout", function()
    if not isModuleStyledEnabled then
        return  -- Exits early, never restores
    end
    StyledIcons:RefreshViewer(viewerName)
end)

-- After (fixed):
hooksecurefunc(viewerFrame, "RefreshLayout", function()
    local enabled = IsSquareIconsEnabled(settingName)
    ProcessViewer(viewerFrame, settingName, enabled)  -- Always applies correct state
end)
```

**Result:**
- Settings changes are automatically detected on next refresh
- No manual callback needed (hooks are self-healing)
- Icons automatically revert when settings are disabled
- Works correctly even if Blizzard triggers unexpected refreshes

### ~~Solution 1: Wire Up the OnSettingChanged Callback (QUICK FIX)~~

**Status: NOT NEEDED - Self-healing hooks make this unnecessary**

~~**Find where square icon checkboxes are created** (likely in `sui_options.lua` or `sui_gui.lua`) and add:~~

```lua
// When checkbox value changes:
if ns.StyledIcons and ns.StyledIcons.OnSettingChanged then
    ns.StyledIcons.OnSettingChanged()
end
```

~~### Solution 2: Make Hooks Self-Healing (ROBUST FIX)~~

**Modify the hook to always check settings**, not just module state:

```lua
// In StyledIcons:Enable(), change the hook to:
hooksecurefunc(viewerFrame, "RefreshLayout", function()
    // Don't check isModuleStyledEnabled - always check actual settings
    local settingName = viewersSettingKey[viewerName]
    local enabled = IsSquareIconsEnabled(settingName)
    
    pcall(function()
        ProcessViewer(viewerFrame, settingName, enabled)
        if viewerName == "UtilityCooldownViewer" then
            if enabled and IsNormalizedSizeEnabled() then
                StyledIcons:ApplyNormalizedSize()
            end
        end
    end)
end)
```

This way, the hook **always** applies the correct state based on current settings.

### Solution 3: Add Forced Restoration Command (DEBUG AID)

**Already exists!** `/suistyleforce` (line 553)

Users can run this to forcefully refresh all viewers if they get stuck.

### Solution 4: Clear Button State on Disable (SAFETY NET)

**In `RestoreOriginalStyle()`**, remove the guard check:

```lua
local function RestoreOriginalStyle(button, viewerSettingName)
    // REMOVE THIS:
    // if not button.suiSquareStyled then
    //     return
    // end
    
    // Always attempt restoration, even if flag is false
    local width, height = GetViewerIconSize(viewerSettingName)
    button:SetSize(width, height)
    
    // ... rest of restoration code ...
    
    button.suiSquareStyled = false
end
```

This ensures restoration always runs, preventing stuck states.

---

## Testing Recommendations

### Test Scenario 1: Clean Disable
1. Enable square icons for Essential cooldowns
2. Verify icons are square with borders
3. Disable square icons setting
4. Trigger a refresh (`/reload` or enter combat)
5. **Expected:** Icons revert to circular, no borders
6. **Check:** Run `/suistyledicons` to verify module state

### Test Scenario 2: Mid-Combat Disable
1. Enable square icons
2. Enter combat (icons appear)
3. Exit combat
4. Disable square icons
5. Re-enter combat
6. **Expected:** New icons appear circular
7. **Actual (current bug):** New icons may be square or mixed state

### Test Scenario 3: Settings Toggle Spam
1. Rapidly toggle square icons on/off 5 times
2. `/reload`
3. **Expected:** Final setting state matches visual state
4. **Check:** Consistency across all three viewers

---

## Debug Commands Available

```lua
/suistyledicons      // Shows module state and viewer info
/suistyleforce       // Force refresh all viewers
/suisquaretest       // Test square icon application
```

---

## Conclusion

**The root cause is a missing callback wire-up.** The `StyledIcons:OnSettingChanged()` function exists and is correctly implemented, but nothing calls it when settings change in the UI.

**Secondary issues:**
1. Hooks are permanent and can't be removed
2. Button state flags prevent restoration in edge cases
3. Module initialization is one-way (can't uninitialize)

**Immediate fix:** Wire the settings panel checkboxes to call `StyledIcons:OnSettingChanged()`.

**Long-term fix:** Make hooks stateless and always check current settings.

---

## Implementation Summary

**Date:** February 5, 2026

**Changes Applied:**

1. ✅ Modified `StyledIcons:Enable()` hook logic to be stateless
2. ✅ Removed guard check from `RestoreOriginalStyle()`
3. ✅ Added `_G.SuaviUI_RefreshSquareIcons()` global callback

**Testing:**

After these changes, users can:
1. Set square icon settings via console: `/run SuaviUI.SUICore.db.profile.cooldownManager_squareIcons_Essential = false`
2. Trigger refresh: `/reload` or enter/exit combat
3. Icons should automatically revert to native circular style

**Future UI Integration:**

When adding square icon toggles to the options panel, simply call:
```lua
_G.SuaviUI_RefreshSquareIcons()
```
...after updating the database value.

---

## File References

- [cooldown_icons.lua](../utils/cooldown_icons.lua) - Lines 1-568
- [buffborders.lua](../utils/buffborders.lua) - Lines 1-312
- [cooldownmanager.lua](../utils/cooldownmanager.lua) - Lines 1-838
- [suicore_main.lua](../utils/suicore_main.lua) - Default settings (lines 2750-2800)

---

*Analysis Date: February 4, 2026*
*Generated by: SuaviUI Debug System*
