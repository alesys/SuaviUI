---------------------------------------------------------------------------
-- SuaviUI Bags: item categories
-- Pure classification + sorting helpers. No frames, no events.
-- An item is placed in the FIRST enabled category (in the user's order)
-- whose predicate matches; "other" is always the catch-all.
---------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Cat = {}
ns.BagsCategories = Cat

---------------------------------------------------------------------------
-- Category list
---------------------------------------------------------------------------
Cat.DEFAULT_ORDER = {
    "new", "sets", "quest", "junk", "equipment", "consumables", "reagents", "other",
}

Cat.NAMES = {
    new         = "New Items",
    sets        = "Equipment Sets",
    quest       = "Quest",
    junk        = "Junk",
    equipment   = "Equipment",
    consumables = "Consumables",
    reagents    = "Reagents & Trade Goods",
    other       = "Other",
}

-- "other" can never be disabled (it receives everything nothing else claims)
Cat.LOCKED = { other = true }

---------------------------------------------------------------------------
-- Item class ids (numeric fallbacks keep this working if the enum moves)
---------------------------------------------------------------------------
local IC = Enum and Enum.ItemClass or {}
local CLASS_CONSUMABLE  = IC.Consumable      or 0
local CLASS_WEAPON      = IC.Weapon          or 2
local CLASS_GEM         = IC.Gem             or 3
local CLASS_ARMOR       = IC.Armor           or 4
local CLASS_REAGENT     = IC.Reagent         or 5
local CLASS_TRADEGOODS  = IC.Tradegoods      or 7
local CLASS_ENHANCEMENT = IC.ItemEnhancement or 8
local CLASS_QUEST       = IC.Questitem       or 12
local CLASS_PROFESSION  = IC.Profession      or 19

local QUALITY_POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0
local REAGENT_BAG  = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5

Cat.CLASS_WEAPON, Cat.CLASS_ARMOR, Cat.CLASS_PROFESSION = CLASS_WEAPON, CLASS_ARMOR, CLASS_PROFESSION

---------------------------------------------------------------------------
-- Static item info (GetItemInfoInstant never needs the item cache)
---------------------------------------------------------------------------
local instantCache = {}

function Cat.GetInstant(itemID)
    if not itemID then return nil end
    local c = instantCache[itemID]
    if c then return c end
    local _, itemType, itemSubType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then return nil end
    c = {
        itemType   = itemType or "",
        itemSub    = itemSubType or "",
        equipLoc   = equipLoc or "",
        classID    = classID,
        subClassID = subClassID or 0,
    }
    instantCache[itemID] = c
    return c
end

-- isCraftingReagent needs the full item record. Returns true/false, or nil if
-- the record is not cached yet (caller should request a load).
local reagentCache = {}

function Cat.GetIsReagent(itemID)
    local v = reagentCache[itemID]
    if v ~= nil then return v end
    local isReagent = select(17, C_Item.GetItemInfo(itemID))
    if isReagent == nil then return nil end
    reagentCache[itemID] = isReagent and true or false
    return reagentCache[itemID]
end

---------------------------------------------------------------------------
-- Item level (only meaningful for gear)
---------------------------------------------------------------------------
local ilvlCache = {}

function Cat.IsGearClass(classID)
    return classID == CLASS_WEAPON or classID == CLASS_ARMOR or classID == CLASS_PROFESSION
end

-- Returns level (number) or nil when unknown / not cached.
function Cat.GetItemLevel(link, classID)
    if not link or not Cat.IsGearClass(classID) then return nil end
    local lvl = ilvlCache[link]
    if lvl then return lvl end
    lvl = C_Item.GetDetailedItemLevelInfo(link)
    if lvl and lvl > 0 then
        ilvlCache[link] = lvl
        return lvl
    end
    return nil
end

function Cat.ClearCaches()
    wipe(reagentCache)
    wipe(ilvlCache)
end

---------------------------------------------------------------------------
-- Predicates. `e` is a slot entry built by the window:
--   e.bag, e.slot, e.itemID, e.quality, e.classID, e.isQuest, e.inSet, e.isNew, e.isReagent
---------------------------------------------------------------------------
local PREDICATES = {
    new = function(e) return e.isNew end,
    sets = function(e) return e.inSet end,
    quest = function(e) return e.isQuest or e.classID == CLASS_QUEST end,
    junk = function(e) return e.quality == QUALITY_POOR end,
    equipment = function(e)
        local c = e.classID
        return c == CLASS_WEAPON or c == CLASS_ARMOR or c == CLASS_PROFESSION
    end,
    consumables = function(e)
        local c = e.classID
        return c == CLASS_CONSUMABLE or c == CLASS_ENHANCEMENT
    end,
    reagents = function(e)
        local c = e.classID
        return e.bag == REAGENT_BAG or c == CLASS_TRADEGOODS or c == CLASS_GEM
            or c == CLASS_REAGENT or e.isReagent == true
    end,
    other = function() return true end,
}

-- order: array of keys. enabled: map key -> bool (nil counts as enabled).
function Cat.Classify(e, order, enabled)
    for i = 1, #order do
        local key = order[i]
        if key ~= "other" and enabled[key] ~= false then
            local p = PREDICATES[key]
            if p and p(e) then return key end
        end
    end
    return "other"
end

---------------------------------------------------------------------------
-- Ordering helpers
---------------------------------------------------------------------------
-- Returns a clean order array: every known key exactly once, unknown keys
-- dropped, missing keys appended in default order.
function Cat.NormalizeOrder(order)
    local out, seen = {}, {}
    if type(order) == "table" then
        for _, key in ipairs(order) do
            if Cat.NAMES[key] and not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
    end
    for _, key in ipairs(Cat.DEFAULT_ORDER) do
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

-- Comparator used inside a section: gear by item level, everything else by
-- quality, class, name.
function Cat.Compare(a, b)
    local aq, bq = a.quality or 0, b.quality or 0
    if aq ~= bq then return aq > bq end
    local ac, bc = a.classID or 99, b.classID or 99
    if ac ~= bc then return ac < bc end
    local al, bl = a.ilvl or 0, b.ilvl or 0
    if al ~= bl then return al > bl end
    local an, bn = a.sortName or "", b.sortName or ""
    if an ~= bn then return an < bn end
    local ai, bi = a.itemID or 0, b.itemID or 0
    if ai ~= bi then return ai < bi end
    local an2, bn2 = a.count or 0, b.count or 0
    if an2 ~= bn2 then return an2 > bn2 end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end
