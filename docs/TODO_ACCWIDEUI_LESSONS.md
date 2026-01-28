# SuaviUI Enhancement TODO - Lessons from AccWideUI

## Phase 1: Core Infrastructure (High Priority)

### 1. Per-Specialization EditMode Layouts ⭐⭐⭐
**Goal**: Save EditMode layout IDs per specialization instead of full layout strings
**Benefits**: More efficient storage, spec-specific layouts, automatic switching
**Implementation**:
- Hook EditMode events to detect layout changes
- Save layout IDs per spec (like AccWideUI)
- Auto-switch layouts when changing specs
- Add UI options to enable/disable per-spec layouts

### 2. Automatic Layout Synchronization ⭐⭐⭐
**Goal**: Automatically track and save EditMode layout changes
**Benefits**: No manual saving required, always up-to-date layouts
**Implementation**:
- Hook EditModeManager events (OnLayoutChanged, OnLayoutApplied, etc.)
- Detect when user modifies layouts and auto-save
- Add "auto-save" toggle in options
- Show notifications when layouts are auto-saved

## Phase 2: Advanced Features (Medium Priority)

### 3. Screen Resolution Awareness ⭐⭐
**Goal**: Different layouts/settings per screen resolution
**Benefits**: Optimal layouts for different monitor setups
**Implementation**:
- Detect screen resolution on login
- Store resolution-specific layout preferences
- Auto-apply appropriate layout for current resolution
- Add resolution management UI

### 4. Profile-Based Organization ⭐⭐
**Goal**: AceDB profile support for multiple UI configurations
**Benefits**: Easy switching between different UI setups
**Implementation**:
- Convert to AceDB with profile support
- Add profile management UI
- Profile change callbacks for layout switching
- Import/export profiles

## Phase 3: Robustness & Safety (Medium Priority)

### 5. Enhanced Loading System ⭐⭐
**Goal**: Combat-aware loading with timers and safety checks
**Benefits**: Prevents issues during combat, smoother loading
**Implementation**:
- Add combat lockdown checks before applying layouts
- Use ScheduleTimer for delayed application
- Handle loading screen transitions safely
- Add loading progress indicators

### 6. Comprehensive CVar Tracking ⭐
**Goal**: Track CVars that affect UI elements
**Benefits**: Better understanding of what affects layouts
**Implementation**:
- Build categorized lists of UI-related CVars
- Track CVar changes that affect layouts
- Add CVar validation and restoration
- Warn about conflicting CVar settings

## Implementation Notes

- **Priority Order**: Start with 1 & 2 (core functionality), then 3-6
- **Dependencies**: 1 requires EditMode API knowledge, 2 requires event hooking
- **Testing**: Each feature needs extensive testing across different scenarios
- **Backward Compatibility**: Ensure existing layouts still work
- **User Experience**: Add clear UI feedback for all new features

## Success Criteria

- Users can have different layouts per specialization
- Layouts save automatically when modified
- No more manual layout management required
- Smooth transitions between different setups
- Robust error handling and recovery