--[[
    TEST SCRIPT: Square Icons Styling Fix
    
    HOW TO TEST THE FIX:
    
    1. In-game, open chat and type these commands to test:
    
    -- Check current state:
    /suistyledicons
    
    -- Enable square icons for Essential viewer:
    /run SuaviUI.SUICore.db.profile.cooldownManager_squareIcons_Essential = true
    
    -- Trigger a refresh (enter/exit combat or type):
    /reload
    
    -- Icons should now be square
    
    -- Disable square icons:
    /run SuaviUI.SUICore.db.profile.cooldownManager_squareIcons_Essential = false
    
    -- Trigger another refresh:
    /reload
    
    -- Icons should now be circular (native Blizzard style)
    
    2. Alternative test without reload:
    
    -- Toggle setting:
    /run SuaviUI.SUICore.db.profile.cooldownManager_squareIcons_Essential = false
    
    -- Call the refresh function:
    /run SuaviUI_RefreshSquareIcons()
    
    -- Icons should update immediately
    
    3. Verify state:
    
    /suistyledicons
    -- This shows module state and current settings
    
    EXPECTED RESULTS:
    
    - When setting is TRUE: Icons are square with borders
    - When setting is FALSE: Icons are circular (native Blizzard UI)
    - Changes take effect on next RefreshLayout trigger (reload, combat, etc.)
    - No more "stuck" styling after disabling
    
    TROUBLESHOOTING:
    
    If icons are stuck styled:
    /suistyleforce
    -- This forces a complete refresh
    
    THE FIX:
    
    1. Hooks now check actual settings on every RefreshLayout
    2. No longer dependent on module state flag
    3. RestoreOriginalStyle always runs (no guard check)
    4. Self-healing behavior - settings changes auto-apply
    
]]

-- This file is just documentation - no code to execute
-- Delete this file after testing is complete
