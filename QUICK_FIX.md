# Quick Fix: Add Files to Xcode Project

**Xcode is now open. Follow these steps to add all missing files.**

## Step 1: Add Core Models (to BOTH targets)

1. In Xcode, **right-click** on the **"Core"** folder in the left sidebar
2. Select **"Add Files to 'LinerNotes'..."**
3. In the file picker, navigate to the `Core` folder
4. **Select these files** (hold ⌘ to select multiple):
   - `TreasureHunt.swift`
   - `MusicKitModels.swift`
5. **IMPORTANT**: In the dialog, check **BOTH** boxes:
   - ✅ LinerNotesClient
   - ✅ LinerNotesAdmin
6. Click **"Add"**

## Step 2: Add Client Files (to LinerNotesClient ONLY)

### 2a. Add Models Folder
1. Right-click **"LinerNotesClient"** folder
2. Select **"Add Files to 'LinerNotes'..."**
3. Select the **"Models"** folder (the whole folder)
4. Check **ONLY**:
   - ✅ LinerNotesClient
   - ⬜ LinerNotesAdmin (unchecked)
5. Ensure **"Create groups"** is selected (not "Create folder references")
6. Click **"Add"**

### 2b. Add Services Folder
1. Right-click **"LinerNotesClient"** folder
2. Select **"Add Files to 'LinerNotes'..."**
3. Select the **"Services"** folder
4. Check **ONLY**: ✅ LinerNotesClient
5. Click **"Add"**

### 2c. Add Utilities Folder
1. Right-click **"LinerNotesClient"** folder
2. Select **"Add Files to 'LinerNotes'..."**
3. Select the **"Utilities"** folder
4. Check **ONLY**: ✅ LinerNotesClient
5. Click **"Add"**

### 2d. Add ViewModels Folder
1. Right-click **"LinerNotesClient"** folder
2. Select **"Add Files to 'LinerNotes'..."**
3. Select the **"ViewModels"** folder
4. Check **ONLY**: ✅ LinerNotesClient
5. Click **"Add"**

### 2e. Add Views Folder
1. Right-click **"LinerNotesClient"** folder
2. Select **"Add Files to 'LinerNotes'..."**
3. Select the **"Views"** folder
4. Check **ONLY**: ✅ LinerNotesClient
5. Click **"Add"**

## Step 3: Add MusicKit Capability

1. Select the **project** (top item "LinerNotes" in sidebar)
2. Select **LinerNotesClient** target
3. Click **"Signing & Capabilities"** tab
4. Click **"+ Capability"** button
5. Search for and add **"Apple Music"**

## Step 4: Add Info.plist Entry

1. Still in **LinerNotesClient** target
2. Click **"Info"** tab
3. Hover over any key and click the **"+"** button
4. Add:
   - **Key**: `NSAppleMusicUsageDescription`
   - **Type**: String
   - **Value**: `LinerNotes needs access to Apple Music to play songs as part of the musical treasure hunt experience.`

## Step 5: Build

1. Select **"LinerNotesClient"** scheme from the scheme selector (top bar)
2. Press **⌘B** to build
3. If successful, press **⌘R** to run

---

## Alternative: Use Terminal Commands

If you prefer command-line, run these commands:

```bash
cd /Users/rahul/Coding/LinerNotes

# Create a reference file for adding
cat > add_files.txt << 'EOF'
Core/TreasureHunt.swift
Core/MusicKitModels.swift
LinerNotesClient/Models/GameState.swift
LinerNotesClient/Services/MusicKitPlayerService.swift
LinerNotesClient/Utilities/FuzzyMatcher.swift
LinerNotesClient/ViewModels/GameViewModel.swift
LinerNotesClient/Views/GameView.swift
LinerNotesClient/Views/ClueCardView.swift
LinerNotesClient/Views/AnswerInputView.swift
LinerNotesClient/Views/GameProgressView.swift
EOF

echo "Files ready to add - now open Xcode and follow Step 1-5 above"
```

---

## Verification

After adding files, your project structure should look like:

```
LinerNotes
├── LinerNotesClient
│   ├── LinerNotesClientApp.swift
│   ├── ContentView.swift
│   ├── Assets.xcassets
│   ├── Models
│   │   └── GameState.swift
│   ├── Services
│   │   └── MusicKitPlayerService.swift
│   ├── Utilities
│   │   └── FuzzyMatcher.swift
│   ├── ViewModels
│   │   └── GameViewModel.swift
│   └── Views
│       ├── GameView.swift
│       ├── ClueCardView.swift
│       ├── AnswerInputView.swift
│       └── GameProgressView.swift
├── LinerNotesAdmin
│   └── (existing files)
└── Core
    ├── ChainLink.swift
    ├── TreasureHunt.swift
    └── MusicKitModels.swift
```

All Core files should have **both** targets checked.
All LinerNotesClient files should have **only LinerNotesClient** target checked.
