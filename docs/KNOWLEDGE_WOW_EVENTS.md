# WoW Event Reference & Common Pitfalls

Documentation of WoW event handling lessons learned during SuaviUI development.

## Event Registration

### Valid Aura/Buff Tracking Events

| Event | Purpose | Notes |
|-------|---------|-------|
| `UNIT_AURA` | Fires when auras change on any unit | **Correct** for tracking buff duration |
| `AURA_UPDATE` | ❌ INVALID - Does not exist | Common mistake - causes "unknown event" error |
| `UNIT_POWER_FREQUENT` | Fires frequently for power updates (60 FPS) | Ideal for smooth bar updates |
| `UNIT_POWER_UPDATE` | Fires when power changes | Less frequent than FREQUENT |
| `UNIT_MAXPOWER` | Fires when max power changes | Use for initialization |

### Common Mistakes

#### ❌ WRONG - AURA_UPDATE doesn't exist
```lua
self:RegisterEvent("AURA_UPDATE", "OnUnitPower")
-- Error: Attempt to register unknown event "AURA_UPDATE"
```

#### ✅ CORRECT - Use UNIT_AURA instead
```lua
self:RegisterEvent("UNIT_AURA", "OnUnitPower")
-- Fires whenever auras update on any unit
```

## Practical Example: Ebon Might Tracking

For Evoker Ebon Might buff duration tracking:

```lua
-- Register for aura changes
self:RegisterEvent("UNIT_AURA", "OnUnitPower")

-- In update function, get aura data
local function GetTertiaryResourceValue(resource)
    if resource == "EBON_MIGHT" then
        -- Ebon Might spell ID: 395296
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(395296)
        local current = auraData and (auraData.expirationTime - GetTime()) or 0
        local max = 20  -- Ebon Might duration is always 20 seconds
        
        if current < 0 then current = 0 end
        return max, math.max(0, current)
    end
end
```

## Key Takeaways

1. **Always verify event names** against WoW API documentation
2. **UNIT_AURA is for buff/debuff tracking**, not `AURA_UPDATE`
3. **UNIT_POWER_FREQUENT is ideal** for smooth bar animations (60 FPS)
4. **Combine events** for comprehensive tracking (UNIT_AURA + UNIT_POWER_FREQUENT)
5. **Test in-game** to catch unknown event errors early

## Related Resources

- [WoW API Events](https://wowwiki.wiki.gg/wiki/Events)
- [C_UnitAuras API](https://wowpedia.fandom.com/wiki/API_C_UnitAuras)
- SuaviUI Implementation: [suicore_resourcebars.lua](../utils/suicore_resourcebars.lua)
