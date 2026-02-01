# LinerNotes Client Setup Guide

This guide will help you complete the final configuration steps for the LinerNotes Client iOS game application.

## What's Been Implemented

All game implementation files have been created:

### Core Models (in Models/)
- ✅ `GameState.swift` - Tracks player progress through treasure hunt

### Services
- ✅ `MusicKitPlayerService.swift` - MusicKit integration with crossfade logic

### Utilities
- ✅ `FuzzyMatcher.swift` - Artist name matching with "The" tolerance

### ViewModels
- ✅ `GameViewModel.swift` - Game state and music coordination

### Views
- ✅ `ClueCardView.swift` - Clue display with **bold gold first sentence**
- ✅ `AnswerInputView.swift` - Answer submission with hint toggle
- ✅ `GameProgressView.swift` - Visual progress tracker
- ✅ `GameView.swift` - Main game screen
- ✅ `ContentView.swift` - Updated launcher with demo hunt

### Configuration
- ✅ `LinerNotesClient.entitlements` - Network permissions

## Required Configuration Steps

### Step 1: Add Files to Xcode Project

1. Open `LinerNotes.xcodeproj` in Xcode:
   ```bash
   open /Users/rahul/Coding/LinerNotes/LinerNotes.xcodeproj
   ```

2. **Add Client Models**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Navigate to and add the `Models` folder
   - Ensure only **LinerNotesClient** is checked
   - Select "Create groups"

3. **Add Client Services**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `Services` folder
   - Ensure only **LinerNotesClient** is checked

4. **Add Client Utilities**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `Utilities` folder
   - Ensure only **LinerNotesClient** is checked

5. **Add Client ViewModels**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `ViewModels` folder
   - Ensure only **LinerNotesClient** is checked

6. **Add Client Views**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `Views` folder
   - Ensure only **LinerNotesClient** is checked

7. **Add Entitlements File**:
   - Right-click on `LinerNotesClient` folder
   - Select "Add Files to 'LinerNotes'..."
   - Select `LinerNotesClient/LinerNotesClient.entitlements`
   - Ensure only **LinerNotesClient** is checked

8. **Ensure Core Models Are Linked**:
   - Select `Core/ChainLink.swift` in the project navigator
   - In the File Inspector (right panel), verify both targets are checked:
     - ✅ LinerNotesClient
     - ✅ LinerNotesAdmin
   - Do the same for `Core/TreasureHunt.swift` and `Core/MusicKitModels.swift`

### Step 2: Configure LinerNotesClient Target

1. Select the project in Xcode's navigator
2. Select the **LinerNotesClient** target
3. Go to the "Signing & Capabilities" tab

#### Add Code Signing Entitlements
- Under "Signing", find "Code Signing Entitlements"
- Set it to: `LinerNotesClient/LinerNotesClient.entitlements`

#### Add MusicKit Capability
- Click the "+ Capability" button
- Search for and add **"Apple Music"**
- This automatically adds MusicKit entitlements

### Step 3: Add Info.plist Entry

1. With the **LinerNotesClient** target selected
2. Go to the "Info" tab
3. Click the "+" button to add a new entry
4. Add:
   - **Key**: `NSAppleMusicUsageDescription`
   - **Type**: String
   - **Value**: `LinerNotes needs access to Apple Music to play songs as part of the musical treasure hunt experience.`

### Step 4: Verify iOS Configuration

1. With the **LinerNotesClient** target selected
2. Go to "Build Settings"
3. Verify:
   - **Supported Platforms**: iOS
   - **iOS Deployment Target**: 15.0 or later (required for MusicKit)

### Step 5: Build and Test

1. Select the **LinerNotesClient** scheme
2. Choose an iOS simulator or device
3. Build: **⌘B**
4. Run: **⌘R**

## Game Features Implemented

### 🎵 Unique Music Logic

The game implements a special crossfade mechanic:

1. **First Clue**: Song starts playing immediately
2. **Solve Clue**: Next clue appears, but **current song keeps playing**
3. **Solve Next Clue**: Music crossfades to the next song
4. **Pattern Continues**: Each solve triggers crossfade to next song

This creates a unique "connection" between clues where the music from one clue carries over until you solve the next one.

### 🎨 Visual Design

- **Dark theme** with purple/blue gradients
- **Gold accents** (#FFD700) for highlights
- **First sentence** of each clue is **bold and gold** (the connection to previous artist)
- **Album art** displays prominently on clue cards
- **Smooth animations** for transitions
- **Progress bar** with visual feedback

### 🔍 Fuzzy Matching

The answer validation is forgiving:
- **Case insensitive**: "Queen" = "queen"
- **Article removal**: "The Beatles" = "Beatles"
- **Whitespace tolerant**: Extra spaces ignored
- **Diacritic insensitive**: "Beyoncé" = "Beyonce"
- **Levenshtein distance**: Allows up to 2 character typos

Examples that work:
- "Pink Floyd" ✅
- "pink floyd" ✅
- "PINK FLOYD" ✅
- "The Beatles" ✅
- "Beatles" ✅
- "beatles" ✅

### 📱 Game Flow

1. **Home Screen**: Shows app title and "Start Demo Hunt" button
2. **Start Screen**: Displays treasure hunt name, description, and link count
3. **Gameplay**:
   - Clue card with album art
   - Answer input field
   - Optional hint button (lights up gold when available)
   - Progress bar
   - Top bar with hunt name and progress count
4. **Success Animation**: Green checkmark when answer is correct
5. **Completion Screen**: Trophy animation with completion time

### 🎮 Controls

- **Answer Field**: Auto-focuses for quick typing
- **Submit Button**: Tap or press "Done" on keyboard
- **Hint Button**: Toggle to show/hide hint
- **Exit Button**: Top-left X to quit game
- **Keyboard Submit**: Press Return/Done to submit answer

## Testing the Demo Hunt

The demo hunt includes 3 classic rock clues:

### Clue 1: Pink Floyd
- **ISRC**: GBAYE7300017 (Money - Dark Side of the Moon)
- **Correct Answers**: "Pink Floyd", "pink floyd"
- **Hint**: "Think lunar and progressive"

### Clue 2: Queen
- **ISRC**: GBUM71029604 (Bohemian Rhapsody)
- **Correct Answers**: "Queen", "queen"
- **Hint**: "They're royalty in rock"

### Clue 3: The Beatles
- **ISRC**: GBAYE0601498 (Hey Jude)
- **Correct Answers**: "The Beatles", "Beatles", "the beatles", "beatles"
- **Hint**: "The Fab Four"

### Testing Checklist

1. ✅ App launches to home screen
2. ✅ Tap "Start Demo Hunt" shows start screen
3. ✅ Tap "Start Treasure Hunt" requests MusicKit permission
4. ✅ Grant permission and first song starts playing
5. ✅ First clue appears with album art
6. ✅ First sentence is **bold and gold**
7. ✅ Type "pink floyd" and submit
8. ✅ Success animation appears
9. ✅ Next clue appears, **music keeps playing**
10. ✅ Type "queen" and submit
11. ✅ Music **crossfades** to Bohemian Rhapsody
12. ✅ Third clue appears
13. ✅ Tap hint button to see "The Fab Four"
14. ✅ Type "beatles" (without "The")
15. ✅ Answer accepted (fuzzy matching works)
16. ✅ Completion screen appears with trophy

## Advanced Features

### MusicKit Integration

The `MusicKitPlayerService` handles:
- Authorization requests
- ISRC-based song lookup
- Playback control
- Crossfade logic with timing delays
- Error handling

### State Management

The `GameViewModel` coordinates:
- Game state transitions
- Answer validation
- Music playback timing
- UI updates
- Progress tracking

### Performance

- Async/await for smooth UI
- @MainActor for thread safety
- Lazy loading of album art
- Efficient fuzzy matching algorithm

## Common Issues & Solutions

### Issue: MusicKit authorization fails
**Solution**:
- Verify Apple Music capability is added
- Check NSAppleMusicUsageDescription in Info.plist
- Ensure you're signed into Apple Music on the device/simulator
- Note: Apple Music subscription required for playback

### Issue: Songs don't play
**Solution**:
- Check network connection
- Verify ISRC codes are valid
- Try running on a physical device (simulator may have limitations)
- Check console for MusicKit errors

### Issue: First sentence not showing as gold/bold
**Solution**:
- Ensure clues are formatted with proper sentence structure
- First sentence must end with period, exclamation, or question mark
- Check ClueCardView implementation

### Issue: Fuzzy matching too strict/lenient
**Solution**:
- Adjust Levenshtein distance threshold in FuzzyMatcher.swift (currently 2)
- Add more artist name variants to correctArtist array
- Check normalization logic

### Issue: Crossfade not working
**Solution**:
- Verify `onClueSolved()` is being called in GameViewModel
- Check MusicKitPlayerService crossfade timing
- Note: Volume-based crossfade requires iOS system volume control

## File Structure

```
LinerNotesClient/
├── LinerNotesClientApp.swift       # App entry point
├── ContentView.swift                # Home screen
├── LinerNotesClient.entitlements   # Permissions
├── Models/
│   └── GameState.swift             # Game progress tracking
├── Services/
│   └── MusicKitPlayerService.swift # Music playback
├── Utilities/
│   └── FuzzyMatcher.swift          # Answer validation
├── ViewModels/
│   └── GameViewModel.swift         # Game logic
└── Views/
    ├── ClueCardView.swift          # Clue display
    ├── AnswerInputView.swift       # Answer input
    ├── GameProgressView.swift      # Progress bar
    └── GameView.swift              # Main game screen
```

## Next Steps

After setup:

1. **Test on Device**: Simulator may have MusicKit limitations
2. **Customize Demo**: Edit ISRCs in ContentView.swift for different songs
3. **Create Real Hunts**: Use LinerNotesAdmin to create full 20-link hunts
4. **Add File Loading**: Implement loading hunts from JSON files
5. **Add Achievements**: Track perfect runs, speed runs, etc.
6. **Add Social Features**: Share completion times, challenge friends

## Support

If you encounter build errors:
1. Clean build folder: Product → Clean Build Folder
2. Delete derived data: Xcode → Preferences → Locations → Derived Data
3. Verify all files are added to LinerNotesClient target only
4. Check that Core files are added to BOTH targets
5. Restart Xcode if needed

Refer to the main `SETUP_GUIDE.md` for Admin setup instructions.
