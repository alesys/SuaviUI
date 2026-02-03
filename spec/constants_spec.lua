-- Test: WIDTH_MODE constants
describe("WIDTH_MODE constants", function()
    local ns
    
    setup(function()
        -- Load WoW API mocks
        require("spec.mocks.wow_api")
        
        -- Create namespace
        ns = {}
        _G.ns = ns
        
        -- Load constants
        dofile("utils/constants.lua")
    end)
    
    it("should have ns.Constants defined", function()
        assert.is_not_nil(ns.Constants)
    end)
    
    it("should have WIDTH_MODE table", function()
        assert.is_not_nil(ns.Constants.WIDTH_MODE)
    end)
    
    describe("WIDTH_MODE values", function()
        it("should have MANUAL mode", function()
            assert.equals("Manual", ns.Constants.WIDTH_MODE.MANUAL)
        end)
        
        it("should have SYNC_UNIT_FRAME mode", function()
            assert.equals("Sync With Unit Frame", ns.Constants.WIDTH_MODE.SYNC_UNIT_FRAME)
        end)
        
        it("should have SYNC_ESSENTIAL mode", function()
            assert.equals("Sync With Essential Cooldowns", ns.Constants.WIDTH_MODE.SYNC_ESSENTIAL)
        end)
        
        it("should have SYNC_UTILITY mode", function()
            assert.equals("Sync With Utility Cooldowns", ns.Constants.WIDTH_MODE.SYNC_UTILITY)
        end)
        
        it("should have SYNC_TRACKED_BUFFS mode", function()
            assert.equals("Sync With Tracked Buffs", ns.Constants.WIDTH_MODE.SYNC_TRACKED_BUFFS)
        end)
        
        it("should have exactly 5 modes", function()
            local count = 0
            for _ in pairs(ns.Constants.WIDTH_MODE) do
                count = count + 1
            end
            assert.equals(5, count)
        end)
    end)
end)
