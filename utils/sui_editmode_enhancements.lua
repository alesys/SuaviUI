-------------------------------------------------------------------------------
-- sui_editmode_enhancements.lua
-- External fixes for LibEQOLEditMode: snap registration, snap anchor
-- persistence, overlay toggle, and overlay-hide bug workaround.
-- Loaded AFTER all editmode registration files so LEM.selectionRegistry
-- is fully populated.
-------------------------------------------------------------------------------
local _, ns = ...
local LEM = LibStub and LibStub("LibEQOLEditMode-1.0", true)
if not LEM then return end

-------------------------------------------------------------------------------
-- Part A: Fix overlay re-showing on click
-- Blizzard's ShowSelected() applies new NineSlice textures (alpha=1) which
-- override the alpha=0 set by LEM's overlay-hide system.  We re-hide them.
-------------------------------------------------------------------------------
local function rehideOverlayTextures(self)
    if self.overlayHidden then
        for _, region in ipairs({ self:GetRegions() }) do
            if region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
    end
end

if EditModeSystemSelectionBaseMixin then
    if EditModeSystemSelectionBaseMixin.ShowSelected then
        hooksecurefunc(EditModeSystemSelectionBaseMixin, "ShowSelected", rehideOverlayTextures)
    end
    if EditModeSystemSelectionBaseMixin.ShowHighlighted then
        hooksecurefunc(EditModeSystemSelectionBaseMixin, "ShowHighlighted", rehideOverlayTextures)
    end
end

-------------------------------------------------------------------------------
-- Part B: Register LEM frames as snap targets
-- Without this, Blizzard frames and other LEM frames cannot snap to ours.
-------------------------------------------------------------------------------
local function registerAllForMagnetism()
    if not EditModeMagnetismManager then return end
    for frame in pairs(LEM.selectionRegistry) do
        EditModeMagnetismManager:RegisterFrame(frame)
    end
end

local function unregisterAllFromMagnetism()
    if not EditModeMagnetismManager then return end
    for frame in pairs(LEM.selectionRegistry) do
        EditModeMagnetismManager:UnregisterFrame(frame)
    end
end

LEM:RegisterCallback("enter", registerAllForMagnetism)
LEM:RegisterCallback("exit", unregisterAllFromMagnetism)

-------------------------------------------------------------------------------
-- Part C: Preserve snap anchors after drag
-- LEM's finishSelectionDrag overwrites the snap anchor with UIParent-relative
-- offsets.  We hook SnapToFrame on each LEM frame to capture the snap info
-- before it's lost.  Position callbacks check frame._suiPendingSnap.
-------------------------------------------------------------------------------
local function hookSnapToFrame(frame)
    if frame._suiSnapHooked or not frame.SnapToFrame then return end
    local origSnap = frame.SnapToFrame
    frame.SnapToFrame = function(self, frameInfo)
        origSnap(self, frameInfo)
        -- Capture the anchor that SnapToFrame just set, before LEM overwrites it
        local p, relTo, relP, offX, offY = self:GetPoint(1)
        if relTo and relTo ~= UIParent and relTo ~= self:GetParent() then
            self._suiPendingSnap = {
                point = p,
                frame = relTo,
                relativePoint = relP,
                offsetX = offX,
                offsetY = offY,
            }
        end
    end
    frame._suiSnapHooked = true
end

local function hookAllSnapToFrame()
    for frame in pairs(LEM.selectionRegistry) do
        hookSnapToFrame(frame)
    end
end

LEM:RegisterCallback("enter", hookAllSnapToFrame)

-------------------------------------------------------------------------------
-- Part D: Enable overlay toggle (eye button) on all LEM frames
-------------------------------------------------------------------------------
local function enableAllOverlayToggles()
    for frame in pairs(LEM.selectionRegistry) do
        LEM:SetFrameOverlayToggleEnabled(frame, true)
    end
end

LEM:RegisterCallback("enter", enableAllOverlayToggles)
