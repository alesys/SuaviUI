# SuaviUI Layout System

## Overview

The Layout System centralizes all UI spacing, sizing, and positioning constants into a single, maintainable configuration object. This replaces scattered "magic numbers" throughout the codebase with semantic constants.

## Location

All layout constants are defined in `utils/sui_gui.lua` under `GUI.Layout`

Access via shorthand: `local L = GUI.Layout`

## Architecture

### **GUI.Colors** (Theme System)
- All color values (backgrounds, accents, borders, text)
- Easy to swap themes by replacing color values
- Access via `C` shorthand

### **GUI.Layout** (Spacing & Sizing)
- All dimensions, spacing, typography
- Widget sizes, padding, form layouts
- Access via `L` shorthand

## Layout Categories

### Form System
```lua
formLabelWidth = 180       -- Width allocated for labels
formControlStart = 180     -- X position where controls start
formRowHeight = 28         -- Standard row height
formGap = 6                -- Gap between label and control
```

### Widget Dimensions
```lua
checkbox = { size = 16, checkSize = 20 }
toggle = { width = 40, height = 20, thumbSize = 16, thumbInset = 2 }
dropdown = { height = 24, chevronWidth = 20, menuItemHeight = 22 }
slider = { height = 12, thumbWidth = 10, thumbHeight = 16 }
colorPicker = { size = 24, sizeSmall = 16 }
```

### Spacing Scale (Tailwind-inspired)
```lua
space = {
    xs = 4,      -- Extra small
    sm = 6,      -- Small (label offsets)
    md = 10,     -- Medium (general padding)
    lg = 15,     -- Large (section gaps)
    xl = 20,     -- Extra large
    xxl = 30,    -- Double extra large
}
```

### Typography
```lua
font = {
    tiny = 10,    -- Muted/small text
    small = 11,   -- Descriptions, secondary
    normal = 12,  -- Standard labels/controls
    large = 14,   // Headers, titles
}
```

### Panel Constraints
```lua
panel = {
    defaultWidth = 750,
    minWidth = 600,
    maxWidth = 1000,
    minHeight = 400,
    maxHeight = 1200,
    padding = 10,
    paddingDouble = 20,
}
```

### Tab System
```lua
tabs = {
    perRow = 5,
    height = 22,
    spacing = 2,
    startY = -35,
}

subTabs = {
    height = 24,
    spacing = 4,
    separatorSpacing = 15,
}
```

## Usage Examples

### Before (Hard-coded)
```lua
local box = CreateFrame("Button", nil, container, "BackdropTemplate")
box:SetSize(16, 16)
text:SetPoint("LEFT", box, "RIGHT", 6, 0)
SetFont(text, 12, "", C.text)
```

### After (Layout Constants)
```lua
local box = CreateFrame("Button", nil, container, "BackdropTemplate")
box:SetSize(L.checkbox.size, L.checkbox.size)
text:SetPoint("LEFT", box, "RIGHT", L.space.sm, 0)
SetFont(text, L.font.normal, "", C.text)
```

## Benefits

### 1. **Maintainability**
- Change toggle width once: updates all toggles
- Adjust spacing scale: updates entire UI
- No hunting for magic numbers

### 2. **Self-Documenting**
```lua
-- Before: What is 180?
track:SetPoint("LEFT", container, "LEFT", 180, 0)

// After: Clear semantic meaning
track:SetPoint("LEFT", container, "LEFT", L.formControlStart, 0)
```

### 3. **Customization Ready**
Users can easily modify `GUI.Layout` to create compact/spacious variants:
```lua
-- Compact mode
L.formRowHeight = 24
L.space.md = 8

-- Spacious mode
L.formRowHeight = 32
L.space.md = 12
```

### 4. **Future Responsive Layouts**
Foundation for breakpoint-based layouts:
```lua
if panelWidth < 700 then
    L.formControlStart = 150  -- Narrower label area
else
    L.formControlStart = 180  -- Standard
end
```

## Current Status

### ✅ Implemented
- Layout constants defined
- Toggle switches using constants
- Main frame using constants
- Panel constraints using constants
- Tab system using constants
- Font sizes using constants
- Spacing using constants (partial)

### 🔄 In Progress
- Checkbox sizes (multiple instances need individual updates)
- Dropdown dimensions
- Color picker sizes
- Slider dimensions
- Section spacing

### ⏳ Future Enhancements
- Theme switching system (multiple color palettes)
- Responsive breakpoints
- Compact/normal/spacious layout modes
- Per-user layout preferences
- Dynamic font scaling

## Customization Guide

### Changing Widget Sizes
Edit `GUI.Layout` in `sui_gui.lua`:
```lua
toggle = { 
    width = 50,      -- Make toggles wider
    height = 24,     -- Make toggles taller
    thumbSize = 20,  -- Bigger thumb
    thumbInset = 2,
}
```

### Adjusting Spacing
```lua
space = {
    xs = 6,    -- Increase from 4
    sm = 8,    // Increase from 6
    md = 12,   -- Increase from 10
    lg = 18,   -- Increase from 15
    xl = 24,   -- Increase from 20
    xxl = 36,  -- Increase from 30
}
```

### Form Layout Changes
```lua
formRowHeight = 32,     -- More vertical space
formControlStart = 200, -- Move controls further right
```

### Panel Size Adjustments
```lua
panel = {
    defaultWidth = 800,  -- Wider default
    maxWidth = 1200,     -- Allow bigger resize
}
```

## Best Practices

1. **Always use Layout constants** instead of hard-coded numbers
2. **Use semantic names** (L.formControlStart, not L.offset180)
3. **Document new constants** when adding widgets
4. **Keep related values together** (all toggle properties in toggle object)
5. **Use spacing scale** instead of arbitrary values

## Migration Guide

When updating old code:
1. Identify the hard-coded number
2. Find/add appropriate Layout constant
3. Replace number with `L.constantName`
4. Test that behavior is identical

Example:
```lua
-- Find
container:SetHeight(28)

-- Identify purpose
-- This is a form row

-- Replace
container:SetHeight(L.formRowHeight)
```

## Performance Impact

**Zero runtime overhead:**
- Constants are resolved at code load time
- No table lookups during widget creation
- Same performance as hard-coded values
- Actually faster to modify (no /reload needed for color changes once hot-reload is added)

## Future: Theme System

Planned theme switching:
```lua
GUI.Themes = {
    purple = { accent = {0.659, 0.333, 0.969, 1}, ... },
    blue = { accent = {0.2, 0.6, 1, 1}, ... },
    mint = { accent = {0.34, 0.83, 0.6, 1}, ... },
}

function GUI:SetTheme(themeName)
    self.Colors = self.Themes[themeName]
    -- Refresh UI
end
```

## Contributing

When adding new widgets:
1. Add dimension constants to `GUI.Layout`
2. Use constants instead of hard-coded values
3. Document the constants in this file
4. Update examples if needed

---

Last Updated: February 2026
