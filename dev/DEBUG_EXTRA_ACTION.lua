-- Debug script to understand ExtraActionBarFrame behavior

print("=== DEBUGGING EXTRA ACTION BUTTON ===")

-- Check if frame exists
if ExtraActionBarFrame then
    print("ExtraActionBarFrame exists")
    print("  IsShown:", ExtraActionBarFrame:IsShown())
    print("  IsVisible:", ExtraActionBarFrame:IsVisible())
    print("  GetAlpha:", ExtraActionBarFrame:GetAlpha())
    print("  Mouse enabled:", ExtraActionBarFrame:IsMouseEnabled())
    
    -- Check children/components
    if ExtraActionBarFrame.button then
        print("  button child exists")
        print("    button IsShown:", ExtraActionBarFrame.button:IsShown())
        print("    button IsVisible:", ExtraActionBarFrame.button:IsVisible())
    end
    
    if ExtraActionBarFrame.style then
        print("  style child exists")
        print("    style IsShown:", ExtraActionBarFrame.style:IsShown())
        print("    style Alpha:", ExtraActionBarFrame.style:GetAlpha())
    end
    
    -- Check parent
    print("  Parent:", ExtraActionBarFrame:GetParent() and ExtraActionBarFrame:GetParent():GetName() or "nil")
    
    -- Check NumChildren
    print("  NumChildren:", ExtraActionBarFrame:GetNumChildren())
    for i = 1, ExtraActionBarFrame:GetNumChildren() do
        local child = select(i, ExtraActionBarFrame:GetChildren())
        if child then
            print("    Child " .. i .. ": " .. (child:GetName() or "unnamed") .. 
                  " IsShown=" .. tostring(child:IsShown()) .. 
                  " IsVisible=" .. tostring(child:IsVisible()))
        end
    end
else
    print("ExtraActionBarFrame does NOT exist yet")
end

print("\n=== ZONE ABILITY FRAME ===")
if ZoneAbilityFrame then
    print("ZoneAbilityFrame exists")
    print("  IsShown:", ZoneAbilityFrame:IsShown())
    print("  IsVisible:", ZoneAbilityFrame:IsVisible())
    print("  GetAlpha:", ZoneAbilityFrame:GetAlpha())
    print("  Mouse enabled:", ZoneAbilityFrame:IsMouseEnabled())
    
    if ZoneAbilityFrame.SpellButton then
        print("  SpellButton exists")
        print("    spellID:", ZoneAbilityFrame.SpellButton.spellID)
        print("    IsShown:", ZoneAbilityFrame.SpellButton:IsShown())
    else
        print("  SpellButton: nil")
    end
    
    print("  Parent:", ZoneAbilityFrame:GetParent() and ZoneAbilityFrame:GetParent():GetName() or "nil")
    print("  NumChildren:", ZoneAbilityFrame:GetNumChildren())
else
    print("ZoneAbilityFrame does NOT exist yet")
end

print("\n=== API CHECKS ===")
print("HasExtraActionBar():", HasExtraActionBar and HasExtraActionBar() or "function not available")

-- Check what triggers visibility
print("\nScheduling checks at 1s, 2s, 3s...")
C_Timer.After(1, function()
    print("\n--- At 1 second ---")
    if ExtraActionBarFrame then
        print("ExtraActionBarFrame.IsShown:", ExtraActionBarFrame:IsShown())
        print("HasExtraActionBar:", HasExtraActionBar and HasExtraActionBar() or "N/A")
    end
end)

C_Timer.After(2, function()
    print("\n--- At 2 seconds (where it appears) ---")
    if ExtraActionBarFrame then
        print("ExtraActionBarFrame.IsShown:", ExtraActionBarFrame:IsShown())
        print("HasExtraActionBar:", HasExtraActionBar and HasExtraActionBar() or "N/A")
        if ExtraActionBarFrame.button then
            print("button.action:", ExtraActionBarFrame.button.action)
        end
    end
end)

C_Timer.After(3, function()
    print("\n--- At 3 seconds ---")
    if ExtraActionBarFrame then
        print("ExtraActionBarFrame.IsShown:", ExtraActionBarFrame:IsShown())
        print("HasExtraActionBar:", HasExtraActionBar and HasExtraActionBar() or "N/A")
    end
end)
