local addonName, SUICore = ...

-- Ensure ResourceBars namespace exists
SUICore.ResourceBars = SUICore.ResourceBars or {}
local RB = SUICore.ResourceBars

-- Libraries
RB.LSM = LibStub("LibSharedMedia-3.0")
RB.LEM = LibStub("LibEQOLEditMode-1.0")
RB.LibSerialize = LibStub("LibSerialize", true) or LibStub("AceSerializer-3.0", true)
RB.LibDeflate = LibStub("LibDeflate", true)

local LSM = RB.LSM

-- NOTE: All media registration is now consolidated in utils/media.lua
-- This file only contains resource bar configuration constants

------------------------------------------------------------
-- PROFILE-AWARE RESOURCE BAR STORAGE
------------------------------------------------------------
function RB.GetResourceBarsDB()
    if SUICore and SUICore.db and SUICore.db.profile then
        SUICore.db.profile.resourceBars = SUICore.db.profile.resourceBars or {}
        SuaviUI_ResourceBarsDB = SUICore.db.profile.resourceBars
        return SuaviUI_ResourceBarsDB
    end

    SuaviUI_ResourceBarsDB = SuaviUI_ResourceBarsDB or {}
    return SuaviUI_ResourceBarsDB
end

------------------------------------------------------------
-- COMMON DEFAULTS & DROPDOWN OPTIONS
------------------------------------------------------------
RB.commonDefaults = {
    -- LEM settings
    enableOverlayToggle = true,
    settingsMaxHeight = select(2, GetPhysicalScreenSize()) * 0.6,
    point = "CENTER",
    x = 0,
    y = 0,
    -- Bar settings
    relativeFrame = "UIParent",
    relativePoint = "CENTER",
    barVisible = "Always Visible",
    hideWhileMountedOrVehicule = false,
    barStrata = "MEDIUM",
    scale = 1,
    width = 200,
    minWidth = 0,
    widthMode = "Manual",
    height = 15,
    fillDirection = "Left to Right",
    smoothProgress = true,
    fasterUpdates = true,
    showText = true,
    textColor = { r = 1, g = 1, b = 1, a = 1 },
    textFormat = "Current",
    textPrecision = "12",
    showFragmentedPowerBarText = false,
    fragmentedPowerBarTextColor = { r = 1, g = 1, b = 1, a = 1 },
    fragmentedPowerBarTextPrecision = "12.3",
    font = LSM:Fetch(LSM.MediaType.FONT, "Friz Quadrata TT"),
    fontSize = 12,
    fontOutline = "OUTLINE",
    textAlign = "CENTER",
    maskAndBorderStyle = "Thin",
    borderColor = { r = 0, g = 0, b = 0, a = 1 },
    backgroundStyle = "SUI Semi-transparent",
    backgroundColor = { r = 1, g = 1, b = 1, a = 1 },
    useStatusBarColorForBackgroundColor = false,
    foregroundStyle = "Blizzard",
    useResourceAtlas = false,
}

RB.availableBarVisibilityOptions = {
    { text = "Always Visible" },
    { text = "In Combat" },
    { text = "Has Target Selected" },
    { text = "Has Target Selected OR In Combat" },
    { text = "Hidden" },
}

RB.availableBarStrataOptions = {
    { text = "TOOLTIP" },
    { text = "DIALOG" },
    { text = "HIGH" },
    { text = "MEDIUM" },
    { text = "LOW" },
    { text = "BACKGROUND" },
}

RB.availableRoleOptions = {
    { text = "Tank", value = "TANK" },
    { text = "Healer", value = "HEALER" },
    { text = "DPS", value = "DAMAGER" },
}

RB.availablePositionModeOptions = function(config)
    local positions = {
        { text = "Self" },
    }

    if config.frameName == "SuaviUI_HealthBar" then
        table.insert(positions, { text = "Use Primary Resource Bar Position If Hidden" })
        table.insert(positions, { text = "Use Secondary Resource Bar Position If Hidden" })
    elseif config.frameName == "SuaviUI_SecondaryResourceBar" then
        table.insert(positions, { text = "Use Primary Resource Bar Position If Hidden" })
        table.insert(positions, { text = "Use Health Bar Position If Hidden" })
    end

    return positions
end

RB.availableRelativeFrames = function(config)
    local frames = {
        { text = "UIParent" },
    }

    if config.frameName == "SuaviUI_HealthBar" then
        table.insert(frames, { text = "Primary Resource Bar" })
        table.insert(frames, { text = "Secondary Resource Bar" })
    elseif config.frameName == "SuaviUI_PrimaryResourceBar" then
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Secondary Resource Bar" })
    elseif config.frameName == "SuaviUI_SecondaryResourceBar" then
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Primary Resource Bar" })
    else
        table.insert(frames, { text = "Health Bar" })
        table.insert(frames, { text = "Primary Resource Bar" })
        table.insert(frames, { text = "Secondary Resource Bar" })
    end

    local additionalFrames = {
        { text = "PlayerFrame" },
        { text = "TargetFrame" },
        { text = "Essential Cooldowns" },
        { text = "Utility Cooldowns" },
        { text = "Tracked Buffs" },
        { text = "Action Bar" },
    }

    for _, frame in pairs(additionalFrames) do
        table.insert(frames, frame)
    end

    for i = 2, 8 do
        table.insert(frames, { text = "Action Bar " .. i })
    end

    return frames
end

RB.resolveRelativeFrames = function(relativeFrame)
    local tbl = {
        ["UIParent"] = UIParent,
        ["Health Bar"] = RB.barInstances and RB.barInstances["SuaviUI_HealthBar"] and RB.barInstances["SuaviUI_HealthBar"].Frame,
        ["Primary Resource Bar"] = RB.barInstances and RB.barInstances["SuaviUI_PrimaryResourceBar"] and RB.barInstances["SuaviUI_PrimaryResourceBar"].Frame,
        ["Secondary Resource Bar"] = RB.barInstances and RB.barInstances["SuaviUI_SecondaryResourceBar"] and RB.barInstances["SuaviUI_SecondaryResourceBar"].Frame,
        ["PlayerFrame"] = PlayerFrame,
        ["TargetFrame"] = TargetFrame,
        ["Essential Cooldowns"] = _G["EssentialCooldownViewer"],
        ["Utility Cooldowns"] = _G["UtilityCooldownViewer"],
        ["Tracked Buffs"] = _G["BuffIconCooldownViewer"],
        ["Action Bar"] = _G["MainActionBar"],
        ["Action Bar 2"] = _G["MultiBarBottomLeft"],
        ["Action Bar 3"] = _G["MultiBarBottomRight"],
        ["Action Bar 4"] = _G["MultiBarRight"],
        ["Action Bar 5"] = _G["MultiBarLeft"],
        ["Action Bar 6"] = _G["MultiBar5"],
        ["Action Bar 7"] = _G["MultiBar6"],
        ["Action Bar 8"] = _G["MultiBar7"],
    }
    return tbl[relativeFrame] or UIParent
end

RB.availableAnchorPoints = {
    { text = "TOPLEFT" },
    { text = "TOP" },
    { text = "TOPRIGHT" },
    { text = "LEFT" },
    { text = "CENTER" },
    { text = "RIGHT" },
    { text = "BOTTOMLEFT" },
    { text = "BOTTOM" },
    { text = "BOTTOMRIGHT" },
}

RB.availableRelativePoints = {
    { text = "TOPLEFT" },
    { text = "TOP" },
    { text = "TOPRIGHT" },
    { text = "LEFT" },
    { text = "CENTER" },
    { text = "RIGHT" },
    { text = "BOTTOMLEFT" },
    { text = "BOTTOM" },
    { text = "BOTTOMRIGHT" },
}

RB.availableWidthModes = {
    { text = "Manual" },
    { text = "Sync With Essential Cooldowns" },
    { text = "Sync With Utility Cooldowns" },
    { text = "Sync With Tracked Buffs" },
}

RB.availableFillDirections = {
    { text = "Left to Right" },
    { text = "Right to Left" },
    { text = "Top to Bottom" },
    { text = "Bottom to Top" },
}

RB.availableOutlineStyles = {
    { text = "NONE" },
    { text = "OUTLINE" },
    { text = "THICKOUTLINE" },
}

RB.availableTextFormats = {
    { text = "Current" },
    { text = "Current / Maximum" },
    { text = "Percent" },
    { text = "Percent%" },
    { text = "Current - Percent" },
    { text = "Current - Percent%" },
}

RB.textPrecisionAllowedForType = {
    ["Percent"] = true,
    ["Percent%"] = true,
    ["Current - Percent"] = true,
    ["Current - Percent%"] = true,
}

RB.availableTextPrecisions = {
    { text = "12" },
    { text = "12.3" },
    { text = "12.34" },
    { text = "12.345" },
}

RB.availableTextAlignmentStyles = {
    { text = "TOP" },
    { text = "LEFT" },
    { text = "CENTER" },
    { text = "RIGHT" },
    { text = "BOTTOM" },
}

RB.maskAndBorderStyles = {
    ["1 Pixel"] = {
        type = "fixed",
        thickness = 1,
    },
    ["Thin"] = {
        type = "fixed",
        thickness = 2,
    },
    ["Slight"] = {
        type = "fixed",
        thickness = 3,
    },
    ["Bold"] = {
        type = "fixed",
        thickness = 5,
    },
    ["Blizzard Classic"] = {
        type = "texture",
        mask = [[Interface\AddOns\SuaviUI\assets\textures\border-blizzard-classic-mask.png]],
        border = LSM:Fetch(LSM.MediaType.BORDER, "SUI Border Blizzard Classic"),
    },
    ["Blizzard Classic Thin"] = {
        type = "texture",
        mask = [[Interface\AddOns\SuaviUI\assets\textures\border-blizzard-classic-thin-mask.png]],
        border = LSM:Fetch(LSM.MediaType.BORDER, "SUI Border Blizzard Classic Thin"),
    },
    ["None"] = {},
}

RB.availableMaskAndBorderStyles = {}
for styleName, _ in pairs(RB.maskAndBorderStyles) do
    table.insert(RB.availableMaskAndBorderStyles, { text = styleName })
end

RB.backgroundStyles = {
    ["SUI Semi-transparent"] = { type = "color", r = 0, g = 0, b = 0, a = 0.5 },
}

RB.availableBackgroundStyles = {}
for name, _ in pairs(RB.backgroundStyles) do
    table.insert(RB.availableBackgroundStyles, name)
end

------------------------------------------------------------
-- POWER TYPES
------------------------------------------------------------

-- Power types that should show discrete ticks
RB.tickedPowerTypes = {
    [Enum.PowerType.ArcaneCharges] = true,
    [Enum.PowerType.Chi] = true,
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.HolyPower] = true,
    [Enum.PowerType.Runes] = true,
    [Enum.PowerType.SoulShards] = true,
    ["MAELSTROM_WEAPON"] = true,
    ["TIP_OF_THE_SPEAR"] = true,
    ["SOUL_FRAGMENTS_VENGEANCE"] = true,
    ["WHIRLWIND"] = true,
}

-- Power types that are fragmented (multiple independent segments)
RB.fragmentedPowerTypes = {
    [Enum.PowerType.ComboPoints] = true,
    [Enum.PowerType.Essence] = true,
    [Enum.PowerType.Runes] = true,
    ["MAELSTROM_WEAPON"] = true,
}

------------------------------------------------------------
-- LOCALIZATION (basic strings)
------------------------------------------------------------
RB.L = {
    -- Categories
    ["CATEGORY_BAR_VISIBILITY"] = "Bar Visibility",
    ["CATEGORY_POSITION_AND_SIZE"] = "Position & Size",
    ["CATEGORY_BAR_SETTINGS"] = "Bar Settings",
    ["CATEGORY_BAR_STYLE"] = "Bar Style",
    ["CATEGORY_TEXT_SETTINGS"] = "Text Settings",
    ["CATEGORY_FONT"] = "Font",

    -- Visibility
    ["BAR_VISIBLE"] = "Bar Visible",
    ["BAR_STRATA"] = "Frame Strata",
    ["BAR_STRATA_TOOLTIP"] = "The frame stacking layer for this bar",
    ["HIDE_WHILE_MOUNTED_OR_VEHICULE"] = "Hide While Mounted/Vehicle",
    ["HIDE_WHILE_MOUNTED_OR_VEHICULE_TOOLTIP"] = "Hide the bar when mounted or in a vehicle",
    ["HIDE_HEALTH_ON_ROLE"] = "Hide Health On Role",
    ["HIDE_MANA_ON_ROLE"] = "Hide Mana On Role",
    ["HIDE_MANA_ON_ROLE_PRIMARY_BAR_TOOLTIP"] = "Hide mana bar for selected roles",
    ["HIDE_BLIZZARD_UI"] = "Hide Blizzard UI",
    ["HIDE_BLIZZARD_UI_HEALTH_BAR_TOOLTIP"] = "Hide the default player frame",
    ["HIDE_BLIZZARD_UI_SECONDARY_POWER_BAR_TOOLTIP"] = "Hide the default class resource frame",

    -- Position & Size
    ["POSITION"] = "Position Mode",
    ["X_POSITION"] = "X Position",
    ["Y_POSITION"] = "Y Position",
    ["RELATIVE_FRAME"] = "Relative Frame",
    ["RELATIVE_FRAME_TOOLTIP"] = "The frame this bar is positioned relative to",
    ["RELATIVE_FRAME_CYCLIC_WARNING"] = "Cannot anchor to a frame that creates a cyclic dependency",
    ["ANCHOR_POINT"] = "Anchor Point",
    ["RELATIVE_POINT"] = "Relative Point",
    ["BAR_SIZE"] = "Bar Scale",
    ["WIDTH_MODE"] = "Width Mode",
    ["WIDTH"] = "Width",
    ["MINIMUM_WIDTH"] = "Minimum Width",
    ["MINIMUM_WIDTH_TOOLTIP"] = "Minimum width when syncing with another frame",
    ["HEIGHT"] = "Height",

    -- Bar Settings
    ["FILL_DIRECTION"] = "Fill Direction",
    ["FASTER_UPDATES"] = "Faster Updates",
    ["SMOOTH_PROGRESS"] = "Smooth Progress",
    ["SHOW_TICKS_WHEN_AVAILABLE"] = "Show Ticks",
    ["TICK_THICKNESS"] = "Tick Thickness",

    -- Bar Style
    ["USE_CLASS_COLOR"] = "Use Class Color",
    ["USE_RESOURCE_TEXTURE_AND_COLOR"] = "Use Resource Atlas",
    ["BORDER"] = "Border",
    ["BACKGROUND"] = "Background",
    ["USE_BAR_COLOR_FOR_BACKGROUND_COLOR"] = "Use Bar Color for Background",
    ["BAR_TEXTURE"] = "Bar Texture",

    -- Text Settings
    ["SHOW_RESOURCE_NUMBER"] = "Show Text",
    ["RESOURCE_NUMBER_FORMAT"] = "Text Format",
    ["RESOURCE_NUMBER_FORMAT_TOOLTIP"] = "How to display the resource value",
    ["RESOURCE_NUMBER_PRECISION"] = "Text Precision",
    ["RESOURCE_NUMBER_ALIGNMENT"] = "Text Alignment",
    ["SHOW_MANA_AS_PERCENT"] = "Show Mana as Percent",
    ["SHOW_MANA_AS_PERCENT_TOOLTIP"] = "Display mana as percentage instead of raw value",
    ["SHOW_RESOURCE_CHARGE_TIMER"] = "Show Charge Timer",
    ["CHARGE_TIMER_PRECISION"] = "Timer Precision",

    -- Font
    ["FONT"] = "Font",
    ["FONT_SIZE"] = "Font Size",
    ["FONT_OUTLINE"] = "Font Outline",

    -- Edit Mode Names
    ["HEALTH_BAR_EDIT_MODE_NAME"] = "Suavihealth",
    ["PRIMARY_POWER_BAR_EDIT_MODE_NAME"] = "Suavipower",
    ["SECONDARY_POWER_BAR_EDIT_MODE_NAME"] = "Suavipower II",
    ["TERTIARY_POWER_BAR_EDIT_MODE_NAME"] = "Suavipower III",

    -- Import/Export
    ["POWER_COLOR_SETTINGS"] = "Power Color Settings",
    ["EXPORT_BAR"] = "Export Bar",
    ["IMPORT_BAR"] = "Import Bar",
    ["EXPORT"] = "Export",
    ["IMPORT"] = "Import",
    ["CLOSE"] = "Close",
    ["OKAY"] = "OK",
    ["CANCEL"] = "Cancel",
    ["EXPORT_FAILED"] = "Export failed",
    ["IMPORT_FAILED_WITH_ERROR"] = "Import failed: ",
    ["IMPORT_STRING_NOT_SUITABLE"] = "Import string is not from",
    ["IMPORT_STRING_OLDER_VERSION"] = "Import string is from an older version of",
    ["IMPORT_STRING_INVALID"] = "Import string is invalid",
    ["IMPORT_DECODE_FAILED"] = "Failed to decode import string",
    ["IMPORT_DECOMPRESSION_FAILED"] = "Failed to decompress import data",
    ["IMPORT_DESERIALIZATION_FAILED"] = "Failed to deserialize import data",
    ["SETTING_OPEN_AFTER_EDIT_MODE_CLOSE"] = "Settings will open after Edit Mode closes",
}

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
function RB.getTableKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, tostring(k))
    end
    return keys
end

function RB.rounded(num)
    return math.floor(num + 0.5)
end
