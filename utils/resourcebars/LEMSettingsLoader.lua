------------------------------------------------------------
-- LEM SETTINGS LOADER
-- Based on SenseiClassResourceBar by Equilateral (EQOL)
-- Modified for SuaviUI AceDB profile integration
------------------------------------------------------------

local addonName, SUICore = ...

local RB = SUICore.ResourceBars
local LSM = RB.LSM
local LEM = RB.LEM
local L = RB.L

------------------------------------------------------------
-- LEM SETTINGS LOADER MIXIN
------------------------------------------------------------

local LEMSettingsLoaderMixin = {}

-- Helper to get bar data from profile
local function GetBarData(config, layoutName)
    local db = RB.GetResourceBarsDB()
    if not db then return nil end
    return db[config.dbName] and db[config.dbName][layoutName]
end

-- Helper to ensure bar data exists and return it
local function EnsureBarData(config, layoutName, defaults)
    local db = RB.GetResourceBarsDB()
    if not db then return nil end
    
    db[config.dbName] = db[config.dbName] or {}
    db[config.dbName][layoutName] = db[config.dbName][layoutName] or CopyTable(defaults)
    return db[config.dbName][layoutName]
end

local function BuildLemSettings(bar, defaults)
    local config = bar:GetConfig()

    local uiWidth, uiHeight = GetPhysicalScreenSize()
    uiWidth = uiWidth / 2
    uiHeight = uiHeight / 2

    local settings = {
        -- BAR VISIBILITY CATEGORY
        {
            order = 100,
            name = L["CATEGORY_BAR_VISIBILITY"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_BAR_VISIBILITY"],
        },
        {
            parentId = L["CATEGORY_BAR_VISIBILITY"],
            order = 101,
            name = L["BAR_VISIBLE"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.barVisible,
            useOldStyle = true,
            values = RB.availableBarVisibilityOptions,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.barVisible) or defaults.barVisible
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then data.barVisible = value end
            end,
        },
        {
            parentId = L["CATEGORY_BAR_VISIBILITY"],
            order = 102,
            name = L["BAR_STRATA"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.barStrata,
            useOldStyle = true,
            values = RB.availableBarStrataOptions,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.barStrata) or defaults.barStrata
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.barStrata = value
                    bar:ApplyLayout(layoutName)
                end
            end,
            tooltip = L["BAR_STRATA_TOOLTIP"],
        },
        {
            parentId = L["CATEGORY_BAR_VISIBILITY"],
            order = 104,
            name = L["HIDE_WHILE_MOUNTED_OR_VEHICULE"],
            kind = LEM.SettingType.Checkbox,
            default = defaults.hideWhileMountedOrVehicule,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                if data and data.hideWhileMountedOrVehicule ~= nil then
                    return data.hideWhileMountedOrVehicule
                else
                    return defaults.hideWhileMountedOrVehicule
                end
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then data.hideWhileMountedOrVehicule = value end
            end,
            tooltip = L["HIDE_WHILE_MOUNTED_OR_VEHICULE_TOOLTIP"],
        },
        -- POSITION AND SIZE CATEGORY
        {
            order = 200,
            name = L["CATEGORY_POSITION_AND_SIZE"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_POSITION_AND_SIZE"],
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 202,
            name = L["X_POSITION"],
            kind = LEM.SettingType.Slider,
            default = defaults.x,
            minValue = uiWidth * -1,
            maxValue = uiWidth,
            valueStep = 1,
            allowInput = true,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.x ~= nil and RB.rounded(data.x) or defaults.x) or defaults.x
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.x = RB.rounded(value)
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 203,
            name = L["Y_POSITION"],
            kind = LEM.SettingType.Slider,
            default = defaults.y,
            minValue = uiHeight * -1,
            maxValue = uiHeight,
            valueStep = 1,
            allowInput = true,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.y ~= nil and RB.rounded(data.y) or defaults.y) or defaults.y
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.y = RB.rounded(value)
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 204,
            name = L["RELATIVE_FRAME"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.relativeFrame,
            useOldStyle = true,
            values = RB.availableRelativeFrames(config),
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.relativeFrame) or defaults.relativeFrame
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.relativeFrame = value
                    -- Reset position when changing relative frame
                    data.x = defaults.x
                    data.y = defaults.y
                    data.point = defaults.point
                    data.relativePoint = defaults.relativePoint
                    bar:ApplyLayout(layoutName)
                    LEM.internal:RefreshSettingValues({ L["X_POSITION"], L["Y_POSITION"], L["ANCHOR_POINT"], L["RELATIVE_POINT"] })
                end
            end,
            tooltip = L["RELATIVE_FRAME_TOOLTIP"],
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 205,
            name = L["ANCHOR_POINT"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.point,
            useOldStyle = true,
            values = RB.availableAnchorPoints,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.point) or defaults.point
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.point = value
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 206,
            name = L["RELATIVE_POINT"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.relativePoint,
            useOldStyle = true,
            values = RB.availableRelativePoints,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.relativePoint) or defaults.relativePoint
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.relativePoint = value
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 210,
            kind = LEM.SettingType.Divider,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 211,
            name = L["BAR_SIZE"],
            kind = LEM.SettingType.Slider,
            default = defaults.scale,
            minValue = 0.25,
            maxValue = 2,
            valueStep = 0.01,
            formatter = function(value)
                return string.format("%d%%", RB.rounded(value, 2) * 100)
            end,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.scale ~= nil and RB.rounded(data.scale, 2) or defaults.scale) or defaults.scale
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.scale = RB.rounded(value, 2)
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 212,
            name = L["WIDTH_MODE"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.widthMode,
            useOldStyle = true,
            values = RB.availableWidthModes,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.widthMode) or defaults.widthMode
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.widthMode = value
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 213,
            name = L["WIDTH"],
            kind = LEM.SettingType.Slider,
            default = defaults.width,
            minValue = 1,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.width ~= nil and RB.rounded(data.width) or defaults.width) or defaults.width
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.width = RB.rounded(value)
                    bar:ApplyLayout(layoutName)
                end
            end,
            isEnabled = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.widthMode == RB.WIDTH_MODE.MANUAL
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 214,
            name = L["MINIMUM_WIDTH"],
            kind = LEM.SettingType.Slider,
            default = defaults.minWidth,
            minValue = 0,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.minWidth ~= nil and RB.rounded(data.minWidth) or defaults.minWidth) or defaults.minWidth
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.minWidth = RB.rounded(value)
                    bar:ApplyLayout(layoutName)
                end
            end,
            tooltip = L["MINIMUM_WIDTH_TOOLTIP"],
            isEnabled = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data ~= nil and data.widthMode ~= RB.WIDTH_MODE.MANUAL
            end,
        },
        {
            parentId = L["CATEGORY_POSITION_AND_SIZE"],
            order = 215,
            name = L["HEIGHT"],
            kind = LEM.SettingType.Slider,
            default = defaults.height,
            minValue = 1,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and (data.height ~= nil and RB.rounded(data.height) or defaults.height) or defaults.height
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.height = RB.rounded(value)
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        -- BAR SETTINGS CATEGORY
        {
            order = 300,
            name = L["CATEGORY_BAR_SETTINGS"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_BAR_SETTINGS"],
            defaultCollapsed = true,
        },
        {
            parentId = L["CATEGORY_BAR_SETTINGS"],
            order = 301,
            name = L["FILL_DIRECTION"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.fillDirection,
            useOldStyle = true,
            values = RB.availableFillDirections,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.fillDirection) or defaults.fillDirection
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.fillDirection = value
                    bar:ApplyLayout(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_BAR_SETTINGS"],
            order = 302,
            name = L["FASTER_UPDATES"],
            kind = LEM.SettingType.Checkbox,
            default = defaults.fasterUpdates,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                if data and data.fasterUpdates ~= nil then
                    return data.fasterUpdates
                else
                    return defaults.fasterUpdates
                end
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.fasterUpdates = value
                    if value then
                        bar:EnableFasterUpdates()
                    else
                        bar:DisableFasterUpdates()
                    end
                end
            end,
        },
        {
            parentId = L["CATEGORY_BAR_SETTINGS"],
            order = 303,
            name = L["SMOOTH_PROGRESS"],
            kind = LEM.SettingType.Checkbox,
            default = defaults.smoothProgress,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                if data and data.smoothProgress ~= nil then
                    return data.smoothProgress
                else
                    return defaults.smoothProgress
                end
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then data.smoothProgress = value end
            end,
        },
        -- BAR STYLE CATEGORY
        {
            order = 400,
            name = L["CATEGORY_BAR_STYLE"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_BAR_STYLE"],
            defaultCollapsed = true,
        },
        {
            parentId = L["CATEGORY_BAR_STYLE"],
            order = 402,
            name = L["BAR_TEXTURE"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.foregroundStyle,
            useOldStyle = true,
            height = 200,
            generator = function(dropdown, rootDescription, settingObject)
                dropdown.texturePool = {}

                local layoutName = LEM.GetActiveLayoutName() or "Default"
                local data = GetBarData(config, layoutName)
                if not data then return end

                if not dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked then
                    hooksecurefunc(dropdown, "OnMenuClosed", function()
                        for _, texture in pairs(dropdown.texturePool) do
                            texture:Hide()
                        end
                    end)
                    dropdown._SUI_Foreground_Dropdown_OnMenuClosed_hooked = true
                end

                dropdown:SetDefaultText(settingObject.get(layoutName))

                local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
                local sortedTextures = {}
                for textureName in pairs(textures) do
                    table.insert(sortedTextures, textureName)
                end
                table.sort(sortedTextures)

                for index, textureName in ipairs(sortedTextures) do
                    local texturePath = textures[textureName]

                    local button = rootDescription:CreateButton(textureName, function()
                        dropdown:SetDefaultText(textureName)
                        settingObject.set(layoutName, textureName)
                    end)

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
        },
        {
            parentId = L["CATEGORY_BAR_STYLE"],
            order = 403,
            name = L["BACKGROUND"],
            kind = LEM.SettingType.DropdownColor,
            default = defaults.backgroundStyle,
            colorDefault = defaults.backgroundColor,
            useOldStyle = true,
            height = 200,
            generator = function(dropdown, rootDescription, settingObject)
                dropdown.texturePool = {}

                local layoutName = LEM.GetActiveLayoutName() or "Default"
                local data = GetBarData(config, layoutName)
                if not data then return end

                if not dropdown._SUI_Background_Dropdown_OnMenuClosed_hooked then
                    hooksecurefunc(dropdown, "OnMenuClosed", function()
                        for _, texture in pairs(dropdown.texturePool) do
                            texture:Hide()
                        end
                    end)
                    dropdown._SUI_Background_Dropdown_OnMenuClosed_hooked = true
                end

                dropdown:SetDefaultText(settingObject.get(layoutName))

                local textures = LSM:HashTable(LSM.MediaType.BACKGROUND)
                local sortedTextures = CopyTable(RB.availableBackgroundStyles)
                for textureName in pairs(textures) do
                    table.insert(sortedTextures, textureName)
                end
                table.sort(sortedTextures)

                for index, textureName in ipairs(sortedTextures) do
                    local texturePath = textures[textureName]

                    local button = rootDescription:CreateButton(textureName, function()
                        dropdown:SetDefaultText(textureName)
                        settingObject.set(layoutName, textureName)
                    end)

                    if texturePath then
                        button:AddInitializer(function(self)
                            local textureBackground = dropdown.texturePool[index]
                            if not textureBackground then
                                textureBackground = dropdown:CreateTexture(nil, "BACKGROUND")
                                dropdown.texturePool[index] = textureBackground
                            end

                            textureBackground:SetParent(self)
                            textureBackground:SetAllPoints(self)
                            textureBackground:SetTexture(texturePath)

                            textureBackground:Show()
                        end)
                    end
                end
            end,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.backgroundStyle) or defaults.backgroundStyle
            end,
            colorGet = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.backgroundColor or defaults.backgroundColor
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.backgroundStyle = value
                    bar:ApplyLayout(layoutName)
                end
            end,
            colorSet = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.backgroundColor = value
                    bar:ApplyBackgroundSettings(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_BAR_STYLE"],
            order = 404,
            name = L["USE_BAR_COLOR_FOR_BACKGROUND_COLOR"],
            kind = LEM.SettingType.Checkbox,
            default = defaults.useStatusBarColorForBackgroundColor,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                if data and data.useStatusBarColorForBackgroundColor ~= nil then
                    return data.useStatusBarColorForBackgroundColor
                else
                    return defaults.useStatusBarColorForBackgroundColor
                end
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.useStatusBarColorForBackgroundColor = value
                    bar:ApplyBackgroundSettings(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_BAR_STYLE"],
            order = 405,
            name = L["BORDER"],
            kind = LEM.SettingType.DropdownColor,
            default = defaults.maskAndBorderStyle,
            colorDefault = defaults.borderColor,
            useOldStyle = true,
            values = RB.availableMaskAndBorderStyles,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.maskAndBorderStyle) or defaults.maskAndBorderStyle
            end,
            colorGet = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.borderColor or defaults.borderColor
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.maskAndBorderStyle = value
                    bar:ApplyMaskAndBorderSettings(layoutName)
                end
            end,
            colorSet = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.borderColor = value
                    bar:ApplyMaskAndBorderSettings(layoutName)
                end
            end,
        },
        -- TEXT SETTINGS CATEGORY
        {
            order = 500,
            name = L["CATEGORY_TEXT_SETTINGS"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_TEXT_SETTINGS"],
            defaultCollapsed = true,
        },
        {
            parentId = L["CATEGORY_TEXT_SETTINGS"],
            order = 501,
            name = L["SHOW_RESOURCE_NUMBER"],
            kind = LEM.SettingType.CheckboxColor,
            default = defaults.showText,
            colorDefault = defaults.textColor,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                if data and data.showText ~= nil then
                    return data.showText
                else
                    return defaults.showText
                end
            end,
            colorGet = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.textColor or defaults.textColor
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.showText = value
                    bar:ApplyTextVisibilitySettings(layoutName)
                end
            end,
            colorSet = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.textColor = value
                    bar:ApplyFontSettings(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_TEXT_SETTINGS"],
            order = 502,
            name = L["RESOURCE_NUMBER_FORMAT"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.textFormat,
            useOldStyle = true,
            values = RB.availableTextFormats,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.textFormat) or defaults.textFormat
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.textFormat = value
                    bar:UpdateDisplay(layoutName)
                end
            end,
            tooltip = L["RESOURCE_NUMBER_FORMAT_TOOLTIP"],
            isEnabled = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.showText
            end,
        },
        {
            parentId = L["CATEGORY_TEXT_SETTINGS"],
            order = 503,
            name = L["RESOURCE_NUMBER_PRECISION"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.textPrecision,
            useOldStyle = true,
            values = RB.availableTextPrecisions,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.textPrecision) or defaults.textPrecision
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.textPrecision = value
                    bar:UpdateDisplay(layoutName)
                end
            end,
            isEnabled = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.showText and RB.textPrecisionAllowedForType[data.textFormat] ~= nil
            end,
        },
        {
            parentId = L["CATEGORY_TEXT_SETTINGS"],
            order = 504,
            name = L["RESOURCE_NUMBER_ALIGNMENT"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.textAlign,
            useOldStyle = true,
            values = RB.availableTextAlignmentStyles,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.textAlign) or defaults.textAlign
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.textAlign = value
                    bar:ApplyFontSettings(layoutName)
                end
            end,
            isEnabled = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and data.showText
            end,
        },
        -- FONT CATEGORY
        {
            order = 600,
            name = L["CATEGORY_FONT"],
            kind = LEM.SettingType.Collapsible,
            id = L["CATEGORY_FONT"],
            defaultCollapsed = true,
        },
        {
            parentId = L["CATEGORY_FONT"],
            order = 601,
            name = L["FONT"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.font,
            useOldStyle = true,
            height = 200,
            generator = function(dropdown, rootDescription, settingObject)
                dropdown.fontPool = {}

                local layoutName = LEM.GetActiveLayoutName() or "Default"
                local data = GetBarData(config, layoutName)
                if not data then return end

                if not dropdown._SUI_FontFace_Dropdown_OnMenuClosed_hooked then
                    hooksecurefunc(dropdown, "OnMenuClosed", function()
                        for _, fontDisplay in pairs(dropdown.fontPool) do
                            fontDisplay:Hide()
                        end
                    end)
                    dropdown._SUI_FontFace_Dropdown_OnMenuClosed_hooked = true
                end

                local fonts = LSM:HashTable(LSM.MediaType.FONT)
                local sortedFonts = {}
                for fontName in pairs(fonts) do
                    table.insert(sortedFonts, fontName)
                end
                table.sort(sortedFonts)

                for index, fontName in ipairs(sortedFonts) do
                    local fontPath = fonts[fontName]

                    local button = rootDescription:CreateRadio(fontName, function(d)
                        return d.get(layoutName) == d.value
                    end, function(d)
                        d.set(layoutName, d.value)
                    end, {
                        get = settingObject.get,
                        set = settingObject.set,
                        value = fontPath
                    })

                    button:AddInitializer(function(self)
                        local fontDisplay = dropdown.fontPool[index]
                        if not fontDisplay then
                            fontDisplay = dropdown:CreateFontString(nil, "BACKGROUND")
                            dropdown.fontPool[index] = fontDisplay
                        end

                        self.fontString:Hide()

                        fontDisplay:SetParent(self)
                        fontDisplay:SetPoint("LEFT", self.fontString, "LEFT", 0, 0)
                        fontDisplay:SetFont(fontPath, 12)
                        fontDisplay:SetText(fontName)
                        fontDisplay:Show()
                    end)
                end
            end,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.font) or defaults.font
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.font = value
                    bar:ApplyFontSettings(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_FONT"],
            order = 602,
            name = L["FONT_SIZE"],
            kind = LEM.SettingType.Slider,
            default = defaults.fontSize,
            minValue = 5,
            maxValue = 50,
            valueStep = 1,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return data and RB.rounded(data.fontSize) or defaults.fontSize
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.fontSize = RB.rounded(value)
                    bar:ApplyFontSettings(layoutName)
                end
            end,
        },
        {
            parentId = L["CATEGORY_FONT"],
            order = 603,
            name = L["FONT_OUTLINE"],
            kind = LEM.SettingType.Dropdown,
            default = defaults.fontOutline,
            useOldStyle = true,
            values = RB.availableOutlineStyles,
            get = function(layoutName)
                local data = GetBarData(config, layoutName)
                return (data and data.fontOutline) or defaults.fontOutline
            end,
            set = function(layoutName, value)
                local data = EnsureBarData(config, layoutName, defaults)
                if data then
                    data.fontOutline = value
                    bar:ApplyFontSettings(layoutName)
                end
            end,
        },
    }

    -- Add config-specific settings
    if config.lemSettings and type(config.lemSettings) == "function" then
        local customSettings = config.lemSettings(bar, defaults)
        for _, setting in ipairs(customSettings) do
            table.insert(settings, setting)
        end
    end

    -- Sort settings by order field
    table.sort(settings, function(a, b)
        local orderA = a.order or 999
        local orderB = b.order or 999
        return orderA < orderB
    end)

    return settings
end

function LEMSettingsLoaderMixin:Init(bar, defaults)
    self.bar = bar
    self.defaults = CopyTable(defaults)

    local frame = bar:GetFrame()
    local config = bar:GetConfig()

    -- Ensure database is initialized
    local db = RB.GetResourceBarsDB()

    local function OnPositionChanged(frame, layoutName, point, x, y)
        local data = EnsureBarData(config, layoutName, defaults)
        if data then
            data.point = point
            data.relativePoint = point
            data.x = x
            data.y = y
            bar:ApplyLayout(layoutName)
            LEM.internal:RefreshSettingValues({ L["X_POSITION"], L["Y_POSITION"] })
        end
    end

    LEM:RegisterCallback("enter", function()
        bar:ApplyVisibilitySettings()
        bar:ApplyLayout(nil, true)
        bar:UpdateDisplay(nil, true)
    end)

    LEM:RegisterCallback("exit", function()
        bar:ApplyVisibilitySettings()
        bar:ApplyLayout(nil, true)
        bar:UpdateDisplay(nil, true)
    end)

    LEM:RegisterCallback("layout", function(layoutName)
        local data = EnsureBarData(config, layoutName, defaults)
        bar:OnLayoutChange(layoutName)
        bar:InitCooldownManagerWidthHook(layoutName)
        bar:ApplyVisibilitySettings(layoutName)
        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end)

    LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
        local db = RB.GetResourceBarsDB()
        local original = LEM:GetLayouts()[duplicateIndices[1]].name
        local originalData = GetBarData(config, original)
        db[config.dbName][layoutName] = originalData and CopyTable(originalData) or CopyTable(defaults)
        bar:InitCooldownManagerWidthHook(layoutName)
        bar:ApplyVisibilitySettings(layoutName)
        bar:ApplyLayout(layoutName, true)
        bar:UpdateDisplay(layoutName, true)
    end)

    LEM:RegisterCallback("layoutrenamed", function(oldLayoutName, newLayoutName)
        local db = RB.GetResourceBarsDB()
        local oldData = GetBarData(config, oldLayoutName)
        db[config.dbName][newLayoutName] = oldData and CopyTable(oldData) or CopyTable(defaults)
        db[config.dbName][oldLayoutName] = nil
        bar:InitCooldownManagerWidthHook(newLayoutName)
        bar:ApplyVisibilitySettings()
        bar:ApplyLayout()
        bar:UpdateDisplay()
    end)

    LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
        local db = RB.GetResourceBarsDB()
        if db[config.dbName] then
            db[config.dbName][layoutName] = nil
        end
        bar:ApplyVisibilitySettings()
        bar:ApplyLayout()
        bar:UpdateDisplay()
    end)

    LEM:AddFrame(frame, OnPositionChanged, defaults)
end

function LEMSettingsLoaderMixin:LoadSettings()
    local frame = self.bar:GetFrame()

    LEM:AddFrameSettings(frame, BuildLemSettings(self.bar, self.defaults))

    local buttonSettings = {
        {
            text = L["EXPORT_BAR"],
            click = function()
                local exportString = RB.exportBarAsString(self.bar:GetConfig().dbName)
                if not exportString then
                    RB.prettyPrint(L["EXPORT_FAILED"])
                    return
                end
                StaticPopupDialogs["SUI_RB_EXPORT_SETTINGS"] = StaticPopupDialogs["SUI_RB_EXPORT_SETTINGS"]
                    or {
                        text = L["EXPORT"],
                        button1 = L["CLOSE"],
                        hasEditBox = true,
                        editBoxWidth = 320,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                StaticPopupDialogs["SUI_RB_EXPORT_SETTINGS"].OnShow = function(self)
                    self:SetFrameStrata("TOOLTIP")
                    local editBox = self.editBox or self:GetEditBox()
                    editBox:SetText(exportString)
                    editBox:HighlightText()
                    editBox:SetFocus()
                end
                StaticPopup_Show("SUI_RB_EXPORT_SETTINGS")
            end,
        },
        {
            text = L["IMPORT_BAR"],
            click = function()
                local dbName = self.bar:GetConfig().dbName
                StaticPopupDialogs["SUI_RB_IMPORT_SETTINGS"] = StaticPopupDialogs["SUI_RB_IMPORT_SETTINGS"]
                    or {
                        text = L["IMPORT"],
                        button1 = L["OKAY"],
                        button2 = L["CANCEL"],
                        hasEditBox = true,
                        editBoxWidth = 320,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                StaticPopupDialogs["SUI_RB_IMPORT_SETTINGS"].OnShow = function(self)
                    self:SetFrameStrata("TOOLTIP")
                    local editBox = self.editBox or self:GetEditBox()
                    editBox:SetText("")
                    editBox:SetFocus()
                end
                StaticPopupDialogs["SUI_RB_IMPORT_SETTINGS"].EditBoxOnEnterPressed = function(editBox)
                    local parent = editBox:GetParent()
                    if parent and parent.button1 then parent.button1:Click() end
                end
                StaticPopupDialogs["SUI_RB_IMPORT_SETTINGS"].OnAccept = function(self)
                    local editBox = self.editBox or self:GetEditBox()
                    local input = editBox:GetText() or ""

                    local ok, error = RB.importBarAsString(input, dbName)
                    if not ok then
                        RB.prettyPrint(L["IMPORT_FAILED_WITH_ERROR"] .. error)
                    end

                    RB.fullUpdateBars()
                    LEM.internal:RefreshSettingValues()
                end
                StaticPopup_Show("SUI_RB_IMPORT_SETTINGS")
            end
        }
    }

    if LEM.AddFrameSettingsButtons then
        LEM:AddFrameSettingsButtons(frame, buttonSettings)
    else
        for _, buttonSetting in ipairs(buttonSettings) do
            LEM:AddFrameSettingsButton(frame, buttonSetting)
        end
    end
end

RB.LEMSettingsLoaderMixin = LEMSettingsLoaderMixin
