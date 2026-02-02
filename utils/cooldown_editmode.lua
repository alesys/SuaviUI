-- cooldown_editmode.lua
-- EditMode settings integration for CooldownManagerCentered features
-- Adds growth direction dropdowns and square icon settings to Essential/Utility/BuffIcon/BuffBar viewers
--
-- NOTE: This module is DISABLED because it triggers a Blizzard bug in EncounterWarnings
-- when entering Edit Mode. The settings are available in the SuaviUI Options panel instead.
-- Re-enable when Blizzard fixes the EncounterWarnings secret value comparison bug.

local _, SUI = ...

-- Early exit to prevent triggering Blizzard's Edit Mode bug
-- This file is intentionally empty/disabled
