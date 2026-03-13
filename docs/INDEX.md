# SuaviUI Documentation Index

## User Documentation

- **[README.md](README.md)** - Main documentation with features, installation, and troubleshooting
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and release notes

## Developer Documentation

### Core Guides
- **[DEVELOPMENT_PRINCIPLES.md](DEVELOPMENT_PRINCIPLES.md)** - Coding standards, architecture decisions, and guidelines
- **[RELEASE_PROCESS.md](RELEASE_PROCESS.md)** - How to build and publish releases (including ZIP creation and GitHub automation)

### Implementation Guides
Located in [`GUIDES/`](GUIDES/):
- **TERTIARY_BAR_IMPLEMENTATION.md** - Strategy for implementing tertiary resource bars
- **CROSS_PROJECT_KNOWLEDGE_PLAYBOOK.md** - Portable debugging, taint-safety, Edit Mode, and release practices for reuse in other addons

### Debugging & Incident Records
- **[BUGSACKER_ANALYSIS_GUIDE.md](BUGSACKER_ANALYSIS_GUIDE.md)** - How to read BugGrabber/BugSack output and triage session errors.
- **[ARCHIVE/CDM_TAINT_INVESTIGATION.md](ARCHIVE/CDM_TAINT_INVESTIGATION.md)** - Historical record of CDM taint bugs (sessions 4891–4927). Superseded by fixes in sessions 4979–5076 and by the taint rules in CLAUDE.md memory.

### Technical References
Located in [`REFERENCES/`](REFERENCES/):
- **KNOWLEDGE_WOW_EVENTS.md** - WoW event system reference
- **LAYOUT_SYSTEM.md** - SuaviUI's layout and positioning system
- **LIBRARY_AUDIT.md** - Inventory of all 3rd-party libraries and versions
- **RESOURCE_BARS_AUDIT.md** - Resource bar implementation details
- **SETTINGS_SAVE_SYSTEM.md** - How settings persistence works

### Archived Documentation
Located in [`ARCHIVE/`](ARCHIVE/):
Contains historical development documentation including:
- Analysis and audit documents from past work
- Experimental implementations (EditMode integrations, CDM features)
- Comparisons with other UI addons (Sensei, AccWideUI)
- API reference documentation
- Asset files (Suavibars PSD, design files)

## File Organization

```
SuaviUI/
├── README.md                 (Root entry point - links to docs/)
├── SuaviUI.toc              (Addon manifest)
├── SuaviUI.code-workspace   (VSCode workspace)
├── init.lua                 (Addon initialization)
├── docs/                    (All documentation)
│   ├── README.md            (Full user documentation)
│   ├── CHANGELOG.md         (Release history)
│   ├── INDEX.md             (This file - documentation roadmap)
│   ├── DEVELOPMENT_PRINCIPLES.md
│   ├── RELEASE_PROCESS.md
│   ├── BUGSACKER_ANALYSIS_GUIDE.md
│   ├── QUI_COMPARISON_ANALYSIS.md
│   ├── GUIDES/              (Implementation guides)
│   ├── REFERENCES/          (Technical references: events, layout, libraries, settings)
│   └── ARCHIVE/             (Historical documentation)
├── dev/                     (Development files)
│   ├── release.sh           (Automated release script)
│   ├── DEBUG_*.lua          (Debug scripts)
│   ├── TEST_*.lua           (Test scripts)
│   ├── package.ps1          (PowerShell build script — legacy)
│   ├── ACE3_UPDATE_REPORT.txt
│   ├── sui_options_backup.lua
│   └── error.log
├── libs/                    (3rd-party libraries)
├── assets/                  (Addon assets)
├── utils/                   (Utility modules)
├── skinning/                (UI skinning)
├── imports/                 (API imports)
└── Locales/                 (Localization)
```

## Quick Navigation

- **"How do I install SuaviUI?"** → [README.md](README.md)
- **"What changed in the latest version?"** → [CHANGELOG.md](CHANGELOG.md)
- **"How do I make a release?"** → [RELEASE_PROCESS.md](RELEASE_PROCESS.md)
- **"Why are CDM 'secret value' errors appearing?"** → [ARCHIVE/CDM_TAINT_INVESTIGATION.md](ARCHIVE/CDM_TAINT_INVESTIGATION.md) (historical) + CLAUDE.md memory (current rules)
- **"What's the code style?"** → [DEVELOPMENT_PRINCIPLES.md](DEVELOPMENT_PRINCIPLES.md)
- **"How are libraries managed?"** → [LIBRARY_AUDIT.md](LIBRARY_AUDIT.md)
- **"How does settings save work?"** → [SETTINGS_SAVE_SYSTEM.md](SETTINGS_SAVE_SYSTEM.md)
- **"What should we copy to another addon repo?"** → [GUIDES/CROSS_PROJECT_KNOWLEDGE_PLAYBOOK.md](GUIDES/CROSS_PROJECT_KNOWLEDGE_PLAYBOOK.md)
- **"What old features existed?"** → [ARCHIVE/](ARCHIVE/)
