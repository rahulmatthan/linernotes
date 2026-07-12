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
- `TreasureHunt.swift`: Container for ChainLinks with metadata (name, description, dates, version) - supports dynamic playlist sizes
- `ChainLink.swift`: Single puzzle with multi-tier hints, multiple choice options, correctAnswers array, song metadata, and album art
- `MusicKitModels.swift`: Wrapper structs for MusicKit search results

### Data Flow

**Admin App:** Create Hunt → Search iTunes API → Auto-populate song ID/artwork/metadata → Save to JSON → Push to GitHub

**Client App:** Fetch JSON from GitHub → Cache locally → Display clue → User solves → Song plays as reward → Next clue appears during song → Continue

### Key Architectural Patterns

**State Management:**
- ViewModels use `@MainActor` and `ObservableObject` for reactive UI updates
- `TreasureHuntViewModel` manages the entire hunt state and file operations
- `MusicSearchViewModel` handles MusicKit authorization and search

**MusicKit Integration:**
- `MusicKitService` (Admin): Thread-safe `actor` for iTunes API search (no auth required) and artwork download
- `MusicKitPlayerService` (Client): `@MainActor` class for playback with song queuing
- Client requires Apple Music authorization via `NSAppleMusicUsageDescription` in Info.plist
- Song lookup priority: Apple Music ID (numeric) → ISRC → term search (title + artist)

**Persistence:**
- JSON files with pretty-printing and ISO8601 dates
- Album art stored as base64-encoded Data in JSON (Phase 1 simplicity)
- Default location: `~/Documents/LinerNotes/TreasureHunts/`
- FileManager extension with async/await NSSavePanel/NSOpenPanel

**Validation:**
- `ChainLink.isValid`: Requires non-empty clue, ISRC, at least one correct answer, and 4 non-empty MC options within character limits
- `ChainLink.isWithinCharacterLimits`: Enforces clue (200), hint1 (150), hint2 (150), MC options (50 each), songInfoText (300)
- `TreasureHunt.isComplete`: All links must be valid (dynamic count, not fixed 20)
- `TreasureHunt.completionPercentage`: Tracks progress (0-100%)

### Admin App Architecture

Two editing modes available:

**Master-detail layout (NavigationSplitView):**
```
TreasureHuntEditorView (main)
├── Sidebar: List of ChainLinkListItemView (status indicators, thumbnails)
├── Detail: ChainLinkEditorView (form with all fields, character counters)
└── Modals:
    ├── MusicSearchSheet (search bar, results, selection)
    └── PreviewSheet (all clues in order)
```

**Table layout (PlaylistTableEditorView):**
```
PlaylistTableEditorView
├── Toolbar: New, Load, Save buttons
├── Table: Inline editing for all ChainLink fields
├── PlaylistRowView: Single row with character counters
└── "Add New Row" button at bottom
```

**Music Search Flow:**
1. User clicks "Search Music" in editor
2. MusicSearchSheet appears (no auth required for iTunes API)
3. User searches → MusicKitService queries iTunes Search API
4. User selects song → auto-populates Apple Music ID, song title, artist name, and downloads artwork
5. Sheet dismisses → ChainLink updates with data

**iTunes API vs MusicKit:**
- Admin uses iTunes Search API (no auth, works without Apple Music subscription)
- Song ID extracted from `trackViewUrl` parameter (`?i=songId`)
- Client then looks up song in Apple Music catalog using that ID

### Client App Architecture

State-driven progression with remote content fetching:

```
ContentView (entry point, fetches hunt from GitHub)
└── fullScreenCover → GameView
    ├── Album art background (blurred fill + centered letterboxed)
    ├── Clue card with progressive hints (HintDisplayView)
    ├── Answer input with fuzzy matching
    ├── "That is correct" overlay → Song info card
    ├── NowPlayingBar (thin progress bar at bottom)
    └── Completion screen (end of playlist)
```

**Content Loading (ContentView):**
- Priority: Remote GitHub → Cached → Bundled → Demo
- Remote URL: `https://raw.githubusercontent.com/rahulmatthan/linernotes-data/refs/heads/main/Version%201.json`
- Successful fetches are cached in app's cache directory

**Answer Validation:**
- Case insensitive comparison
- Removes "the " prefix for matching
- FuzzyMatcher supports Levenshtein distance (up to 2 chars difference)
- Accepts multiple answer variants from `correctAnswers` array

**Progressive Hint System:**
- Hint appears automatically after 45 seconds from clue appearance
- After hint1, multiple choice appears (15s later for first song, or when 10s remain in current song for subsequent songs)
- Multiple choice is skipped in hard mode
- User can type answer OR select MC option

**Music Playback (MusicKitPlayerService):**
- Songs play AFTER correct answer (reward), not before
- If song already playing, new song is queued
- Queued song auto-plays when current song naturally finishes
- Song lookup: Apple Music ID first, then ISRC, then term search fallback
- Uses ApplicationMusicPlayer from MusicKit

### Game Flow State Machine

The client app uses several overlay states to control what's visible during gameplay. Understanding this state machine is critical to avoid bugs where the clue appears prematurely during transitions.

**Overlay State Variables (GameViewModel):**
| State | Purpose |
|-------|---------|
| `showingCorrectMessage` | "Correct" overlay with answer text |
| `showingSongStartInfo` | "NOW PLAYING" overlay with song title, artist, and songStartInfo |
| `showingSongInfo` | Song info overlay (currently unused in main flow) |
| `waitingForNextSong` | Trivia/queued song indicator while waiting for queued song |
| `transitionPause` | **Critical:** Keeps clue hidden during 1-second pauses between overlays |
| `showFadeToBlack` | Full black screen (used in onboarding only) |

**Clue Visibility Logic (GameView.swift lines 311-318):**
```swift
if viewModel.showingSongInfo {
    songInfoOverlay
} else if viewModel.waitingForNextSong || viewModel.showingCorrectMessage ||
          viewModel.showingSongStartInfo || viewModel.transitionPause {
    closeButtonHeader  // Clue is hidden, only close button visible
} else {
    clueScreen  // Clue is visible
}
```

**IMPORTANT:** The `transitionPause` state must be `true` during the 1-second pauses between overlays, otherwise the clue will flash briefly before the next overlay appears.

---

#### First Song Flow (No Song Playing Yet)

**Location:** `GameViewModel.submitAnswer()` lines 358-395

```
User submits correct answer
    ↓
Album art appears as background (immediate)
    ↓
"Correct" overlay appears (showingCorrectMessage = true)
    ↓
Song starts playing
    ↓
Wait 7 seconds
    ↓
transitionPause = true, showingCorrectMessage = false
    ↓
Wait 1 second (clue hidden by transitionPause)
    ↓
[If songStartInfo exists:]
    showingSongStartInfo = true, transitionPause = false
        ↓
    "NOW PLAYING" overlay visible for 7 seconds
        ↓
    transitionPause = true, showingSongStartInfo = false
        ↓
    Wait 1 second (clue hidden by transitionPause)
        ↓
    transitionPause = false
[Else:]
    transitionPause = false
    ↓
advanceToNextClue() → Next clue appears
```

**Timing Summary (First Song):**
- Correct overlay: 7 seconds
- Pause: 1 second
- Song Start Info overlay: 7 seconds (if exists)
- Pause: 1 second (if Song Start Info was shown)
- Next clue appears

---

#### Subsequent Songs Flow (Song Already Playing → Queued)

**Location:** `GameViewModel.submitAnswer()` lines 338-357 and `startObservingQueuedSong()` lines 405-466

**Part 1: When user answers correctly (song gets queued):**
```
User submits correct answer while song is playing
    ↓
"Correct" overlay appears (showingCorrectMessage = true)
    ↓
New song is queued (not playing yet)
    ↓
Wait 7 seconds
    ↓
waitingForNextSong = true, showingCorrectMessage = false
    ↓
Trivia indicator appears (shows trivia about CURRENTLY PLAYING song)
    ↓
[User waits for current song to finish, or taps Skip]
```

**Part 2: When queued song starts playing:**
```
Queued song becomes now playing (detected by polling)
    ↓
Album art updates to new song
    ↓
Trivia timer stops
    ↓
[If songStartInfo exists:]
    showingSongStartInfo = true, waitingForNextSong = false
        ↓
    "NOW PLAYING" overlay visible for 7 seconds
        ↓
    transitionPause = true, showingSongStartInfo = false
        ↓
    Wait 1 second (clue hidden by transitionPause)
        ↓
    transitionPause = false
[Else:]
    waitingForNextSong = false
    ↓
advanceToNextClue() → Next clue appears
```

**Key Difference from First Song:** Subsequent songs do NOT show the "Correct" overlay with answer text after the queued song starts - they only show the "NOW PLAYING" Song Start Info overlay.

---

#### All Timing Constants

| Component | Duration | Location |
|-----------|----------|----------|
| Auto hint timer | 45 seconds | `GameViewModel.swift` line 184 |
| Auto MC timer (first song) | 15 seconds after hint | `GameViewModel.swift` line 218 |
| Auto MC timer (subsequent) | When 10s remain in song | `GameViewModel.swift` line 251 |
| "Correct" overlay | 7 seconds | `GameViewModel.swift` lines 340, 360 |
| "NOW PLAYING" overlay | 7 seconds | `GameViewModel.swift` lines 378, 439 |
| Transition pause | 1 second | `GameViewModel.swift` lines 370, 385, 446 |
| Trivia cycle interval | 10 seconds | `GameViewModel.swift` line 525 |
| Overlay fade animations | 1.5 seconds | `GameView.swift` lines 320-324 |
| Album art transition | 0.8 seconds | `GameView.swift` lines 178-179 |

---

#### Common Pitfalls (Game Flow)

**Clue flashing during transitions:**
- Cause: `transitionPause` not set to `true` before hiding an overlay
- Fix: Always set `transitionPause = true` BEFORE setting other overlay states to `false`

**Overlays not fading smoothly:**
- Cause: Missing `.animation()` modifier for a state variable
- Fix: Ensure all overlay states have corresponding animation modifiers in `gameScreen()`

**Wrong timing between overlays:**
- Cause: Sleep durations modified without updating documentation
- Fix: Keep timing constants documented and update this section when changing values

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

**Wrong song playing:**
- iTunes API doesn't provide real ISRCs
- Solution: Extract Apple Music ID from `trackViewUrl` (`?i=songId` parameter)
- Client looks up by ID first, then falls back to ISRC, then term search

## Content Deployment

Hunt JSON files are hosted on GitHub for over-the-air updates:
- Repository: `https://github.com/rahulmatthan/linernotes-data`
- Raw URL format: `https://raw.githubusercontent.com/rahulmatthan/linernotes-data/refs/heads/main/[filename].json`
- To update content: Push new JSON to GitHub, client will fetch on next app launch
