# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LinerNotes is a musical treasure hunt application built with SwiftUI. The project consists of two separate apps sharing a common core:

- **LinerNotesClient**: iOS app (iOS 16.0+) for players to solve musical treasure hunts
- **LinerNotesAdmin**: macOS app (macOS 14.0+) for creators to build treasure hunts

Both apps share the `Core/` directory which contains shared data models and business logic.

## Architecture

### Multi-Target Structure

The project uses a single Xcode workspace with two independent app targets that share core models but have completely separate UI and services:

**LinerNotesClient** (iOS)
- Entry: `LinerNotesClientApp.swift` → `ContentView.swift`
- Platform: iOS 16.0+
- Purpose: Game interface for players
- Key dependencies: MusicKit for playback

**LinerNotesAdmin** (macOS)
- Entry: `LinerNotesAdminApp.swift` → `AdminContentView.swift` → `TreasureHuntEditorView.swift`
- Platform: macOS 14.0+
- Purpose: Treasure hunt creation with MusicKit song search
- Key dependencies: MusicKit for search, AppKit for file panels

**Core** (Shared)
- `TreasureHunt.swift`: Container for 20 ChainLinks with metadata (name, description, dates, version)
- `ChainLink.swift`: Single puzzle with clue, hint, correctArtist array, ISRC, and album art data
- `MusicKitModels.swift`: Wrapper structs for MusicKit search results

### Data Flow

**Admin App:** Create Hunt → Search MusicKit → Auto-populate ISRC/artwork → Save to JSON → Export file

**Client App:** Load Hunt JSON → Display clues one-by-one → Validate answers → Play songs via MusicKit → Show completion

### Key Architectural Patterns

**State Management:**
- ViewModels use `@MainActor` and `ObservableObject` for reactive UI updates
- `TreasureHuntViewModel` manages the entire hunt state and file operations
- `MusicSearchViewModel` handles MusicKit authorization and search

**MusicKit Integration:**
- `MusicKitService` (Admin): Thread-safe `actor` for search and artwork download
- `MusicKitPlayerService` (Client): `@MainActor` class for playback with crossfade logic
- Both require Apple Music authorization via `NSAppleMusicUsageDescription` in Info.plist

**Persistence:**
- JSON files with pretty-printing and ISO8601 dates
- Album art stored as base64-encoded Data in JSON (Phase 1 simplicity)
- Default location: `~/Documents/LinerNotes/TreasureHunts/`
- FileManager extension with async/await NSSavePanel/NSOpenPanel

**Validation:**
- `ChainLink.isValid`: Requires non-empty clue, ISRC, and at least one artist name
- `TreasureHunt.isComplete`: All 20 links must be valid
- `TreasureHunt.completionPercentage`: Tracks progress (0-100%)

### Admin App Architecture

Master-detail layout using `NavigationSplitView`:

```
TreasureHuntEditorView (main)
├── Sidebar: List of 20 ChainLinkListItemView (status indicators, thumbnails)
├── Detail: ChainLinkEditorView (form with TextEditor, artist tags, ISRC)
└── Modals:
    ├── MusicSearchSheet (search bar, results, selection)
    ├── PreviewSheet (all 20 clues in order)
    └── InfoSheet (hunt metadata: name, description)
```

**Music Search Flow:**
1. User clicks "Search Music" in ChainLinkEditorView
2. MusicSearchSheet appears, requests authorization if needed
3. User searches → MusicKitService queries Apple Music Catalog
4. User selects song → auto-populates ISRC and downloads artwork
5. Sheet dismisses → ChainLinkEditorView updates with data

### Client App Architecture

Simple single-card view with state-driven progression:

```
ContentView (entry with demo hunt button)
└── fullScreenCover → GameView
    ├── Current clue display (first sentence can be bold/gold)
    ├── Answer input with fuzzy matching (FuzzyMatcher)
    ├── Success overlay (1 second, then advance)
    └── Completion screen (trophy)
```

**Answer Validation:**
- Case insensitive comparison
- Removes "the " prefix for matching
- FuzzyMatcher supports Levenshtein distance (up to 2 chars difference)
- Accepts multiple artist name variants from `correctArtist` array

**Music Playback (MusicKitPlayerService):**
- Unique crossfade mechanic: song continues playing after solve until next solve
- First clue: plays immediately
- Subsequent clues: crossfades from previous song when answered correctly
- Uses ApplicationMusicPlayer from MusicKit

## Building and Running

### In Xcode (Recommended)
```bash
open LinerNotes.xcodeproj
```

Select scheme (LinerNotesClient or LinerNotesAdmin) and press ⌘R.

### Command Line
```bash
# Build client (iOS)
xcodebuild -project LinerNotes.xcodeproj -scheme LinerNotesClient -configuration Debug

# Build admin (macOS)
xcodebuild -project LinerNotes.xcodeproj -scheme LinerNotesAdmin -configuration Debug

# Run client in simulator
xcodebuild -project LinerNotes.xcodeproj -scheme LinerNotesClient -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests (when added)
xcodebuild test -project LinerNotes.xcodeproj -scheme LinerNotesClient -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Development Guidelines

### Adding Files to Targets

**Core files** must be added to BOTH targets:
1. Add file to `Core/` directory
2. In Xcode File Inspector: check both LinerNotesClient and LinerNotesAdmin under "Target Membership"
3. Verify both targets appear in build phases (Sources section)

**Platform-specific code in Core:**
```swift
#if canImport(AppKit)
import AppKit  // macOS
#elseif canImport(UIKit)
import UIKit   // iOS
#endif
```

### MusicKit Authorization

Both apps require `NSAppleMusicUsageDescription` in build settings:
- Client: "LinerNotes needs access to Apple Music to play songs as part of the musical treasure hunt experience."
- Admin: "LinerNotes Admin searches Apple Music to populate treasure hunt songs with accurate metadata and artwork."

These are set in `project.pbxproj` under `INFOPLIST_KEY_NSAppleMusicUsageDescription`.

### Project Configuration Critical Points

**Client (iOS):**
- `SDKROOT = iphoneos`
- `IPHONEOS_DEPLOYMENT_TARGET = 16.6` (requires iOS 16.0 for NavigationStack)
- `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone and iPad)

**Admin (macOS):**
- `SDKROOT = macosx`
- `MACOSX_DEPLOYMENT_TARGET = 14.0` (requires macOS 14.0 for MusicKit actor support)
- Must NOT have `IPHONEOS_DEPLOYMENT_TARGET` or `TARGETED_DEVICE_FAMILY`

### Common Pitfalls

**Blank screen issues:**
- Use `.fullScreenCover(item:)` instead of `.fullScreenCover(isPresented:)` to avoid timing issues with nil data
- Ensure TreasureHunt is passed as binding, not copied

**Build errors "Cannot find type":**
- File not added to correct target's build phase
- Check Target Membership in File Inspector

**Privacy crash:**
- Missing `NSAppleMusicUsageDescription` in build settings
- Rebuild after adding to `project.pbxproj`

**Platform mismatch:**
- AppKit imports in iOS code or UIKit imports in macOS code
- Use conditional imports with `#if canImport()`
