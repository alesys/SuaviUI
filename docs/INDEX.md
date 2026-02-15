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
│   ├── KNOWLEDGE_WOW_EVENTS.md
│   ├── LAYOUT_SYSTEM.md
│   ├── LIBRARY_AUDIT.md
│   ├── RESOURCE_BARS_AUDIT.md
│   ├── SETTINGS_SAVE_SYSTEM.md
│   ├── GUIDES/              (Implementation guides and strategies)
│   ├── REFERENCES/          (Technical reference documents)
│   └── ARCHIVE/             (Historical development documentation)
├── dev/                     (Development files)
│   ├── DEBUG_*.lua          (Debug scripts)
│   ├── TEST_*.lua           (Test scripts)
│   ├── package.ps1          (PowerShell build script)
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
- **"What's the code style?"** → [DEVELOPMENT_PRINCIPLES.md](DEVELOPMENT_PRINCIPLES.md)
- **"How are libraries managed?"** → [LIBRARY_AUDIT.md](LIBRARY_AUDIT.md)
- **"How does settings save work?"** → [SETTINGS_SAVE_SYSTEM.md](SETTINGS_SAVE_SYSTEM.md)
- **"What old features existed?"** → [ARCHIVE/](ARCHIVE/)
