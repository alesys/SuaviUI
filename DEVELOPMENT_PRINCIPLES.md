# Development Principles for SuaviUI

## Core Philosophy: DO NOT REINVENT THE WHEEL

**When working on this addon, follow proven patterns from existing, working addons.**

### Primary Reference: SenseiClassResourceBar

SenseiClassResourceBar is the reference implementation for:
- Resource bar architecture
- LibEQOL (Edit Mode) integration
- Position and layout management
- Database structure and persistence

### Golden Rule

**WHEN IN DOUBT, COPY SENSEI EXACTLY.**

Do not:
- ❌ Add delays or timers unless Sensei uses them
- ❌ Create "improved" versions of working code
- ❌ Add extra layers of abstraction
- ❌ Invent new patterns or architectures
- ❌ Assume something needs to be "fixed" without evidence

Do:
- ✅ Look at Sensei's implementation first
- ✅ Copy the exact pattern Sensei uses
- ✅ Keep the same initialization timing
- ✅ Use the same callback structure
- ✅ Match the same code flow

### Why This Matters

**Working code > clever code**

Sensei is a mature, tested addon that handles:
- LibEQOL integration correctly
- Position persistence across reloads
- Edit Mode enter/exit cycles
- Layout switching and management
- Profile awareness

If Sensei does it a certain way, there's a reason. Don't second-guess it.

### Lessons Learned

1. **Resource Bar Positioning Bug (Jan 2026)**
   - Problem: Bars appeared at default positions on reload
   - Failed approaches: Added delays, tried to skip positioning, invented new timing logic
   - Solution: Removed the 1-second delay we added - Sensei initializes immediately on ADDON_LOADED
   - Time wasted: 5+ hours
   - Lesson: **Check Sensei first, copy exactly, test**

2. **LibEQOL Purpose**
   - LibEQOL handles positioning INSIDE Edit Mode
   - Outside Edit Mode, bars position themselves from SavedVariables
   - Don't try to make LibEQOL do things it wasn't designed for

### Development Workflow

1. **Identify what needs to be implemented**
2. **Find the equivalent in SenseiClassResourceBar**
3. **Copy Sensei's approach exactly**
4. **Adapt variable/function names to match SuaviUI conventions**
5. **Test**
6. **Only if it doesn't work, investigate differences**

### When to Deviate from Sensei

Only deviate when:
- Sensei has a bug (verify it's actually a bug first)
- SuaviUI has fundamentally different requirements
- You have tested proof that Sensei's approach doesn't work for your case

Even then:
- Document WHY you're deviating
- Keep changes minimal
- Test thoroughly

### Reference Addons (in priority order)

1. **SenseiClassResourceBar** - Primary reference for resource bars and LibEQOL
2. **LibEQOL documentation/examples** - For understanding the library itself
3. **Blizzard UI code** - Only for native Blizzard systems

### Reminder

**The goal is a working addon, not an innovative one.**

Proven patterns > novel solutions
