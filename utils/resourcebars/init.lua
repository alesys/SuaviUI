--- SuaviUI Resource Bars Module
-- Initializes all resource bars with LibEQOL Edit Mode integration

local ADDON_NAME, ns = ...
local SUICore = ns.Addon

-- Load all required libraries and modules
local LEM = LibStub("LibEQOLEditMode-1.0")
local LSM = LibStub("LibSharedMedia-3.0")

-- Create namespace for bars
SUICore.bars = {}

-- Position change callback - save to database
local function OnBarPositionChanged(barFrame, layoutName, point, x, y)
    local dbName = barFrame.dbName  -- Use dbName not barKey
    if not SUICore.db.profile.resourceBars[dbName] then return end
    
    local layout = SUICore.db.profile.resourceBars[dbName][layoutName]
    if layout then
        layout.point = point
        layout.relativePoint = point  -- Also update relativePoint to match
        layout.x = x
        layout.y = y
        
        -- Refresh position sliders in settings panel (don't call ApplyLayout - LibEQOL handles visual)
        LEM.internal:RefreshSettingValues({"X Position", "Y Position"})
    end
end

-- Register bar with LibEQOL
local function RegisterBar(barFrame, dbName)
    if not LEM or not barFrame then return end
    
    -- Don't overwrite barKey - it's already set correctly in Initialize()
    -- barFrame.barKey is already set to "primary", "secondary", etc.
    -- dbName is "primaryPowerBar", "secondaryPowerBar", etc.
    
    -- Get database reference for this bar
    local function GetDBForLayout(layoutName)
        layoutName = layoutName or LEM.activeLayoutName
        
        -- Ensure layout exists - if not, copy from Default
        if not SUICore.db.profile.resourceBars[dbName][layoutName] then
            -- Deep copy Default layout to new layout
            local defaults = SUICore.db.profile.resourceBars[dbName]["Default"]
            if defaults then
                SUICore.db.profile.resourceBars[dbName][layoutName] = CopyTable(defaults)
            end
        end
        
        return SUICore.db.profile.resourceBars[dbName][layoutName]
    end
    
    -- Get default layout to extract position defaults
    local db = GetDBForLayout("Default")
    
    -- Build defaults table for position (LibEQOL expects a table, not a function)
    local defaults = {
        point = db.point or "CENTER",
        relativeFrame = "UIParent",  -- LibEQOL uses relativeFrame, not relativeTo
        relativePoint = db.relativePoint or "CENTER",
        x = db.x or 0,
        y = db.y or 0
    }
    
    -- Register with LEM for Edit Mode support
    LEM:AddFrame(barFrame, OnBarPositionChanged, defaults)
    
    -- Get screen dimensions for position sliders
    local uiWidth, uiHeight = GetPhysicalScreenSize()
    uiWidth = uiWidth / 2
    uiHeight = uiHeight / 2
    
    -- Add comprehensive settings panel (matching Sensei implementation)
    local settings = {
        -- Bar Visibility Section
        {
            order = 100,
            name = "Bar Visibility",
            kind = LEM.SettingType.Collapsible,
            id = "visibility",
        },
        {
            order = 101,
            name = "Enabled",
            kind = LEM.SettingType.Checkbox,
            parentId = "visibility",
            get = function(layout) return GetDBForLayout(layout).enabled end,
            set = function(layout, value) 
                GetDBForLayout(layout).enabled = value
                barFrame:ApplyLayout(layout)
            end,
            default = true,
        },
        {
            order = 102,
            name = "Bar Strata",
            kind = LEM.SettingType.Dropdown,
            parentId = "visibility",
            get = function(layout) return GetDBForLayout(layout).barStrata or "MEDIUM" end,
            set = function(layout, value)
                GetDBForLayout(layout).barStrata = value
                barFrame:SetFrameStrata(value)
            end,
            useOldStyle = true,
            values = {
                { text = "TOOLTIP" },
                { text = "DIALOG" },
                { text = "HIGH" },
                { text = "MEDIUM" },
                { text = "LOW" },
                { text = "BACKGROUND" },
            },
            default = "MEDIUM",
        },
        {
            order = 104,
            name = "Hide While Mounted Or In Vehicle",
            kind = LEM.SettingType.Checkbox,
            parentId = "visibility",
            get = function(layout) return GetDBForLayout(layout).hideWhileMountedOrVehicule or false end,
            set = function(layout, value)
                GetDBForLayout(layout).hideWhileMountedOrVehicule = value
                barFrame:ApplyLayout(layout)
            end,
            default = false,
        },
        
        -- Position & Size Section
        {
            order = 200,
            name = "Position & Size",
            kind = LEM.SettingType.Collapsible,
            id = "position",
        },
        {
            order = 202,
            name = "X Position",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = uiWidth * -1,
            maxValue = uiWidth,
            valueStep = 1,
            allowInput = true,
            get = function(layout) return GetDBForLayout(layout).x or 0 end,
            set = function(layout, value)
                GetDBForLayout(layout).x = value
                barFrame:ApplyLayout(layout)
            end,
            default = 0,
        },
        {
            order = 203,
            name = "Y Position",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = uiHeight * -1,
            maxValue = uiHeight,
            valueStep = 1,
            allowInput = true,
            get = function(layout) return GetDBForLayout(layout).y or 0 end,
            set = function(layout, value)
                GetDBForLayout(layout).y = value
                barFrame:ApplyLayout(layout)
            end,
            default = 0,
        },
        {
            order = 204,
            name = "Relative Frame",
            kind = LEM.SettingType.Dropdown,
            parentId = "position",
            get = function(layout) return GetDBForLayout(layout).relativeTo or "UIParent" end,
            set = function(layout, value)
                local db = GetDBForLayout(layout)
                db.relativeTo = value
                -- Reset position when changing relative frame to avoid unexpected placement
                db.x = 0
                db.y = 0
                db.point = "CENTER"
                db.relativePoint = "CENTER"
                barFrame:ApplyLayout(layout)
                LEM.internal:RefreshSettingValues({"X Position", "Y Position", "Anchor Point", "Relative Point"})
            end,
            useOldStyle = true,
            values = ns.ResourceBars.helpers.getAvailableRelativeFrames(barFrame.barKey),
            default = "UIParent",
        },
        {
            order = 205,
            name = "Anchor Point",
            kind = LEM.SettingType.Dropdown,
            parentId = "position",
            get = function(layout) return GetDBForLayout(layout).point or "CENTER" end,
            set = function(layout, value)
                GetDBForLayout(layout).point = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            values = {
                { text = "TOPLEFT" },
                { text = "TOP" },
                { text = "TOPRIGHT" },
                { text = "LEFT" },
                { text = "CENTER" },
                { text = "RIGHT" },
                { text = "BOTTOMLEFT" },
                { text = "BOTTOM" },
                { text = "BOTTOMRIGHT" },
            },
            default = "CENTER",
        },
        {
            order = 206,
            name = "Relative Point",
            kind = LEM.SettingType.Dropdown,
            parentId = "position",
            get = function(layout) return GetDBForLayout(layout).relativePoint or "CENTER" end,
            set = function(layout, value)
                GetDBForLayout(layout).relativePoint = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            values = {
                { text = "TOPLEFT" },
                { text = "TOP" },
                { text = "TOPRIGHT" },
                { text = "LEFT" },
                { text = "CENTER" },
                { text = "RIGHT" },
                { text = "BOTTOMLEFT" },
                { text = "BOTTOM" },
                { text = "BOTTOMRIGHT" },
            },
            default = "CENTER",
        },
        {
            order = 210,
            kind = LEM.SettingType.Divider,
            parentId = "position",
        },
        {
            order = 211,
            name = "Bar Size",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = 0.25,
            maxValue = 2,
            valueStep = 0.01,
            formatter = function(value) return string.format("%d%%", value * 100) end,
            get = function(layout) return GetDBForLayout(layout).scale or 1 end,
            set = function(layout, value)
                GetDBForLayout(layout).scale = value
                barFrame:ApplyLayout(layout)
            end,
            default = 1,
        },
        {
            order = 212,
            name = "Width Mode",
            kind = LEM.SettingType.Dropdown,
            parentId = "position",
            get = function(layout) return GetDBForLayout(layout).widthMode or "Manual" end,
            set = function(layout, value)
                GetDBForLayout(layout).widthMode = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            values = {
                { text = "Manual" },
            },
            default = "Manual",
        },
        {
            order = 213,
            name = "Width",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = 1,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layout) return GetDBForLayout(layout).width or 326 end,
            set = function(layout, value)
                GetDBForLayout(layout).width = value
                barFrame:ApplyLayout(layout)
            end,
            isEnabled = function(layout)
                return (GetDBForLayout(layout).widthMode or "Manual") == "Manual"
            end,
            default = 326,
        },
        {
            order = 214,
            name = "Minimum Width",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = 0,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layout) return GetDBForLayout(layout).minWidth or 0 end,
            set = function(layout, value)
                GetDBForLayout(layout).minWidth = value
                barFrame:ApplyLayout(layout)
            end,
            default = 0,
        },
        {
            order = 215,
            name = "Height",
            kind = LEM.SettingType.Slider,
            parentId = "position",
            minValue = 1,
            maxValue = 500,
            valueStep = 1,
            allowInput = true,
            get = function(layout) return GetDBForLayout(layout).height or 8 end,
            set = function(layout, value)
                GetDBForLayout(layout).height = value
                barFrame:ApplyLayout(layout)
            end,
            default = 8,
        },
        
        -- Bar Settings Section
        {
            order = 300,
            name = "Bar Settings",
            kind = LEM.SettingType.Collapsible,
            id = "barSettings",
            defaultCollapsed = true,
        },
        {
            order = 301,
            name = "Fill Direction",
            kind = LEM.SettingType.Dropdown,
            parentId = "barSettings",
            get = function(layout) return GetDBForLayout(layout).fillDirection or "Left to Right" end,
            set = function(layout, value)
                GetDBForLayout(layout).fillDirection = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            values = {
                { text = "Left to Right" },
                { text = "Right to Left" },
                { text = "Top to Bottom" },
                { text = "Bottom to Top" },
            },
            default = "Left to Right",
        },
        {
            order = 302,
            name = "Smooth Progress",
            kind = LEM.SettingType.Checkbox,
            parentId = "barSettings",
            get = function(layout) return GetDBForLayout(layout).smoothProgress ~= false end,
            set = function(layout, value)
                GetDBForLayout(layout).smoothProgress = value
                barFrame:ApplyLayout(layout)
            end,
            default = true,
        },
        
        -- Bar Style Section
        {
            order = 400,
            name = "Bar Style",
            kind = LEM.SettingType.Collapsible,
            id = "style",
            defaultCollapsed = true,
        },
        {
            order = 401,
            name = "Texture",
            kind = LEM.SettingType.Dropdown,
            parentId = "style",
            get = function(layout) return GetDBForLayout(layout).texture or "Suavi v5" end,
            set = function(layout, value)
                GetDBForLayout(layout).texture = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            height = 200,
            generator = function(dropdown, rootDescription, settingObject)
                local layoutName = LEM.GetActiveLayoutName() or "Default"
                dropdown:SetDefaultText(settingObject.get(layoutName))

                local LSM = LibStub("LibSharedMedia-3.0", true)
                if not LSM then 
                    rootDescription:CreateButton("Suavi v5", function()
                        dropdown:SetDefaultText("Suavi v5")
                        settingObject.set(layoutName, "Suavi v5")
                    end)
                    return
                end
                
                local textures = LSM:HashTable(LSM.MediaType.STATUSBAR)
                local sortedTextures = {}
                for textureName in pairs(textures) do
                    table.insert(sortedTextures, textureName)
                end
                table.sort(sortedTextures)

                for _, textureName in ipairs(sortedTextures) do
                    rootDescription:CreateButton(textureName, function()
                        dropdown:SetDefaultText(textureName)
                        settingObject.set(layoutName, textureName)
                    end)
                end
            end,
            default = "Suavi v5",
        },
        {
            order = 403,
            name = "Border Size",
            kind = LEM.SettingType.Slider,
            parentId = "style",
            minValue = 0,
            maxValue = 5,
            valueStep = 1,
            get = function(layout) return GetDBForLayout(layout).borderSize or 1 end,
            set = function(layout, value)
                GetDBForLayout(layout).borderSize = value
                barFrame:ApplyLayout(layout)
            end,
            default = 1,
        },
        
        -- Text Settings Section
        {
            order = 500,
            name = "Text Settings",
            kind = LEM.SettingType.Collapsible,
            id = "text",
            defaultCollapsed = true,
        },
        {
            order = 501,
            name = "Show Text",
            kind = LEM.SettingType.Checkbox,
            parentId = "text",
            get = function(layout) return GetDBForLayout(layout).showText ~= false end,
            set = function(layout, value)
                GetDBForLayout(layout).showText = value
                barFrame:ApplyLayout(layout)
            end,
            default = true,
        },
        {
            order = 502,
            name = "Show Percent",
            kind = LEM.SettingType.Checkbox,
            parentId = "text",
            get = function(layout) return GetDBForLayout(layout).showPercent ~= false end,
            set = function(layout, value)
                GetDBForLayout(layout).showPercent = value
                barFrame:ApplyLayout(layout)
            end,
            isEnabled = function(layout) return GetDBForLayout(layout).showText ~= false end,
            default = true,
        },
        {
            order = 503,
            name = "Text Size",
            kind = LEM.SettingType.Slider,
            parentId = "text",
            minValue = 8,
            maxValue = 32,
            valueStep = 1,
            get = function(layout) return GetDBForLayout(layout).textSize or 14 end,
            set = function(layout, value)
                GetDBForLayout(layout).textSize = value
                barFrame:ApplyLayout(layout)
            end,
            isEnabled = function(layout) return GetDBForLayout(layout).showText ~= false end,
            default = 14,
        },
        {
            order = 504,
            name = "Text Alignment",
            kind = LEM.SettingType.Dropdown,
            parentId = "text",
            get = function(layout) return GetDBForLayout(layout).textAlign or "CENTER" end,
            set = function(layout, value)
                GetDBForLayout(layout).textAlign = value
                barFrame:ApplyLayout(layout)
            end,
            useOldStyle = true,
            values = {
                { text = "LEFT" },
                { text = "CENTER" },
                { text = "RIGHT" },
            },
            isEnabled = function(layout) return GetDBForLayout(layout).showText ~= false end,
            default = "CENTER",
        },
    }
    
    LEM:AddFrameSettings(barFrame, settings)
    
    -- Register LibEQOL callbacks for layout management
    LEM:RegisterCallback("enter", function()
        barFrame:ApplyLayout()
        -- Ensure drag is enabled when entering Edit Mode (if relative to UIParent)
        local db = GetDBForLayout(LEM.GetActiveLayoutName() or "Default")
        if db and (not db.relativeTo or db.relativeTo == "UIParent") then
            LEM:SetFrameDragEnabled(barFrame, true)
        end
    end)
    
    LEM:RegisterCallback("exit", function()
        barFrame:ApplyLayout()
    end)
    
    LEM:RegisterCallback("layout", function(layoutName)
        -- Ensure layout exists
        if not SUICore.db.profile.resourceBars[dbName][layoutName] then
            local defaults = SUICore.db.profile.resourceBars[dbName]["Default"]
            if defaults then
                SUICore.db.profile.resourceBars[dbName][layoutName] = CopyTable(defaults)
            end
        end
        barFrame:ApplyLayout(layoutName, true)
    end)
    
    LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
        local layouts = LEM:GetLayouts()
        if layouts and layouts[duplicateIndices[1]] then
            local original = layouts[duplicateIndices[1]].name
            if SUICore.db.profile.resourceBars[dbName][original] then
                SUICore.db.profile.resourceBars[dbName][layoutName] = CopyTable(SUICore.db.profile.resourceBars[dbName][original])
            end
        end
        barFrame:ApplyLayout(layoutName, true)
    end)
    
    LEM:RegisterCallback("layoutrenamed", function(oldLayoutName, newLayoutName)
        if SUICore.db.profile.resourceBars[dbName][oldLayoutName] then
            SUICore.db.profile.resourceBars[dbName][newLayoutName] = CopyTable(SUICore.db.profile.resourceBars[dbName][oldLayoutName])
            SUICore.db.profile.resourceBars[dbName][oldLayoutName] = nil
        end
        barFrame:ApplyLayout()
    end)
    
    LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
        if SUICore.db.profile.resourceBars[dbName] then
            SUICore.db.profile.resourceBars[dbName][layoutName] = nil
        end
        barFrame:ApplyLayout()
    end)
end

-- Database defaults
local function GetDefaults()
    return {
        resourceBars = {
            -- Health Bar
            healthBar = {
                ["Default"] = {
                    enabled = false,
                    width = 326,
                    height = 20,
                    x = 0,
                    y = 100,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    texture = "Suavi v5",
                    bgColor = { 0.078, 0.078, 0.078, 0.83 },
                    borderSize = 1,
                    showText = true,
                    showPercent = true,
                    textSize = 14,
                },
            },
            -- Primary Power Bar
            primaryPowerBar = {
                ["Default"] = {
                    enabled = true,
                    width = 326,
                    height = 8,
                    x = 0,
                    y = -204,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    texture = "Suavi v5",
                    bgColor = { 0.078, 0.078, 0.078, 1 },
                    borderSize = 1,
                    colorMode = "power",
                    usePowerColor = true,
                    useClassColor = false,
                    useCustomColor = false,
                    customColor = { 0.2, 0.6, 1, 1 },
                    showText = true,
                    showPercent = true,
                    textSize = 16,
                    textX = 1,
                    textY = 3,
                    textUseClassColor = false,
                    textCustomColor = { 1, 1, 1, 1 },
                    showTicks = false,
                    tickThickness = 2,
                    tickColor = { 0, 0, 0, 1 },
                    alignTo = "none",
                    widthSync = "none",
                    snapGap = 5,
                    orientation = "HORIZONTAL",
                },
            },
            -- Secondary Power Bar
            secondaryPowerBar = {
                ["Default"] = {
                    enabled = true,
                    width = 326,
                    height = 8,
                    x = 0,
                    y = -220,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    texture = "Suavi v5",
                    bgColor = { 0.078, 0.078, 0.078, 0.83 },
                    borderSize = 1,
                    colorMode = "power",
                    usePowerColor = true,
                    useClassColor = false,
                    useCustomColor = false,
                    customColor = { 1, 0.8, 0.2, 1 },
                    showText = false,
                    showPercent = false,
                    textSize = 14,
                    textX = 0,
                    textY = 2,
                    textUseClassColor = false,
                    textCustomColor = { 1, 1, 1, 1 },
                    showTicks = true,
                    tickThickness = 2,
                    tickColor = { 0, 0, 0, 1 },
                    showFragmentedPowerBarText = false,
                    alignTo = "primary",
                    widthSync = "primary",
                    snapGap = 5,
                    orientation = "AUTO",
                },
            },
            -- Tertiary Power Bar
            tertiaryPowerBar = {
                ["Default"] = {
                    enabled = false,
                    width = 326,
                    height = 8,
                    x = 0,
                    y = -236,
                    point = "CENTER",
                    relativeTo = "UIParent",
                    relativePoint = "CENTER",
                    texture = "Suavi v5",
                    bgColor = { 0.078, 0.078, 0.078, 0.83 },
                    borderSize = 1,
                    colorMode = "power",
                    usePowerColor = true,
                    useClassColor = false,
                    customColor = { 0.5, 0.8, 1, 1 },
                    showText = true,
                    showPercent = false,
                    textSize = 14,
                    textX = 0,
                    textY = 2,
                    textUseClassColor = false,
                    textCustomColor = { 1, 1, 1, 1 },
                    showTicks = false,
                    alignTo = "secondary",
                    widthSync = "secondary",
                    snapGap = 5,
                    orientation = "HORIZONTAL",
                },
            },
            -- Global power colors
            powerColors = ns.PowerColors.defaults,
        }
    }
end

-- Initialize module
local function InitializeResourceBars()
    -- Merge defaults into database
    if not SUICore.db.profile.resourceBars then
        SUICore.db.profile.resourceBars = {}
    end
    
    local defaults = GetDefaults().resourceBars
    for key, value in pairs(defaults) do
        if not SUICore.db.profile.resourceBars[key] then
            if key == "powerColors" then
                -- Migrate power colors from old location
                if SUICore.db.profile.powerColors then
                    SUICore.db.profile.resourceBars.powerColors = SUICore.db.profile.powerColors
                else
                    SUICore.db.profile.resourceBars.powerColors = value
                end
            else
                -- Initialize bar settings
                SUICore.db.profile.resourceBars[key] = {}
                for layout, settings in pairs(value) do
                    SUICore.db.profile.resourceBars[key][layout] = settings
                end
            end
        else
            -- Migrate existing saves: add missing fields from defaults
            if key ~= "powerColors" then
                for layoutName, layoutData in pairs(SUICore.db.profile.resourceBars[key]) do
                    local defaultLayout = value["Default"]
                    if defaultLayout then
                        -- Add relativeTo if missing
                        if not layoutData.relativeTo then
                            layoutData.relativeTo = defaultLayout.relativeTo or "UIParent"
                        end
                        -- Add relativePoint if missing
                        if not layoutData.relativePoint then
                            layoutData.relativePoint = layoutData.point or defaultLayout.relativePoint or "CENTER"
                        end
                    end
                end
            end
        end
    end
    
    -- Create bar instances
    SUICore.bars.health = ns.HealthBar:Create()
    SUICore.bars.health:Initialize()
    RegisterBar(SUICore.bars.health, "healthBar")
    
    SUICore.bars.primary = ns.PrimaryPowerBar:Create()
    SUICore.bars.primary:Initialize()
    RegisterBar(SUICore.bars.primary, "primaryPowerBar")
    
    SUICore.bars.secondary = ns.SecondaryPowerBar:Create()
    SUICore.bars.secondary:Initialize()
    RegisterBar(SUICore.bars.secondary, "secondaryPowerBar")
    
    SUICore.bars.tertiary = ns.TertiaryPowerBar:Create()
    SUICore.bars.tertiary:Initialize()
    RegisterBar(SUICore.bars.tertiary, "tertiaryPowerBar")
    
    -- Initial updates
    SUICore.bars.health:UpdateHealth()
    SUICore.bars.primary:UpdatePower()
    SUICore.bars.secondary:UpdatePower()
    SUICore.bars.tertiary:UpdatePower()
end

-- Helper: get current layout
function SUICore:GetCurrentLayout()
    return "Default"  -- Can extend later for multiple layouts
end

-- Hook into SUICore initialization
local oldOnEnable = SUICore.OnEnable
function SUICore:OnEnable()
    if oldOnEnable then
        oldOnEnable(self)
    end
    
    C_Timer.After(0.1, function()
        InitializeResourceBars()
    end)
end

-- Update all bars
function SUICore:UpdateAllResourceBars()
    if self.bars then
        self.bars.health:UpdateHealth()
        self.bars.primary:UpdatePower()
        self.bars.secondary:UpdatePower()
        self.bars.tertiary:UpdatePower()
    end
end

-- Hook RefreshAll
local oldRefreshAll = SUICore.RefreshAll
function SUICore:RefreshAll()
    if oldRefreshAll then
        oldRefreshAll(self)
    end
    
    self:UpdateAllResourceBars()
end

ns.ResourceBarsModule = {
    GetDefaults = GetDefaults,
    Initialize = InitializeResourceBars,
}

-- Debug command
SLASH_SUIRESBAR1 = "/suibar"
SlashCmdList["SUIRESBAR"] = function(msg)
    if msg == "show" then
        if SUICore.bars then
            print("Showing all bars...")
            if SUICore.bars.primary then
                print("Primary bar exists, forcing show")
                SUICore.bars.primary:ApplyLayout()
                SUICore.bars.primary:UpdatePower()
                print("Primary shown:", SUICore.bars.primary:IsShown())
            end
            if SUICore.bars.secondary then
                SUICore.bars.secondary:ApplyLayout()
                SUICore.bars.secondary:UpdatePower()
            end
        end
    elseif msg == "status" then
        if SUICore.bars and SUICore.bars.primary then
            local db = SUICore.bars.primary:GetDB()
            print("Primary DB:", db and "exists" or "nil")
            if db then
                print("  enabled:", db.enabled)
                print("  position:", db.x, db.y)
                print("  size:", db.width, db.height)
            end
            print("Primary shown:", SUICore.bars.primary:IsShown())
            
            -- Debug resource detection
            print("Bar key:", SUICore.bars.primary.barKey)
            print("Calling GetPrimaryResource...")
            local resource = SUICore:GetPrimaryResource()
            print("GetPrimaryResource returned:", resource)
            local resource2 = SUICore.bars.primary:DetectResource()
            print("DetectResource returned:", resource2)
            if resource then
                local max, current = SUICore.bars.primary:GetResourceValue(resource)
                print("Resource value:", current, "/", max)
            end
        else
            print("Bars not initialized")
        end
    elseif msg == "force" then
        if SUICore.bars and SUICore.bars.primary then
            print("Force showing primary bar...")
            SUICore.bars.primary:ApplyLayout()
            SUICore.bars.primary:Show()
            print("Frame shown:", SUICore.bars.primary:IsShown())
            print("Frame parent:", SUICore.bars.primary:GetParent():GetName())
            print("Frame strata:", SUICore.bars.primary:GetFrameStrata())
            print("Frame size:", SUICore.bars.primary:GetSize())
        end
    end
end
