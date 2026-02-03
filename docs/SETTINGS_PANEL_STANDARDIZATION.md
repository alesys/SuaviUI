# Settings Panel Standardization Guide

## Executive Summary

This document outlines a complete standardization approach for all settings panels and dropdowns across SuaviUI, SenseiClassResourceBar, and CooldownManagerCentered. Currently, there are significant inconsistencies in:

1. **Dropdown Styling**: Some dropdowns use old-style appearance (button-like), others use modern style
2. **Texture Preview Implementation**: Some texture/statusbar dropdowns show texture previews; others don't
3. **Consistency Across Panels**: Different panels implement similar settings differently

**Goal**: Ensure every dropdown that has texture/visual content shows a preview, and all dropdowns maintain consistent styling.

---

## Current State Analysis

### 1. Edit Mode (LEM) Dropdowns

#### Panel: Castbar Edit Mode (`castbar_editmode.lua`)

**Dropdowns Found:**
- Line 373: Bar Texture (Anchor To) - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 433: Bar Texture - `values: GetTextureList()` - **NO PREVIEW**
- Line 474: Anchor To - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 718: Font Selection - `values: GetFontList()` - **NO PREVIEW**
- Line 877: Font Flags - `values: GetFontFlagsList()` - **NO PREVIEW**
- Line 970: Font Size - `values: FONT_SIZES` - **NO PREVIEW**
- Line 1099: Visibility - `values: VISIBILITY_OPTIONS` - **NO PREVIEW**

**Issues:**
- Bar Texture dropdown doesn't show texture preview (should show!)
- Font dropdown doesn't show font preview (optional but nice)
- All use simple `values` table with no custom generator

**Styling:** All use basic LEM.SettingType.Dropdown (no `useOldStyle`)

#### Panel: Unit Frames Edit Mode (`unitframes_editmode.lua`)

**Dropdowns Found:**
- Line 344: Anchor To - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 445: Bar Texture - `values: GetTextureList()` - **NO PREVIEW**
- Line 735: Anchor To - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 901: Anchor To - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 1101: Anchor To - `values: ANCHOR_OPTIONS` - **NO PREVIEW**
- Line 1149: Font - `values: GetFontList()` - **NO PREVIEW**
- Line 1358: Font Flags - `values: FONT_FLAGS_LIST` - **NO PREVIEW**
- Line 1389: Font Size - `values: FONT_SIZE_LIST` - **NO PREVIEW**
- Line 1599: Texture - `values: GetTextureList()` - **NO PREVIEW**
- Line 1623: Background Texture - `values: GetTextureList()` - **NO PREVIEW**

**Issues:**
- Multiple texture dropdowns without previews
- All use basic dropdown, no custom generators

**Styling:** Most use `useOldStyle: true` (button-like appearance)

#### Panel: Resource Bars Edit Mode (`resourcebars/LEMSettingsLoader.lua`)

**Dropdowns Found WITH Generators (GOOD!):**
- Line 402 (437): Bar Texture (Foreground) - `useOldStyle: true, height: 200` - **HAS PREVIEW** ✅
- Line 403 (511): Background Texture - `DropdownColor, useOldStyle: true, height: 200` - **HAS PREVIEW** ✅
- Line 689: Font - `useOldStyle: true, values: LSM fonts` - **NO PREVIEW**
- Line 714: Font Flags - **NO PREVIEW**
- Line 738: Font Size - **NO PREVIEW**
- Line 770: Alignment - **NO PREVIEW**
- Line 864: Anchor To - **NO PREVIEW**

**Good Examples:**
- Lines 437-510: Foreground texture dropdown with texture pool and AddInitializer for previews
- Lines 511-614: Background texture dropdown with DropdownColor type and color picker

**Issues:**
- Only foreground and background dropdowns have custom generators with previews
- Other texture/selection dropdowns are missing this

**Styling:** Uses `useOldStyle: true` and `height: 200` for scrollable dropdowns

#### SenseiClassResourceBar (`Helpers/LEMSettingsLoader.lua`)

**Implementation Pattern (BEST PRACTICE):**

The SenseiClassResourceBar addon implements the most complete version:

```lua
{
    kind = LEM.SettingType.DropdownColor,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        dropdown.texturePool = {}
        
        -- Hook cleanup
        if not dropdown._SCRB_Background_Dropdown_OnMenuClosed_hooked then
            hooksecurefunc(dropdown, "OnMenuClosed", function()
                for _, texture in pairs(dropdown.texturePool) do
                    texture:Hide()
                end
            end)
            dropdown._SCRB_Background_Dropdown_OnMenuClosed_hooked = true
        end
        
        -- Build menu with texture previews
        for index, textureName in ipairs(sortedTextures) do
            local texturePath = textures[textureName]
            local button = rootDescription:CreateButton(textureName, callback)
            
            if texturePath then
                button:AddInitializer(function(buttonFrame)
                    local preview = dropdown.texturePool[index]
                    if not preview then
                        preview = buttonFrame:CreateTexture(nil, "BACKGROUND")
                        dropdown.texturePool[index] = preview
                    end
                    preview:SetParent(buttonFrame)
                    preview:SetAllPoints(buttonFrame)
                    preview:SetTexture(texturePath)
                    preview:Show()
                end)
            end
        end
    end
}
```

**Features:**
- ✅ Custom generator function
- ✅ Texture pool for efficient rendering
- ✅ OnMenuClosed hook to hide textures
- ✅ AddInitializer to add previews to each button
- ✅ Proper spacing and sizing
- ✅ `useOldStyle: true` for consistent appearance

---

## Standardization Rules

### Rule 1: Dropdown Styling

**ALL texture/statusbar dropdowns MUST use:**
```lua
{
    useOldStyle = true,      -- Consistent button-like appearance
    height = 200,             -- Scrollable menu
    ...
}
```

**Rationale:**
- Old style maintains consistent visual appearance with resource bar style
- Height allows for large texture collections without visual clutter
- Matches current SenseiClassResourceBar implementation

### Rule 2: Texture Preview Implementation

**If a dropdown is for visual media (textures, statusbars, fonts), it MUST show a preview:**

#### For Statusbar/Texture Dropdowns:
```lua
{
    kind = LEM.SettingType.Dropdown,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        -- Initialize texture pool
        dropdown.texturePool = {}
        
        -- Hook cleanup
        if not dropdown._YourAddon_Cleanup_Hooked then
            hooksecurefunc(dropdown, "OnMenuClosed", function()
                for _, texture in pairs(dropdown.texturePool) do
                    texture:Hide()
                end
            end)
            dropdown._YourAddon_Cleanup_Hooked = true
        end
        
        -- Get sorted texture list
        local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
        local sortedTextures = {}
        for textureName in pairs(textures) do
            table.insert(sortedTextures, textureName)
        end
        table.sort(sortedTextures)
        
        -- Set current value as default text
        dropdown:SetDefaultText(settingObject.get(layoutName))
        
        -- Add each texture as a button with preview
        for index, textureName in ipairs(sortedTextures) do
            local texturePath = textures[textureName]
            
            local button = rootDescription:CreateButton(textureName, function()
                dropdown:SetDefaultText(textureName)
                settingObject.set(layoutName, textureName)
            end)
            
            -- Add texture preview to button
            if texturePath then
                button:AddInitializer(function(buttonFrame)
                    local preview = dropdown.texturePool[index]
                    if not preview then
                        preview = buttonFrame:CreateTexture(nil, "BACKGROUND")
                        dropdown.texturePool[index] = preview
                    end
                    
                    preview:SetParent(buttonFrame)
                    preview:SetAllPoints(buttonFrame)
                    preview:SetTexture(texturePath)
                    preview:Show()
                end)
            end
        end
    end,
    get = function(layoutName)
        -- Return current texture name
    end,
    set = function(layoutName, value)
        -- Set texture and apply
    end,
}
```

#### For DropdownColor (Texture + Color Picker):
Same as above but with:
```lua
{
    kind = LEM.SettingType.DropdownColor,  -- Includes color picker
    colorDefault = defaults.backgroundColor,
    colorGet = function(layoutName) ... end,
    colorSet = function(layoutName, r, g, b, a) ... end,
    ...
}
```

#### For Font Dropdowns (Optional but Recommended):
```lua
{
    kind = LEM.SettingType.Dropdown,
    useOldStyle = true,
    height = 300,  -- Font list can be long
    generator = function(dropdown, rootDescription, settingObject)
        local LSM = LibStub("LibSharedMedia-3.0")
        local fonts = LSM:HashTable(LSM.MediaType.FONT)
        local sortedFonts = {}
        for fontName in pairs(fonts) do
            table.insert(sortedFonts, fontName)
        end
        table.sort(sortedFonts)
        
        dropdown:SetDefaultText(settingObject.get(layoutName))
        
        for _, fontName in ipairs(sortedFonts) do
            local fontPath = fonts[fontName]
            
            local button = rootDescription:CreateButton(fontName, function()
                dropdown:SetDefaultText(fontName)
                settingObject.set(layoutName, fontName)
            end)
            
            -- Show font preview in button (optional)
            if fontPath then
                button:AddInitializer(function(buttonFrame)
                    local text = buttonFrame:GetFontString() or buttonFrame:CreateFontString(nil, "OVERLAY")
                    text:SetFont(fontPath, 12)
                    text:SetText(fontName)
                end)
            end
        end
    end,
    ...
}
```

#### For Simple Value Dropdowns (No Preview):
```lua
{
    kind = LEM.SettingType.Dropdown,
    useOldStyle = true,  -- Still use for consistency
    values = {
        {value = "opt1", text = "Option 1"},
        {value = "opt2", text = "Option 2"},
    },
    -- NO generator needed for simple dropdowns
}
```

### Rule 3: DropdownColor Type

**Use DropdownColor when:**
- Setting includes both a texture/style selection AND a color override
- Resource bar backgrounds (texture + background color)
- Any visual element where both style and color matter

**Implementation:**
```lua
{
    kind = LEM.SettingType.DropdownColor,
    useOldStyle = true,
    height = 200,
    generator = function(...) -- Add texture previews
    get = function(...) -- Return texture name
    set = function(...) -- Set texture
    colorGet = function(...) -- Return RGB color
    colorSet = function(..., r, g, b, a) -- Set RGBA color
}
```

### Rule 4: Dropdown Consistency Across Addons

**All three addons must follow the same pattern:**
1. SuaviUI (Master pattern setter)
2. SenseiClassResourceBar (Already implements best practice)
3. CooldownManagerCentered (Uses different system - TBD)

---

## Implementation Checklist

### For Texture/Statusbar Dropdowns

- [ ] Add `useOldStyle = true`
- [ ] Add `height = 200` for scrollable menu
- [ ] Create `generator` function
- [ ] Initialize `dropdown.texturePool = {}`
- [ ] Add `OnMenuClosed` hook to hide textures
- [ ] Get LSM texture hashtable
- [ ] Sort texture names alphabetically
- [ ] Set default text from `settingObject.get()`
- [ ] Create button for each texture
- [ ] Add texture preview via `AddInitializer`
- [ ] Call `SetDefaultText()` on selection
- [ ] Call `settingObject.set()` on selection

### For DropdownColor Dropdowns

- [ ] Follow texture dropdown pattern above
- [ ] Add `colorDefault = defaults.bgColor`
- [ ] Add `colorGet = function(layoutName)` to return current color
- [ ] Add `colorSet = function(layoutName, r, g, b, a)` to set color
- [ ] Ensure color picker is visible alongside texture selector

### For Simple Value Dropdowns

- [ ] Add `useOldStyle = true`
- [ ] Create ordered `values` table
- [ ] Provide meaningful text labels
- [ ] No generator needed

---

## Files Requiring Updates

### SuaviUI

**High Priority (Needs Texture Previews):**
1. [castbar_editmode.lua](castbar_editmode.lua#L433) - Line 433: Bar Texture dropdown
2. [unitframes_editmode.lua](unitframes_editmode.lua#L445) - Line 445: Bar Texture dropdown
3. [unitframes_editmode.lua](unitframes_editmode.lua#L1599) - Line 1599: Unit texture dropdown
4. [unitframes_editmode.lua](unitframes_editmode.lua#L1623) - Line 1623: Background texture dropdown

**Medium Priority (Font Previews - Optional):**
5. [castbar_editmode.lua](castbar_editmode.lua#L718) - Line 718: Font selection
6. [unitframes_editmode.lua](unitframes_editmode.lua#L1149) - Line 1149: Font selection

**Low Priority (Just Consistency):**
7. All non-texture dropdowns should use `useOldStyle = true`

### SenseiClassResourceBar

**Status: ✅ Already implements best practice**
- Uses proper generators
- Shows texture previews
- Uses `useOldStyle = true` and `height = 200`
- Can serve as reference implementation

### CooldownManagerCentered

**Status: ⚠️ Requires Analysis**
- Uses different UI system (not LEM-based)
- May not apply to this standardization
- Requires separate investigation

---

## Reference: Best Practice Example

From [resourcebars/LEMSettingsLoader.lua](resourcebars/LEMSettingsLoader.lua#L437-L510):

```lua
{
    parentId = L["CATEGORY_BAR_STYLE"],
    order = 402,
    name = L["BAR_TEXTURE"],
    kind = LEM.SettingType.Dropdown,
    default = defaults.foregroundStyle,
    useOldStyle = true,
    height = 200,
    generator = function(dropdown, rootDescription, settingObject)
        -- Create texture pool for rendering previews
        dropdown.texturePool = {}

        -- Get layout context
        local layoutName = LEM.GetActiveLayoutName() or "Default"
        local data = GetBarData(config, layoutName)
        if not data then return end

        -- Hook cleanup on menu close
        if not dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked then
            hooksecurefunc(dropdown, "OnMenuClosed", function()
                for _, texture in pairs(dropdown.texturePool) do
                    texture:Hide()
                end
            end)
            dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked = true
        end

        -- Set current value as dropdown text
        dropdown:SetDefaultText(settingObject.get(layoutName))

        -- Get and sort available textures
        local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
        local sortedTextures = {}
        for textureName in pairs(textures) do
            table.insert(sortedTextures, textureName)
        end
        table.sort(sortedTextures)

        -- Create button for each texture with preview
        for index, textureName in ipairs(sortedTextures) do
            local texturePath = textures[textureName]

            local button = rootDescription:CreateButton(textureName, function()
                dropdown:SetDefaultText(textureName)
                settingObject.set(layoutName, textureName)
            end)

            -- Add texture preview to button
            if texturePath then
                button:AddInitializer(function(self)
                    local textureStatusBar = dropdown.texturePool[index]
                    if not textureStatusBar then
                        textureStatusBar = dropdown:CreateTexture(nil, "BACKGROUND")
                        dropdown.texturePool[index] = textureStatusBar
                    end

                    textureStatusBar:SetParent(self)
                    textureStatusBar:SetAllPoints(self)
                    textureStatusBar:SetTexture(texturePath)

                    textureStatusBar:Show()
                end)
            end
        end
    end,
    get = function(layoutName)
        local data = GetBarData(config, layoutName)
        return (data and data.foregroundStyle) or defaults.foregroundStyle
    end,
    set = function(layoutName, value)
        local data = EnsureBarData(config, layoutName, defaults)
        if data then
            data.foregroundStyle = value
            bar:ApplyLayout(layoutName)
        end
    end,
    isEnabled = function(layoutName)
        local data = GetBarData(config, layoutName)
        return not data.useResourceAtlas
    end,
}
```

---

## Migration Path

### Phase 1: Documentation & Analysis (CURRENT)
- [x] Document all dropdown implementations
- [x] Identify inconsistencies
- [x] Create standardization rules
- [ ] **You are here**

### Phase 2: SuaviUI Updates (NEXT)
- [ ] Update castbar_editmode.lua texture dropdowns with previews
- [ ] Update unitframes_editmode.lua texture dropdowns with previews
- [ ] Add `useOldStyle = true` to all value-based dropdowns
- [ ] Test all edit mode panels

### Phase 3: SenseiClassResourceBar (REFERENCE)
- [ ] Verify current implementation matches standards
- [ ] Update if needed
- [ ] Maintain as reference

### Phase 4: CooldownManagerCentered (TBD)
- [ ] Analyze UI system
- [ ] Apply standards if applicable
- [ ] Document findings

### Phase 5: Testing & Refinement
- [ ] Test all dropdowns in Edit Mode
- [ ] Verify texture previews display correctly
- [ ] Verify performance with large texture lists
- [ ] Test with different screen resolutions

---

## Summary of Standards

| Aspect | Standard | Rationale |
|--------|----------|-----------|
| **Styling** | `useOldStyle = true` | Consistent button-like appearance |
| **Height** | `height = 200` | Scrollable for large lists |
| **Texture Dropdowns** | Must have generator with previews | Visual feedback for user |
| **Texture Preview** | Show in button background | Non-intrusive, immediate preview |
| **Cleanup** | OnMenuClosed hook | Memory efficiency |
| **Sorting** | Alphabetical | User-friendly navigation |
| **Font Previews** | Optional but recommended | Improves UX |
| **DropdownColor** | For texture + color settings | Complete style control |

---

## Key Takeaways for Future Development

1. **Always check for existing implementations** before creating new dropdowns
2. **Use the SenseiClassResourceBar pattern** as the reference implementation
3. **Preview every visual element** (textures, fonts, colors)
4. **Keep generators in the main file** if specific to that module
5. **Test with LSM data** to ensure compatibility with custom media
6. **Document the purpose** of custom generators in comments
7. **Use texture pools** for efficient memory management
8. **Always include cleanup hooks** for temporary textures

---

## Questions to Ask When Creating a New Dropdown

1. **Is this a visual element?** (Texture, font, color, statusbar)
   - Yes → Add texture/visual preview
   - No → Use simple values table

2. **Will this list be long?** (>5 items)
   - Yes → Use `height` for scrollable menu
   - No → Regular dropdown is fine

3. **Does this modify a visual element?** (Texture + Color)
   - Yes → Consider `DropdownColor` type
   - No → Use regular `Dropdown` type

4. **Are you duplicating code?** (Another dropdown does something similar)
   - Yes → Extract to helper function or use generator pattern
   - No → Implement following the standard pattern

5. **Does this need performance optimization?** (100+ items)
   - Yes → Implement texture pool and cleanup hooks
   - No → Simple generator is fine

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-03  
**Author:** GitHub Copilot  
**Status:** Ready for Implementation
