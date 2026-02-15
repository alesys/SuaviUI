# BugGrabber Error Log Analysis Guide

## ⚠️ CRITICAL UNDERSTANDING: Counter Does NOT Mean Total

**Location:** `e:\Games\World of Warcraft\_retail_\WTF\Account\SYSELA\SavedVariables\!BugGrabber.lua`

### What the Counter Really Means

```lua
["counter"] = 9912  -- This is NOT the total error occurrences
```

**The `counter` field shows HOW MANY TIMES that SPECIFIC error message appeared SINCE IT WAS FIRST SEEN.**

### Key Points

- **Counter increments CONTINUOUSLY** as the game runs
- **Each unique error message gets its own counter**
- **Running the game for hours will cause counters to increase dramatically**
- **Comparing counters across sessions is MEANINGLESS**
- **The counter NEVER resets** unless you manually delete the BugGrabber log

### How to Properly Evaluate Improvements

❌ **WRONG:** "We went from 9,912 errors to 61 errors - 99% improvement!"
- This is comparing counter values from different sessions
- Both sessions may have been running different amounts of time
- Counters accumulate indefinitely

✅ **RIGHT:** "Session 4612 has ONLY THIS ERROR appearing, no other error types"
- Check error TYPE diversity, not counter values
- Look for completely ELIMINATED error types
- Observe which unique errors exist in current session

### What Changed Between v0.2.8 → v0.2.9

**Before (with LibOpenRaid):**
- Multiple error types: "hasTotem", "spellID", "charges"
- Many unique Blizzard files throwing errors

**After (LibOpenRaid removed):**
- Only ONE error type remaining: "hasTotem" 
- Single source: CooldownViewerItemData.lua:419
- All other error categories eliminated

### Proper Analysis Method

1. **Count unique error TYPES** (not counters)
   - Session 4604-4609: 3+ error types
   - Session 4612: 1 error type ✓

2. **Identify error SOURCE files** (not counter values)
   - Session 4604-4609: Multiple Blizzard files throwing errors
   - Session 4612: Only CooldownViewerItemData.lua ✓

3. **Check time since session started**
   - Don't compare raw counter values across sessions
   - A 24-hour session will have much higher counters than a 1-hour session

### Resume Analysis

The 61-error session 4612 is actually **EXCELLENT** because:
- ✅ "spellID" errors GONE
- ✅ "charges" errors GONE  
- ✅ Multiple error sources ELIMINATED
- ✅ Only ONE error type remaining from ONE source
- ⚠️ Single hasTotem error source still exists (investigating further)

---

**Remember:** Counter increments = time passing + game activity. It's NOT a measure of total occurrences.
