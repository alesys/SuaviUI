# SuaviUI Settings Documentation

> **Complete guide to every setting in the `/sui` options panel**

Access the options panel with `/sui`, `/suavi`, or `/suaviui`

---

## Table of Contents

- [General & QoL](#general--qol)
- [Minimap & Datatext](#minimap--datatext)
- [CDM GCD & Effects](#cdm-gcd--effects)
- [CDM Styles](#cdm-styles)
- [Custom Items/Spells/Buffs](#custom-itemsspellsbuffs)
- [Single Frames & Castbars](#single-frames--castbars)
- [Autohide & Skinning](#autohide--skinning)
- [Action Bars](#action-bars)
- [SUI Import/Export](#sui-importexport)
- [Spec Profiles](#spec-profiles)

---

## General & QoL

Settings for overall UI behavior, quality of life features, and performance.

### UI Scale

**Auto UI Scale**
- Automatically adjusts UI scale based on screen resolution for optimal clarity
- Recommended: **Enabled** for 1080p/1440p/4K displays
- When disabled, uses WoW's native UI scale setting

**UI Scale Override**
- Manually set UI scale when Auto UI Scale is disabled
- Range: 0.4 - 1.2
- Default: 1.0 (100%)

### Default Font Settings

**Default Font**
- Sets the primary font used throughout SuaviUI elements
- Dropdown: All available fonts from WoW + LibSharedMedia
- Default: "Friz Quadrata TT" (WoW's default font)

**Default Font Size**
- Base font size for UI text elements
- Range: 8 - 20
- Default: 12

**Default Font Outline**
- Text outline style for better readability
- Options: None, Outline, Thick Outline
- Default: Outline

### Suavi Recommended FPS Settings

**Apply FPS Settings**
- One-click button to apply Suavi's optimized graphics settings
- Sets 58 CVars for maximum FPS (competitive M+/PvP)
- **Warning**: Significantly reduces visual quality for performance
- Recommended for: High refresh rate monitors (144Hz+), competitive content

**Individual CVar Settings** (expandable after applying)
- View/modify each of the 58 individual settings
- Includes: Shadow quality, texture detail, particle density, etc.

### Combat Status Text Indicator

**Enable Combat Text**
- Shows "IN COMBAT" text indicator on screen during combat
- Useful for tracking combat status without looking at character frame

**Position**
- Nine-point anchor system (Top Left, Center, Bottom Right, etc.)
- Default: "TOP" (top center of screen)

**X Offset / Y Offset**
- Fine-tune horizontal/vertical position
- Range: -500 to +500

**Font Size**
- Text size for combat indicator
- Range: 12 - 40
- Default: 24

**Colors**
- In Combat Color: RGB color picker (default: red)
- Out of Combat Color: RGB color picker (default: green)

### Combat Timer

**Enable Combat Timer**
- Displays elapsed combat time during encounters
- Useful for rotation tracking and encounter timing

**Position / Offsets**
- Same nine-point anchor + X/Y offset system

**Font Size**
- Range: 12 - 32
- Default: 16

**Color**
- RGB color picker for timer text

### Automation

**Auto Repair**
- Automatically repairs gear when visiting vendors
- Uses guild bank funds first (if available), then personal gold

**Auto Sell Junk**
- Automatically sells grey-quality items to vendors

**Auto Confirm Deletes**
- Skips "Are you sure?" confirmation when deleting items
- **Warning**: Irreversible deletions - use with caution

**Auto Accept Quests**
- Automatically accepts quests from NPCs (excludes dailies/weeklies by default)

**Auto Turn-in Quests**
- Automatically completes quests when talking to quest givers

### Missing Raid Buffs

**Enable Missing Buffs**
- Shows on-screen indicators for missing raid buffs
- Checks: Battle Shout, Arcane Intellect, Power Word: Fortitude, Mark of the Wild, Devotion Aura

**Position / Size**
- Nine-point anchor + offsets
- Icon size slider: 24 - 64 pixels

**Visibility**
- Show in Raid: Display when in raid groups
- Show in Party: Display when in 5-man groups
- Show Solo: Display when ungrouped (for self-buffs)

### Quick Salvage

**Enable Quick Salvage**
- Adds a keybindable quick salvage button for mass salvaging gear
- Automatically salvages all BoP items in bags (excluding equipped)

**Keybinding**
- Set via WoW's Keybindings menu (ESC > Keybindings > SuaviUI)

### M+ Dungeons

**Show M+ Timer**
- Displays custom Mythic+ timer during keystone runs
- Shows: Time elapsed, +3/+2/+1 cutoffs, enemy forces %

**Timer Position**
- Nine-point anchor + offsets
- Default: "TOP" (just below minimap)

**Show Enemy Forces**
- Displays enemy forces % in M+ timer
- Color-coded: Red (<100%), Green (100%+)

**Dungeon Teleports**
- Quick teleport menu to M+ dungeon entrances (for portals/teleports)
- Command: `/dtp` or click minimap button

### Others

**Show Intro Message**
- Displays welcome message on login/reload
- Default: Enabled

**Perfect Pixel Snap**
- Forces UI elements to align to whole pixels (prevents blurry edges)
- Recommended: **Enabled** for crisp visuals

**Unlock Frames**
- Global unlock for moving SUI frames (castbars, unitframes, etc.)
- Drag frames to reposition when unlocked

---

### HUD Visibility

Controls visibility of major UI systems based on combat state.

#### CDM Visibility

**Essential Bar - Combat Only**
- Hides Cooldown Manager Essential bar outside of combat
- Default: Disabled (always visible)

**Utility Bar - Combat Only**
- Hides Utility bar outside of combat
- Default: Disabled

#### Unitframes Visibility

**Hide Unitframes Out of Combat**
- Hides Player/Target/Focus frames when not in combat
- Useful for minimal UI aesthetics outside combat

**Hide Player**
- Specifically hide Player frame when out of combat

**Hide Target**
- Hide Target frame when out of combat

**Hide Focus**
- Hide Focus frame when out of combat

#### Custom Items/Spells Bars

**Combat Visibility**
- Set custom tracker bars to only show in combat
- Per-bar toggle for each custom tracker

---

### Cursor & Crosshair

Visual enhancements for cursor and screen center.

#### Cursor Ring

**Enable Cursor Ring**
- Adds a colored ring around the cursor for better visibility

**Ring Size**
- Diameter of ring in pixels
- Range: 32 - 128
- Default: 64

**Ring Color**
- RGB color picker with alpha transparency
- Default: White with 50% opacity

**Texture**
- Choose ring texture style
- Options: Solid, Glow, Pulse, etc.

**Thickness**
- Ring line thickness
- Range: 1 - 8 pixels

#### SUI Crosshair

**Enable Crosshair**
- Displays a crosshair at screen center (FPS-style)
- Useful for precision targeting/positioning

**Crosshair Style**
- Options: Cross, Dot, Circle, T-Shape, Plus
- Default: Cross

**Size**
- Crosshair dimensions
- Range: 8 - 48 pixels

**Thickness**
- Line thickness for crosshair
- Range: 1 - 4 pixels

**Color**
- RGB color picker
- Default: White

**Opacity**
- Transparency level
- Range: 0% - 100%
- Default: 50%

**Gap**
- Center gap size (for Cross/Plus styles)
- Range: 0 - 20 pixels

---

### Buff & Debuff

Customization for buff and debuff display.

#### Buff & Debuff Borders

**Enable Buff Borders**
- Adds colored borders around player buffs based on type
- Colors indicate: Magic (blue), Curse (purple), Disease (brown), Poison (green), Physical (red)

**Border Thickness**
- Width of colored border
- Range: 1 - 4 pixels
- Default: 2

**Show Debuff Type**
- Display debuff type text overlay (e.g., "MAGIC", "POISON")

**Glow Effect**
- Adds animated glow to important buffs
- Intensity: None, Low, Medium, High

#### Hide Blizzard Default Buffs and Debuffs

**Hide Blizzard Buffs**
- Completely hides default WoW buff frames
- **Note**: Requires alternative buff addon (WeakAuras, ElvUI, etc.)

**Hide Blizzard Debuffs**
- Hides default debuff frames

---

### Chat

Chat frame enhancements and customization.

#### Enable/Disable SUI Chat Module

**Enable Chat Module**
- Master toggle for all SUI chat enhancements
- Disable if using alternative chat addon

#### Intro Message

**Show Intro Message**
- Display SuaviUI welcome message on login
- Default: Enabled

#### Chat Background

**Enable Chat Background**
- Adds semi-transparent background to chat frames

**Background Opacity**
- Transparency of chat background
- Range: 0% - 100%
- Default: 30%

**Background Color**
- RGB color picker for chat background

#### Input Box Background

**Enable Input Box Background**
- Adds background to chat input box (where you type)

**Opacity**
- Input box background transparency

#### Message Fade

**Enable Message Fade**
- Chat messages fade out after inactivity

**Fade Delay**
- Seconds before messages start fading
- Range: 0 - 300 seconds
- Default: 120 (2 minutes)

**Fade Duration**
- How long fade animation takes
- Range: 0.1 - 10 seconds
- Default: 3

#### URL Detection

**Enable URL Detection**
- Makes URLs in chat clickable
- Detects: http://, https://, www., discord.gg/, etc.

**URL Color**
- Color for detected URLs
- Default: Bright blue

#### Timestamps

**Show Timestamps**
- Adds time stamps to chat messages

**Format**
- Options: 12-hour, 24-hour
- Include seconds: Yes/No

**Color**
- RGB color for timestamps
- Default: Grey

#### UI Cleanup

**Hide Chat Buttons**
- Hides default chat frame buttons (social, menu, etc.)

**Hide Scroll Arrows**
- Removes scroll up/down arrows from chat

**Fade Tabs**
- Chat tab buttons fade when not moused over

#### Copy Button

**Show Copy Button**
- Adds "Copy" button to chat frames for copying chat text

**Button Position**
- Top Right, Top Left, Bottom Right, Bottom Left

---

### Tooltip

Tooltip customization and behavior.

#### Enable/Disable SUI Tooltip Module

**Enable Tooltip Module**
- Master toggle for SUI tooltip enhancements

#### Cursor Anchor

**Anchor to Cursor**
- Tooltips follow mouse cursor instead of fixed position
- Default: Disabled (anchors to UIParent)

**Cursor Offset X/Y**
- Distance from cursor (when cursor anchored)
- Range: -100 to +100

#### Tooltip Visibility

**Hide on Unitframes**
- Don't show tooltips when mousing over unitframes

**Hide in Combat**
- Suppress tooltips during combat (reduces clutter)

**Show Item Level**
- Display item level on equipment tooltips

**Show Item ID**
- Display item ID for debugging/lookup

**Show Spell ID**
- Display spell ID on spell tooltips

#### Combat

**Combat Alpha**
- Tooltip opacity during combat
- Range: 0% - 100%
- Default: 50% (semi-transparent)

---

### Character Pane

Character sheet and inspect frame customization.

#### Enable/Disable SUI Character Module

**Enable Character Module**
- Master toggle for character pane enhancements

#### Character Pane Settings

**Show Item Level**
- Displays average item level on character sheet

**Show Gear Score**
- Legacy gear score calculation (for reference)

**Colorize Item Quality**
- Color item slots by quality (grey/green/blue/epic/legendary)

**Show Empty Slots**
- Highlight empty equipment slots

**Durability Display**
- Show item durability % on character sheet

#### Inspect Frame

**Enable Inspect Enhancements**
- Applies same enhancements to inspect frame (when inspecting other players)

**Show Target Item Level**
- Display inspected player's average ilvl

---

### Dragonriding

Skyriding/Dragonriding vigor bar customization.

#### Enable

**Enable Dragonriding Module**
- Master toggle for custom dragonriding UI

#### Visibility

**Show Outside Dragonriding**
- Keep vigor bar visible even when not on flying mount
- Default: Disabled (only shows when mounted)

**Hide in Combat**
- Auto-hide vigor bar during combat

#### Bar Size

**Width**
- Bar width in pixels
- Range: 100 - 500
- Default: 300

**Height**
- Bar height in pixels
- Range: 10 - 60
- Default: 20

#### Position

**Anchor Point**
- Nine-point anchor system

**X Offset / Y Offset**
- Fine-tune position

#### Fill Colors

**Vigor Color**
- RGB color for filled vigor segments
- Default: Cyan

**Empty Color**
- Color for depleted segments
- Default: Dark grey

#### Background & Effects

**Background Opacity**
- Transparency of bar background
- Range: 0% - 100%

**Show Glow**
- Animated glow effect when vigor is regenerating

**Glow Intensity**
- Strength of glow effect
- Options: Low, Medium, High

#### Text Display

**Show Vigor Count**
- Display current/max vigor as text (e.g., "4/6")

**Font Size**
- Text size for vigor count
- Range: 8 - 24

---

## Minimap & Datatext

Minimap customization and datatext panels.

### Minimap

#### General

**Enable Minimap Module**
- Master toggle for all minimap enhancements

**Shape**
- Options: Square, Circle (requires Square Minimap addon)
- Default: Circle

**Size**
- Minimap dimensions
- Range: 100 - 300 pixels
- Default: 180

**Position**
- Nine-point anchor + offsets
- Default: "TOPRIGHT"

#### Frame Styling

**Border Style**
- Options: None, Thin, Thick, Custom
- Custom: Uses LibSharedMedia border textures

**Border Color**
- RGB color picker for minimap border

**Background**
- Enable background texture behind minimap

**Background Opacity**
- Transparency of minimap background

#### Hide Minimap Elements

**Hide Zoom Buttons**
- Remove +/- zoom buttons from minimap

**Hide Calendar**
- Hide calendar button

**Hide Clock**
- Hide time display on minimap

**Hide Zone Text**
- Hide zone name label

**Hide Tracking Icon**
- Hide tracking menu button

**Hide Mail Icon**
- Hide "you have mail" icon

**Hide Day/Night Indicator**
- Hide sun/moon position indicator

#### Zone Label

**Show Custom Zone Label**
- SUI-styled zone name display

**Font / Size / Outline**
- Zone text customization

**Position**
- Above, Below, or Overlay on minimap

#### Buttons

##### General

**Enable Minimap Buttons**
- Master toggle for addon buttons around minimap

**Button Size**
- Size of addon buttons
- Range: 16 - 36 pixels

**Buttons Per Row**
- How many buttons before wrapping to next row
- Range: 1 - 12

##### Tracking Options

**Show Tracking Button**
- Quick access to tracking menu (herbs, ore, etc.)

**Tracking Position**
- Position relative to minimap

##### Gathering

**Show Herb Tracking**
- One-click herb tracking toggle

**Show Ore Tracking**
- One-click ore tracking toggle

**Show Treasure Tracking**
- Treasure chest tracking

#### Dungeon Eye

**Enable Dungeon Eye**
- Quick dungeon difficulty indicator on minimap

**Show Difficulty**
- Display M+ keystone level or raid difficulty

**Show Timer**
- Show M+ countdown timer on minimap

---

### Datatext

Custom datatext panels for information display.

#### Minimap Datatext Settings

**Enable Minimap Datatext**
- Master toggle for minimap datatext bar

**Position**
- Above or Below minimap

**Width**
- Panel width
- Range: 100 - 400 pixels

**Height**
- Panel height
- Range: 15 - 40 pixels

**Number of Slots**
- How many datatext slots
- Range: 1 - 6

**Slot Assignment**
- Dropdown per slot: FPS, MS, Durability, Gold, Spec, Bags, Repair, etc.

#### Spec Display Options

**Show Spec Icon**
- Display current specialization icon in datatext

**Show Spec Name**
- Text display of spec name (e.g., "Frost")

**Show Role Icon**
- Tank/Healer/DPS role icon

#### Time Options

**Show Realm Time**
- Display server time

**Show Local Time**
- Display computer's local time

**12-Hour Format**
- Use 12-hour clock vs 24-hour

#### Text Styling

**Font**
- LibSharedMedia font dropdown

**Font Size**
- Range: 8 - 18

**Font Outline**
- None, Outline, Thick

**Text Color**
- RGB color picker

#### Custom Movable Panels

**Create New Panel**
- Button to add custom datatext panel

**Panel Settings** (per panel)
- Width / Height
- Position (nine-point + offsets)
- Number of slots
- Background opacity
- Border size/color
- Slot assignments (dropdown per slot)

**Delete Panel**
- Remove custom panel

---

## CDM GCD & Effects

Cooldown Manager visual effects and GCD tracking.

### Essential

**Show GCD Pulse**
- Animated pulse on Essential bar during GCD
- Helps with GCD-locked abilities

**Pulse Color**
- RGB color for GCD pulse
- Default: White

**Pulse Intensity**
- Strength of pulse effect
- Options: Low, Medium, High
- Default: Medium

**Pulse Speed**
- Animation speed
- Range: Slow, Normal, Fast

### Utility

**Show GCD Pulse**
- Same as Essential but for Utility bar

**Pulse Color / Intensity / Speed**
- Same options as Essential

### Custom Tracker

**Show GCD on Custom Trackers**
- Enable GCD pulse on custom tracker bars

**Per-Tracker Settings**
- Individual pulse color/intensity per custom bar

---

## CDM Styles

Visual styling for Cooldown Manager bars.

### Essential Keybind Display

**Show Keybinds on Essential**
- Display hotkey text on cooldown icons

**Keybind Position**
- Options: Top Left, Top Right, Bottom Left, Bottom Right, Center

**Font Size**
- Keybind text size
- Range: 8 - 18

**Font Outline**
- Text outline style

**Text Color**
- RGB color picker for keybind text

### Utility Keybind Display

**Show Keybinds on Utility**
- Same options as Essential

**Keybind Position / Font / Color**
- Same customization options

### Rotation Helper Overlay

**Enable Rotation Helper**
- Highlights next recommended ability in rotation
- **Note**: Requires compatible rotation addon (HeroRotation, etc.)

**Overlay Style**
- Options: Border Glow, Icon Glow, Flash, Pulse

**Color**
- RGB color for rotation helper highlight
- Default: Green

**Intensity**
- Glow/flash intensity
- Options: Subtle, Normal, Bright

### Rotation Assist Icon

**Show Rotation Icon**
- Larger icon display for current rotation priority ability

**Icon Size**
- Range: 32 - 128 pixels
- Default: 64

**Position**
- Nine-point anchor + offsets

**Border**
- Enable border around rotation icon

**Border Color**
- RGB color picker

---

## Custom Items/Spells/Buffs

Tracker bars for specific spells, items, or buffs.

### Spell Scanner

**Enable Spell Scanner**
- Utility to help find spell IDs for custom tracking

**How to Use**
1. Enable scanner
2. Cast spell or use item
3. Spell ID displays in chat
4. Copy ID for custom tracker

### Custom Tracker Bars

**Create New Tracker**
- Button to add new custom tracker bar

**General Settings** (per tracker)
- Bar Name: Display name for tracker
- Track Type: Spell, Item, Buff, Debuff, Cooldown

**Tracking Configuration**
- Spell/Item ID: Numeric ID to track
- Unit: Player, Target, Focus, Pet
- Show When: Always, In Combat, Out of Combat, Has Target

**Position**
- Nine-point anchor
- X/Y Offsets

**Bar Appearance**
- Width: 100 - 500 pixels
- Height: 10 - 60 pixels
- Texture: LibSharedMedia statusbar textures
- Fill Direction: Left to Right, Right to Left, Bottom to Top, Top to Bottom

**Colors**
- Ready Color: When spell/item is available
- Cooldown Color: When on cooldown
- Missing Color: When conditions not met
- Background Color: Bar background

**Text Display**
- Show Timer: Display time remaining
- Show Stacks: Display buff/item stacks
- Show Spell Name: Show tracked spell name
- Font / Size / Outline
- Text Position: Left, Center, Right

**Visibility**
- Show in PvE: Enable in dungeons/raids
- Show in PvP: Enable in arenas/battlegrounds
- Show While Solo: Enable when ungrouped
- Combat Only: Hide when not in combat

**Delete Tracker**
- Remove custom tracker bar

---

## Single Frames & Castbars

Unitframe and castbar customization for Player, Target, Focus, Pet, ToT, Boss, and Arena.

### General

#### Enable/Disable

**Enable Unitframes Module**
- Master toggle for all SUI unitframe enhancements

#### Global Size Multiplier

**Global Scale**
- Multiplier for ALL unitframes
- Range: 0.5 - 2.0 (50% - 200%)
- Default: 1.0
- Useful for: Quick size adjustments without changing individual settings

#### Default Texture Settings

**Default Health Texture**
- LibSharedMedia statusbar texture for health bars
- Default: "Blizzard"

**Default Power Texture**
- Texture for power bars (mana/rage/energy)

**Smooth Progress**
- Animated bar filling (smooth vs instant)
- Default: Enabled

---

### Player

#### Player Frame Settings

**Enable Player Frame**
- Show/hide player unitframe

**Show in Edit Mode**
- Include in Blizzard's Edit Mode for positioning

**Lock Frame**
- Prevent accidental movement

#### Player Frame Positioning

**Position**
- Nine-point anchor + X/Y offsets
- Default: "BOTTOM" -280, 180

**Scale**
- Individual scale for player frame
- Range: 0.5 - 2.0

#### Health Bar

**Width**
- Health bar width in pixels
- Range: 100 - 500
- Default: 230

**Height**
- Health bar height
- Range: 10 - 80
- Default: 28

**Texture**
- LibSharedMedia statusbar texture

**Color Mode**
- Options: Class Color, Custom, Health Gradient
- Class Color: Automatic based on class
- Custom: RGB color picker
- Health Gradient: Red (low) → Yellow (mid) → Green (full)

**Custom Color**
- RGB picker (when Color Mode = Custom)

**Show Health Text**
- Display current/max HP or percentage

**Text Format**
- Options: Current/Max, Percentage, Current Only, Max Only, Both

**Font / Size / Outline**
- Text customization

**Text Position**
- Left, Center, Right

#### Power Bar

**Show Power Bar**
- Display mana/rage/energy bar

**Width / Height**
- Same range as health bar

**Texture**
- Statusbar texture

**Color Mode**
- Options: Power Type (auto), Class Color, Custom
- Power Type: Blue (mana), Red (rage), Yellow (energy), etc.

**Show Power Text**
- Display current/max power or percentage

**Text Format / Font / Position**
- Same options as health bar text

#### Player Castbar

**Enable Player Castbar**
- Show custom castbar (replaces default)

**Position**
- Attached: Below Player Frame
- Detached: Custom position (nine-point anchor)

**Width / Height**
- Castbar dimensions

**Show Cast Time**
- Display cast time remaining (e.g., "2.3s")

**Show Spell Name**
- Display casting spell name

**Show Icon**
- Spell icon on castbar

**Icon Position**
- Left or Right of bar

**Interrupt Flash**
- Flash effect when cast is interrupted

**Non-Interruptible Color**
- Color for casts that can't be interrupted (e.g., boss casts)
- Default: Red

---

### Target

#### Target Frame Settings

**Enable Target Frame**
- Show/hide target unitframe

**Show Target of Target**
- Small portrait of target's target

**Show Threat %**
- Display threat percentage on target

#### Target Frame Positioning

**Position**
- Nine-point anchor + X/Y offsets
- Default: "BOTTOM" 280, 180

**Scale**
- Individual scale for target frame

#### Health Bar

**Width / Height / Texture / Color**
- Same options as Player health bar

**Show Elite/Rare Border**
- Special border for elite/rare mobs
- Border Colors: Elite (gold), Rare (silver), Rare Elite (blue)

**Class Color Enemies**
- Show class colors for enemy players (PvP)

**NPC Color Mode**
- Hostile: Red
- Neutral: Yellow
- Friendly: Green
- Custom: RGB picker

**Show Health Text**
- Same text options as Player

#### Power Bar

**Show Target Power**
- Display target's mana/rage/energy

**Width / Height / Texture / Color / Text**
- Same options as Player power bar

#### Target Castbar

**Enable Target Castbar**
- Show what target is casting

**Position**
- Attached to Target Frame or Detached custom position

**Width / Height**
- Castbar dimensions

**Show Shield Icon**
- Icon indicating non-interruptible cast

**Interrupt Warning**
- Flash/pulse when cast can be interrupted

**Color Coding**
- Interruptible: Green
- Non-Interruptible: Red
- Channeling: Purple

---

### Focus

#### Focus Frame Settings

**Enable Focus Frame**
- Show/hide focus unitframe

**Auto Set Focus**
- Automatically set focus on arena targets (PvP)

#### Focus Frame Positioning

**Position**
- Nine-point anchor + X/Y offsets
- Default: "BOTTOMRIGHT" -350, 250

**Scale**
- Individual scale

#### Health Bar

**Width / Height / Texture / Color**
- Same options as Player/Target

**Show Health Text**
- Same text options

#### Power Bar

**Show Focus Power**
- Display focus target's power

**Width / Height / Texture / Color / Text**
- Same options as other power bars

#### Focus Castbar

**Enable Focus Castbar**
- Show focus target's casts

**Position / Size / Colors / Text**
- Same options as Target castbar

---

### Pet

#### Pet Frame Settings

**Enable Pet Frame**
- Show/hide pet unitframe

**Show Pet Happiness**
- Legacy hunter pet happiness (Classic only)

#### Pet Frame Positioning

**Position / Scale**
- Same positioning system

#### Health Bar

**Width / Height**
- Range: 50 - 300 pixels (smaller than player/target)

**Texture / Color**
- Same customization options

**Show Pet Name**
- Display pet name on frame

#### Power Bar

**Show Pet Power**
- Display pet's focus/energy

**Width / Height / Texture / Color**
- Same options

---

### Target of Target

#### ToT Frame Settings

**Enable ToT Frame**
- Show target's target (useful for tank swap monitoring)

#### ToT Frame Positioning

**Position / Scale**
- Same positioning system

#### Health Bar

**Width / Height**
- Range: 50 - 200 pixels (compact frame)

**Show ToT Name**
- Display name of target's target

**Color by Reaction**
- Green (friendly), Red (hostile), Yellow (neutral)

#### Power Bar

**Show ToT Power**
- Display power bar

**Width / Height / Color**
- Same compact options

---

### Boss Frames

#### Boss Frame General Settings

**Enable Boss Frames**
- Show custom boss frames (replaces default)

**Number of Boss Frames**
- How many boss frames to show
- Range: 1 - 5 (most encounters have 1-4 bosses)

**Stack Direction**
- Vertical: Stacked top-to-bottom
- Horizontal: Side-by-side

**Spacing**
- Gap between boss frames
- Range: 0 - 50 pixels

#### Boss Frame Positioning

**Position / Scale**
- Anchor point for first boss frame (others stack from there)

#### Health Bar

**Width / Height / Texture**
- Boss frame dimensions

**Show Boss Name**
- Display boss name

**Show Health %**
- Display boss health percentage

**Alternate Power Bar**
- Show alternate power (e.g., Ragnaros power in Firelands)

#### Power Bar

**Show Boss Power**
- Display mana/energy for bosses that use it

**Width / Height / Color**
- Power bar customization

#### Boss Castbar

**Enable Boss Castbars**
- Show boss casts (crucial for interrupts/mechanics)

**Position**
- Attached: Below each boss frame
- Detached: Custom position

**Highlight Interruptible**
- Special color for casts you can interrupt

**Show Cast Shield**
- Icon for non-interruptible casts

---

### Arena Frames

#### Arena Frame General Settings

**Enable Arena Frames**
- Show custom arena frames (PvP)

**Tricket Display**
- Show enemy PvP trinket cooldowns

**DR Tracker**
- Diminishing Returns tracking for CC

#### Arena Frame Positioning

**Position / Scale / Spacing**
- Same options as Boss Frames

#### Health Bar

**Width / Height / Texture / Color**
- Arena frame customization

**Show Class Colors**
- Color health bars by enemy class

**Show Spec Icon**
- Display enemy specialization

#### Power Bar

**Show Arena Power**
- Display enemy mana/rage/energy

**Width / Height / Color**
- Power bar options

---

## Autohide & Skinning

Hide UI elements and apply custom skinning.

### Autohide

#### Objective Tracker

**Hide Objective Tracker**
- Completely hide quest tracker

**Autohide on Combat**
- Hide tracker during combat, show after

**Autohide on Boss**
- Hide during boss encounters

**Fade When Not Focused**
- Reduce opacity when not mousing over

**Fade Opacity**
- Opacity when faded
- Range: 0% - 100%

#### Frames & Buttons

**Hide Minimap Zoom**
- Hide +/- zoom buttons on minimap

**Hide Bag Bar**
- Hide default bag buttons

**Hide Micro Menu**
- Hide character/spellbook/talents buttons

**Hide Gryphons**
- Hide decorative gryphons on action bars

#### Nameplates

**Hide Friendly Nameplates**
- Hide nameplates for friendly NPCs/players

**Hide Enemy Nameplates**
- Hide hostile nameplates

**Nameplate Distance**
- How far away nameplates appear
- Range: 10 - 60 yards

#### Status Bars

**Hide XP Bar**
- Hide experience bar

**Hide Rep Bar**
- Hide reputation bar

**Hide Honor Bar**
- Hide honor level bar (PvP)

#### Combat & Messages

**Hide Error Messages**
- Suppress red error text ("Target not in line of sight", etc.)

**Combat Text Mode**
- Floating Combat Text settings
- Options: Default, Compact, Disabled

---

### Skinning

Apply custom textures/colors to Blizzard frames.

#### Choose Default Color

**Default Skin Color**
- Master accent color for all skinned frames
- RGB color picker
- Default: Purple (#A855F7)

#### Game Menu

**Skin Game Menu**
- Apply custom styling to ESC menu
- Adds backdrop, custom buttons, SuaviUI button

**Add SuaviUI Button**
- Quick access button in ESC menu to open /sui

**Font Size**
- Text size for game menu buttons
- Range: 10 - 16

**Color Scheme**
- Light, Dark, or Custom
- Custom: RGB color picker

#### Ready Check Frame

**Skin Ready Check**
- Custom styling for ready check popup

**Custom Colors**
- Ready (Green), Not Ready (Red), Waiting (Yellow)

#### Keystone Frame

**Skin Keystone Frame**
- Custom M+ keystone selection interface

**Show Keystone Level**
- Display keystone level prominently

#### Encounter Power Bar

**Skin Encounter Power**
- Custom styling for special encounter bars (e.g., Corruption in N'Zoth)

**Custom Color**
- RGB color for power bar

#### Alert Frames

**Skin Alert Frames**
- Achievement popups, loot alerts, etc.

**Animation Style**
- Slide, Fade, or Bounce

#### Loot Window

**Skin Loot Window**
- Custom loot frame styling

**Show Item Level**
- Display ilvl on loot items

**Rarity Borders**
- Color borders by item quality

#### Roll Frames

**Skin Roll Frames**
- Custom styling for Need/Greed/Pass rolls

**Show Item Comparison**
- Tooltip comparison with equipped items

#### Loot History

**Skin Loot History**
- Custom loot history frame

**Max Items Shown**
- Number of loot items to display
- Range: 5 - 20

#### SUI M+ Timer

**Skin M+ Timer**
- Custom Mythic+ timer styling

**Font / Size / Color**
- Timer text customization

**Show Death Counter**
- Display party deaths

#### Reputation/Currency

**Skin Rep/Currency**
- Custom reputation and currency frames

**Highlight Paragon**
- Special color for paragon-ready reputations

#### Inspect Frame

**Skin Inspect Frame**
- Custom styling when inspecting players

**Show Item Level**
- Display average ilvl

**Show Missing Enchants**
- Highlight unenchanted gear

#### Override Action Bar

**Skin Override Bar**
- Vehicle/special action bar styling

#### Objective Tracker

**Skin Objective Tracker**
- Custom quest tracker styling

**Font / Size / Color**
- Tracker text customization

**Backdrop**
- Add background to tracker

**Backdrop Opacity**
- Transparency of tracker background

#### Instance Frames

**Skin Scenario/Dungeon UI**
- Custom styling for scenario objectives, dungeon info

---

## Action Bars

Comprehensive action bar customization.

### Master Settings

#### General Settings

**Enable Action Bars**
- Master toggle for SUI action bar module

**Mouseover Fade**
- Bars fade to low opacity, show on mouseover
- Default: Enabled

**Fade Opacity**
- Opacity when faded out
- Range: 0% - 100%
- Default: 10%

**Fade Speed**
- Animation speed for fade in/out
- Options: Instant, Fast, Normal, Slow

**Inherit Global Font**
- Use default SUI font settings for all bar text

#### Bar Size & Spacing

**Global Button Size**
- Size of all action buttons
- Range: 24 - 80 pixels
- Default: 36

**Global Button Spacing**
- Gap between buttons
- Range: 0 - 16 pixels
- Default: 4

**Row Spacing**
- Gap between rows of buttons
- Range: 0 - 32 pixels

#### Grid Display

**Show Empty Slots**
- Display grid for unassigned buttons
- Useful for: Keybind setup, knowing available slots

**Grid Opacity**
- Transparency of empty button slots
- Range: 0% - 100%

#### Button Text

**Show Macro Names**
- Display macro names on buttons

**Name Font Size**
- Range: 6 - 14
- Default: 10

**Name Position**
- Top, Bottom, Center

#### Hotkey Text

**Show Hotkeys**
- Display keybindings on buttons

**Hotkey Font Size**
- Range: 6 - 14
- Default: 12

**Hotkey Position**
- Top Left, Top Right, Bottom Left, Bottom Right

**Hotkey Color**
- RGB color picker
- Default: White

---

### Mouseover Hide

#### Mouseover Hide Settings

**Enable Mouseover**
- Master toggle for mouseover fade feature

**Individual Bar Toggles**
- Per-bar enable/disable:
  - Action Bar 1 (Main bar)
  - Action Bar 2-6
  - Pet Bar
  - Stance Bar

**Fade Delay**
- Delay before fading after mouse leaves
- Range: 0 - 5 seconds
- Default: 0.5

**Combat Behavior**
- Always Show in Combat: Bars fully visible during combat
- Follow Mouseover in Combat: Fade works during combat

---

### Per-Bar Overrides

Individual settings for each action bar.

#### Action Bar 1

**Enable Bar 1**
- Show/hide main action bar

**Position**
- Nine-point anchor + X/Y offsets
- Default: "BOTTOM" 0, 30

**Button Count**
- Number of buttons to show
- Range: 1 - 12

**Buttons Per Row**
- Layout: 12x1, 6x2, 4x3, 3x4, etc.
- Range: 1 - 12

**Button Size Override**
- Override global size for this bar only
- Leave blank to use global

**Spacing Override**
- Override global spacing

**Hide in Pet Battle**
- Auto-hide during pet battles

**Hide on Vehicle**
- Auto-hide when in vehicle

**Custom Visibility Macro**
- Advanced: Custom show/hide conditions
- Example: `[combat] show; hide`

#### Action Bar 2-6

**Same Options as Bar 1**
- Enable/disable
- Position
- Button count
- Buttons per row
- Size/spacing overrides
- Visibility conditions

#### Pet Bar

**Enable Pet Bar**
- Show/hide pet action bar

**Position / Size / Layout**
- Same positioning options

**Show Pet Name**
- Display active pet name

#### Stance Bar

**Enable Stance Bar**
- Druid forms, Warrior stances, Rogue stealth, etc.

**Position / Size / Layout**
- Same positioning options

**Horizontal Layout**
- Side-by-side vs vertical stack

---

### Extra Buttons

Special action buttons that appear contextually.

#### Extra Action Button

**Enable Extra Action**
- Quest items, encounter mechanics (e.g., Sha crystal)

**Position**
- Nine-point anchor + offsets
- Default: "CENTER" 0, 150

**Size**
- Range: 32 - 80 pixels
- Default: 52

**Show Keybind**
- Display hotkey on button

#### Zone Ability Button

**Enable Zone Ability**
- Zone-specific abilities (e.g., Garrison abilities)

**Position / Size**
- Same options as Extra Action

#### Quest Item Button

**Enable Quest Item**
- Auto-populated quest item button

**Position / Size**
- Same options

**Filter Quests**
- Only show combat-relevant quest items

---

## SUI Import/Export

Profile sharing via encoded strings.

### Import/Export

#### Export/Import String Management

**Export Current Profile**
- Button generates encoded string of all SUI settings
- Copy string to clipboard or text file

**Import Profile**
- Paste encoded string
- Button applies settings from string
- **Warning**: Overwrites current settings

**Export Selected Modules**
- Checkboxes for module selection:
  - Action Bars
  - Unit Frames
  - Minimap
  - Chat
  - Tooltips
  - CDM Settings
  - Custom Trackers
  - All Settings
- Generates partial export string

**Import Behavior**
- Merge: Add to current profile
- Overwrite: Replace current profile
- Default: Merge

**Export Format**
- Compressed String (default): Shorter, harder to read
- Readable JSON: Longer, human-readable

---

### Suavi's Strings

#### Preset Configurations

Pre-made configuration strings for common setups.

**Suavi's M+ Setup**
- Optimized for Mythic+ dungeons
- CDM Essential/Utility positioned for visibility
- Minimal UI, combat-focused

**Suavi's Raid Setup**
- Raid-optimized layout
- Larger unitframes, DBM/BigWigs integration
- More visible boss frames

**Suavi's PvP Setup**
- Arena/BG optimized
- Enemy castbars prominent
- Arena frames with DR tracking

**Suavi's Leveling Setup**
- Clean UI for questing/leveling
- Quest tracker visible
- Minimal clutter

**Suavi's Minimal Setup**
- Absolute bare minimum UI
- Hidden nameplates, minimap, chat
- For screenshots/RP

**Load Preset**
- Button applies selected preset
- Confirmation dialog before overwriting

---

## Spec Profiles

Automatic profile switching per specialization.

### Spec-specific Settings

**Enable Spec Profiles**
- Automatically switch SUI profiles when changing specs
- Useful for: Different UI layouts per spec (e.g., DPS vs Tank)

**Link Spec to Profile**
- Dropdown per spec
- Options: (All available profiles)
- Example:
  - Brewmaster → "Tank Profile"
  - Windwalker → "DPS Profile"
  - Mistweaver → "Healer Profile"

**Create New Profile for Spec**
- Button creates copy of current profile
- Automatically links to current spec

**Unlink Spec**
- Removes spec-specific profile link
- Spec uses default profile

**Auto-Create Profiles**
- Checkbox: Automatically create profile when changing to new spec
- Default: Disabled

---

## Search

Quick settings search functionality.

**Search Bar**
- Type setting name, category, or keyword
- Real-time filter of all settings

**Search Results**
- Displays matching settings from ALL tabs
- Shows: Setting name, category, tab location
- Click result to jump to setting

**Clear Search**
- Button to clear search and return to normal view

**Search Tips**
- Keyword examples: "font", "color", "combat", "hide", "show"
- Searches: Setting names, tooltips, section headers

---

## Credits

Addon information and acknowledgments.

**Version Info**
- Current addon version
- Last updated date

**Credits List**
- Development team
- Contributors
- Testers
- Special thanks

**Changelog Button**
- Opens changelog viewer
- Shows version history

**Discord Link**
- Community Discord server

**GitHub Link**
- Source code repository

**Support Link**
- Donation/support page

---

## Keyboard Shortcuts

Quick access keybinds (set in WoW Keybindings menu under "SuaviUI").

- **Toggle Options Panel**: Open/close `/sui`
- **Quick Keybind Mode**: Open keybind editor (`/kb`)
- **Toggle CDM Settings**: Open Cooldown Manager settings (`/cdm`)
- **Dungeon Teleports**: Open M+ teleport menu (`/dtp`)
- **Reload UI**: Quick reload (`/rl`)

---

## Slash Commands

- `/sui` - Open options panel
- `/suavi` - Alias for `/sui`
- `/suaviui` - Alias for `/sui`
- `/sui editmode` - Toggle unitframe edit mode
- `/sui debug` - Enable debug mode and reload
- `/kb` - Quick keybind mode
- `/cdm` - Toggle CDM settings
- `/cds` - Alias for `/cdm`
- `/dtp` - Dungeon teleports
- `/rl` - Reload UI

---

## Frequently Asked Questions

### General

**Q: Settings not saving?**
A: Make sure to `/reload` after major changes. Some settings require reload.

**Q: How do I reset to defaults?**
A: Options Panel → Import/Export → Reset to Defaults button

**Q: Can I use SuaviUI with ElvUI/other UIs?**
A: Partial compatibility. Disable overlapping modules (e.g., SUI action bars if using ElvUI bars).

### Performance

**Q: How do I optimize for FPS?**
A: General & QoL → Apply Suavi FPS Settings (58 CVars)

**Q: Does SuaviUI impact performance?**
A: Minimal. Most features are UI-only (no combat calculations). CDM uses ~1-2 FPS.

### Cooldown Manager

**Q: CDM not showing cooldowns?**
A: 1) Enable in Options → Gameplay Enhancement
   2) Position bars in Edit Mode (ESC → Edit Mode)
   3) Use 100% icon size for best results

**Q: How do I sync CDM width with resource bars?**
A: Edit Mode → Select CDM Essential → Match Width to Resource Bars (checkbox)

### Profiles

**Q: How do I share my profile?**
A: Import/Export → Export Current Profile → Copy string → Share with friends

**Q: Profile import failed?**
A: Ensure full string copied (check for truncation). Try "Overwrite" mode instead of "Merge".

---

**Last Updated**: February 1, 2026  
**Documentation Version**: 1.0  
**Addon Version**: 0.1.4+

For support, visit: [Discord Server Link]
