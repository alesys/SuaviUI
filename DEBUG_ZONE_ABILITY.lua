-- Debug script for Zone Ability Frame structure

print("=== ZONE ABILITY FRAME DEBUG ===")

if ZoneAbilityFrame then
    print("ZoneAbilityFrame exists")
    print("  IsShown:", ZoneAbilityFrame:IsShown())
    print("  IsVisible:", ZoneAbilityFrame:IsVisible())
    
    -- Check SpellButton
    if ZoneAbilityFrame.SpellButton then
        print("  SpellButton exists")
        print("    spellID:", ZoneAbilityFrame.SpellButton.spellID)
        print("    IsShown:", ZoneAbilityFrame.SpellButton:IsShown())
        print("    IsVisible:", ZoneAbilityFrame.SpellButton:IsVisible())
    else
        print("  SpellButton: nil")
    end
    
    -- Check SpellButtonContainer
    if ZoneAbilityFrame.SpellButtonContainer then
        print("  SpellButtonContainer exists")
        local count = 0
        for button in ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
            count = count + 1
            print("    Active button #" .. count .. ": " .. button:GetName() or "unnamed")
            if button.spellID then
                print("      spellID: " .. button.spellID)
            end
        end
        print("    Total active buttons: " .. count)
    else
        print("  SpellButtonContainer: nil")
    end
    
    -- Check all children
    print("  NumChildren:", ZoneAbilityFrame:GetNumChildren())
    for i = 1, ZoneAbilityFrame:GetNumChildren() do
        local child = select(i, ZoneAbilityFrame:GetChildren())
        if child then
            print("    Child " .. i .. ": " .. (child:GetName() or "unnamed"))
        end
    end
end

-- Schedule checks every second for 5 seconds to see changes
for t = 1, 5 do
    C_Timer.After(t, function()
        print("\n--- At " .. t .. " second(s) ---")
        if ZoneAbilityFrame then
            print("IsShown:", ZoneAbilityFrame:IsShown())
            if ZoneAbilityFrame.SpellButton then
                print("SpellButton.spellID:", ZoneAbilityFrame.SpellButton.spellID)
                print("SpellButton IsShown:", ZoneAbilityFrame.SpellButton:IsShown())
            end
            if ZoneAbilityFrame.SpellButtonContainer then
                local count = 0
                for button in ZoneAbilityFrame.SpellButtonContainer:EnumerateActive() do
                    count = count + 1
                end
                print("Active buttons in container:", count)
            end
        end
    end)
end
