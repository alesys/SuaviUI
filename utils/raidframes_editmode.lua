--[[
    Raid & Party Frames - Edit Mode Integration
    Registers the party and raid containers with Blizzard Edit Mode through
    LibEQOLEditMode. Positions are stored per Edit Mode layout in
    profile.suiRaidFrames.positions[layoutName][kind], like the resource bars.
    While Edit Mode is open the frames show fake units so they can be placed solo.
]]

local ADDON_NAME, ns = ...
local LEM = LibStub("LibEQOLEditMode-1.0", true)

local RF_EditMode = {}
ns.RF_EditMode = RF_EditMode

if not LEM then return end

local registered = false

local function RF() return ns.SUI_RaidFrames end

local function GetKindDB(kind)
    local rf = RF()
    local db = rf and rf:GetDB()
    return db and db[kind]
end

local function Refresh()
    local rf = RF()
    if rf then rf:Refresh() end
end

local function OnPositionChanged(frame, layoutName, point, x, y)
    local rf = RF()
    local kind = frame and frame._suirfKind
    if not rf or not kind then return end
    rf:SavePosition(kind, layoutName, point, x, y)
end

local function Slider(list, parentId, order, kind, key, label, minV, maxV, default)
    list[#list + 1] = {
        parentId = parentId,
        order = order,
        name = label,
        kind = LEM.SettingType.Slider,
        default = default,
        minValue = minV,
        maxValue = maxV,
        valueStep = 1,
        allowInput = true,
        formatter = function(value) return string.format("%d", value) end,
        get = function()
            local k = GetKindDB(kind)
            return k and k[key] or default
        end,
        set = function(_, value)
            local k = GetKindDB(kind)
            if k then
                k[key] = value
                Refresh()
            end
        end,
    }
end

local function Checkbox(list, parentId, order, kind, key, label, default)
    list[#list + 1] = {
        parentId = parentId,
        order = order,
        name = label,
        kind = LEM.SettingType.Checkbox,
        default = default,
        get = function()
            local k = GetKindDB(kind)
            if not k then return default end
            return k[key] and true or false
        end,
        set = function(_, value)
            local k = GetKindDB(kind)
            if k then
                k[key] = value and true or false
                Refresh()
            end
        end,
    }
end

local function BuildSettings(kind)
    local s = {}
    local cat = "CATEGORY_SUIRF_" .. kind
    s[#s + 1] = {
        order = 100,
        name = "Layout",
        kind = LEM.SettingType.Collapsible,
        id = cat,
        defaultCollapsed = false,
    }
    if kind == "party" then
        Slider(s, cat, 101, kind, "width", "Width", 40, 300, 120)
        Slider(s, cat, 102, kind, "height", "Height", 16, 120, 46)
        Slider(s, cat, 103, kind, "spacing", "Spacing", 0, 30, 2)
        Checkbox(s, cat, 104, kind, "showPlayer", "Show Player", true)
    else
        Slider(s, cat, 101, kind, "width", "Width", 30, 250, 88)
        Slider(s, cat, 102, kind, "height", "Height", 16, 120, 40)
        Slider(s, cat, 103, kind, "spacing", "Spacing", 0, 30, 2)
        Slider(s, cat, 104, kind, "groupSpacing", "Group Spacing", 0, 40, 6)
        Slider(s, cat, 105, kind, "groupsPerLine", "Groups per Row", 1, 8, 8)
        Slider(s, cat, 106, kind, "maxGroups", "Groups Shown", 1, 8, 8)
        Slider(s, cat, 107, kind, "previewSize", "Preview Size", 5, 40, 20)
    end
    return s
end

local function OpenOptions()
    local gui = _G.SuaviUI and _G.SuaviUI.GUI
    if gui and gui.Show then gui:Show() end
end

function RF_EditMode:Register()
    if registered then return end
    local rf = RF()
    if not rf or not rf.movers.party or not rf.movers.raid then return end

    for _, kind in ipairs({ "party", "raid" }) do
        local mover = rf.movers[kind]
        local def = rf.DEFAULT_POS[kind]
        local ok = pcall(function()
            LEM:AddFrame(mover, OnPositionChanged, { point = def.point, x = def.x, y = def.y })
            LEM:AddFrameSettings(mover, BuildSettings(kind))
            LEM:AddFrameSettingsButton(mover, { text = "More Options", click = OpenOptions })
        end)
        if not ok then return end
    end
    registered = true

    LEM:RegisterCallback("enter", function()
        local r = RF()
        if r then r:SetPreview("editmode", true) end
    end)

    LEM:RegisterCallback("exit", function()
        local r = RF()
        if r then
            r:SetPreview("editmode", false)
            r:ApplyPositions()
        end
    end)

    LEM:RegisterCallback("layout", function(layoutName)
        local r = RF()
        if not r then return end
        r.activeLayoutName = layoutName
        r:ApplyPositions(layoutName)
    end)

    LEM:RegisterCallback("layoutduplicate", function(_, duplicateIndices, _, _, layoutName)
        local r = RF()
        local db = r and r:GetDB()
        if not db then return end
        local layouts = LEM:GetLayouts()
        local source = duplicateIndices and layouts[duplicateIndices[1]]
        local original = source and db.positions[source.name]
        if original then
            db.positions[layoutName] = CopyTable(original)
        end
        r:ApplyPositions(layoutName)
    end)

    LEM:RegisterCallback("layoutrenamed", function(oldName, newName)
        local r = RF()
        local db = r and r:GetDB()
        if not db then return end
        if db.positions[oldName] then
            db.positions[newName] = db.positions[oldName]
            db.positions[oldName] = nil
        end
        if r.activeLayoutName == oldName then r.activeLayoutName = newName end
        r:ApplyPositions()
    end)

    LEM:RegisterCallback("layoutdeleted", function(_, layoutName)
        local r = RF()
        local db = r and r:GetDB()
        if db then db.positions[layoutName] = nil end
    end)

    -- Edit Mode may already be open (module enabled from the options while editing)
    if LEM:IsInEditMode() then rf:SetPreview("editmode", true) end
    rf:ApplyPositions()
end
