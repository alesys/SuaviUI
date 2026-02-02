--[[
    SuaviUI Constants Module
    Centralizes all magic strings and numbers used throughout the addon
    Ensures consistency and maintainability across the codebase
]]

local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- ANCHOR POINTS
---------------------------------------------------------------------------
-- WoW API anchor point constants
local ANCHOR_POINTS = {
    TOPLEFT = "TOPLEFT",
    TOP = "TOP",
    TOPRIGHT = "TOPRIGHT",
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
    BOTTOMLEFT = "BOTTOMLEFT",
    BOTTOM = "BOTTOM",
    BOTTOMRIGHT = "BOTTOMRIGHT",
}

-- Dropdown options for anchor points (user-facing text)
local ANCHOR_POINT_OPTIONS = {
    { text = "Top Left", value = "TOPLEFT" },
    { text = "Top", value = "TOP" },
    { text = "Top Right", value = "TOPRIGHT" },
    { text = "Left", value = "LEFT" },
    { text = "Center", value = "CENTER" },
    { text = "Right", value = "RIGHT" },
    { text = "Bottom Left", value = "BOTTOMLEFT" },
    { text = "Bottom", value = "BOTTOM" },
    { text = "Bottom Right", value = "BOTTOMRIGHT" },
}

-- Map user-friendly text to API format for normalization
local ANCHOR_POINT_MAP = {
    ["Top Left"] = "TOPLEFT",
    ["Top"] = "TOP",
    ["Top Right"] = "TOPRIGHT",
    ["Left"] = "LEFT",
    ["Center"] = "CENTER",
    ["Right"] = "RIGHT",
    ["Bottom Left"] = "BOTTOMLEFT",
    ["Bottom"] = "BOTTOM",
    ["Bottom Right"] = "BOTTOMRIGHT",
}

---------------------------------------------------------------------------
-- FRAME STRATA
---------------------------------------------------------------------------
-- WoW API frame strata constants
local FRAME_STRATA = {
    WORLD = "WORLD",
    BACKGROUND = "BACKGROUND",
    LOW = "LOW",
    MEDIUM = "MEDIUM",
    HIGH = "HIGH",
    DIALOG = "DIALOG",
    FULLSCREEN = "FULLSCREEN",
    FULLSCREEN_DIALOG = "FULLSCREEN_DIALOG",
    TOOLTIP = "TOOLTIP",
}

---------------------------------------------------------------------------
-- FRAME LEVELS
---------------------------------------------------------------------------
-- Common frame level offsets for layering
local FRAME_LEVELS = {
    -- Base levels
    BASE = 0,
    
    -- Relative offsets for sublayers
    OVERLAY_ABSORB = 1,
    OVERLAY_HEAL_ABSORB = 2,
    OVERLAY_TEXT = 2,
    OVERLAY_INDICATOR = 5,
    OVERLAY_AURA = 10,
    
    -- Cast bar levels
    CASTBAR_BASE = 200,
    
    -- Edit Mode levels
    EDITMODE_BASE = 100,
}

---------------------------------------------------------------------------
-- UNIT TYPES
---------------------------------------------------------------------------
local UNIT_TYPES = {
    PLAYER = "player",
    TARGET = "target",
    FOCUS = "focus",
    PET = "pet",
    BOSS = "boss",
}

-- Boss unit keys
local BOSS_UNIT_KEYS = {
    "boss1",
    "boss2",
    "boss3",
    "boss4",
    "boss5",
}

---------------------------------------------------------------------------
-- RESOURCE TYPES
---------------------------------------------------------------------------
local RESOURCE_TYPES = {
    HEALTH = "health",
    POWER = "power",
    CASTBAR = "castbar",
    AURA = "aura",
}

---------------------------------------------------------------------------
-- DEFAULT VALUES
---------------------------------------------------------------------------
local DEFAULTS = {
    -- Text positioning defaults
    TEXT_ANCHOR = "TOPLEFT",
    POWER_TEXT_ANCHOR = "BOTTOMRIGHT",
    BUFF_ANCHOR = "BOTTOMLEFT",
    DEBUFF_ANCHOR = "TOPLEFT",
    
    -- Border and spacing
    BORDER_SIZE = 1,
    ICON_BORDER_SIZE = 1,
    SEPARATOR_HEIGHT = 1,
    
    -- Font sizes
    FONT_SIZE_NORMAL = 12,
    FONT_SIZE_SMALL = 10,
    FONT_SIZE_LARGE = 14,
    
    -- Preview animation
    PREVIEW_CAST_TIME = 3.0,
    PREVIEW_UPDATE_INTERVAL = 0.016, -- ~60 FPS
    
    -- Layer priorities
    PLAYER_CASTBAR_PRIORITY = 5,
    TARGET_CASTBAR_PRIORITY = 5,
    BOSS_CASTBAR_PRIORITY = 5,
    
    -- Timing
    INITIALIZATION_DELAY = 4,
    FRAME_REGISTRATION_DELAY = 0.1,
    EDITMODE_CALLBACK_DELAY = 0.05,
}

---------------------------------------------------------------------------
-- TEXTURE PATHS
---------------------------------------------------------------------------
local TEXTURE_PATHS = {
    -- Default textures
    WHITE_8X8 = "Interface\\Buttons\\WHITE8x8",
    
    -- Font paths
    FONT_FRIZQT = "Fonts\\FRIZQT__.TTF",
    FONT_ARIAL = "Fonts\\ARIAL.TTF",
}

---------------------------------------------------------------------------
-- OUTLINE TYPES
---------------------------------------------------------------------------
local OUTLINE_TYPES = {
    NONE = "NONE",
    OUTLINE = "OUTLINE",
    THICK_OUTLINE = "THICKOUTLINE",
    MONOCHROME = "MONOCHROME",
    MONOCHROME_OUTLINE = "MONOCHROME,OUTLINE",
}

---------------------------------------------------------------------------
-- JUSTIFICATION
---------------------------------------------------------------------------
local TEXT_JUSTIFICATION = {
    LEFT = "LEFT",
    CENTER = "CENTER",
    RIGHT = "RIGHT",
}

---------------------------------------------------------------------------
-- EXPORT FUNCTIONS
---------------------------------------------------------------------------
-- Normalize anchor point from user-friendly text to API format
local function NormalizeAnchorPoint(anchor)
    if not anchor then return nil end
    -- If already uppercase (API format), return as-is
    if anchor == anchor:upper() then return anchor end
    -- Otherwise convert from user-friendly format
    return ANCHOR_POINT_MAP[anchor] or anchor:upper()
end

-- Validate anchor point
local function IsValidAnchorPoint(anchor)
    return ANCHOR_POINTS[anchor] ~= nil
end

-- Get all valid anchor point values
local function GetAnchorPointValues()
    local values = {}
    for key in pairs(ANCHOR_POINTS) do
        table.insert(values, key)
    end
    return values
end

---------------------------------------------------------------------------
-- REGISTER MODULE
---------------------------------------------------------------------------
ns.Constants = {
    -- Main tables
    ANCHOR_POINTS = ANCHOR_POINTS,
    ANCHOR_POINT_OPTIONS = ANCHOR_POINT_OPTIONS,
    FRAME_STRATA = FRAME_STRATA,
    FRAME_LEVELS = FRAME_LEVELS,
    UNIT_TYPES = UNIT_TYPES,
    BOSS_UNIT_KEYS = BOSS_UNIT_KEYS,
    RESOURCE_TYPES = RESOURCE_TYPES,
    DEFAULTS = DEFAULTS,
    TEXTURE_PATHS = TEXTURE_PATHS,
    OUTLINE_TYPES = OUTLINE_TYPES,
    TEXT_JUSTIFICATION = TEXT_JUSTIFICATION,
    
    -- Functions
    NormalizeAnchorPoint = NormalizeAnchorPoint,
    IsValidAnchorPoint = IsValidAnchorPoint,
    GetAnchorPointValues = GetAnchorPointValues,
}

-- Make constants available globally for convenience
_G.SUI_CONSTANTS = ns.Constants
