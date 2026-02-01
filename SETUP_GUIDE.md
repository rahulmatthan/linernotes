# LinerNotes Admin Setup Guide

This guide will help you complete the final configuration steps for the LinerNotes Admin application.

## Files Created

All implementation files have been created in the following locations:

### Core Models (shared between Client and Admin)
- ✅ `Core/ChainLink.swift` - Extended with album art support
- ✅ `Core/TreasureHunt.swift` - New treasure hunt model
- ✅ `Core/MusicKitModels.swift` - MusicKit wrapper models

### Admin Services & Utilities
- ✅ `LinerNotesAdmin/Utilities/MusicKitService.swift` - MusicKit integration
- ✅ `LinerNotesAdmin/Utilities/FileManager+TreasureHunt.swift` - File persistence

### Admin ViewModels
- ✅ `LinerNotesAdmin/ViewModels/TreasureHuntViewModel.swift` - Main state management
- ✅ `LinerNotesAdmin/ViewModels/MusicSearchViewModel.swift` - Music search state

### Admin Views
- ✅ `LinerNotesAdmin/Views/ChainLinkListItemView.swift` - Sidebar list items
- ✅ `LinerNotesAdmin/Views/MusicSearchSheet.swift` - Music search modal
- ✅ `LinerNotesAdmin/Views/ChainLinkEditorView.swift` - Chain link form editor
- ✅ `LinerNotesAdmin/Views/PreviewSheet.swift` - Preview modal
- ✅ `LinerNotesAdmin/Views/TreasureHuntEditorView.swift` - Main editor UI
- ✅ `LinerNotesAdmin/AdminContentView.swift` - Updated entry point

### Configuration Files
- ✅ `LinerNotesAdmin/LinerNotesAdmin.entitlements` - App sandbox entitlements

## Required Configuration Steps

### Step 1: Add Files to Xcode Project

1. Open `LinerNotes.xcodeproj` in Xcode:
   ```bash
   open /Users/rahul/Coding/LinerNotes/LinerNotes.xcodeproj
   ```

2. **Add Core Models** (these should be added to BOTH targets):
   - Right-click on the `Core` folder in Xcode
   - Select "Add Files to 'LinerNotes'..."
   - Navigate to and select:
     - `Core/TreasureHunt.swift`
     - `Core/MusicKitModels.swift`
   - In the dialog, ensure **both** checkboxes are selected:
     - ✅ LinerNotesClient
     - ✅ LinerNotesAdmin
   - Click "Add"

3. **Add Admin Utilities**:
   - Right-click on `LinerNotesAdmin` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `Utilities` folder
   - Ensure only **LinerNotesAdmin** is checked
   - Select "Create groups" (not folder references)

4. **Add Admin ViewModels**:
   - Right-click on `LinerNotesAdmin` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `ViewModels` folder
   - Ensure only **LinerNotesAdmin** is checked

5. **Add Admin Views**:
   - Right-click on `LinerNotesAdmin` folder
   - Select "Add Files to 'LinerNotes'..."
   - Add the `Views` folder
   - Ensure only **LinerNotesAdmin** is checked

6. **Add Entitlements File**:
   - Right-click on `LinerNotesAdmin` folder
   - Select "Add Files to 'LinerNotes'..."
   - Select `LinerNotesAdmin/LinerNotesAdmin.entitlements`
   - Ensure only **LinerNotesAdmin** is checked

### Step 2: Configure LinerNotesAdmin Target

1. Select the project in Xcode's navigator
2. Select the **LinerNotesAdmin** target
3. Go to the "Signing & Capabilities" tab

#### Add Code Signing Entitlements
- Under "Signing", find "Code Signing Entitlements"
- Set it to: `LinerNotesAdmin/LinerNotesAdmin.entitlements`

#### Add MusicKit Capability
- Click the "+ Capability" button
- Search for and add **"Apple Music"** (this adds MusicKit)
- This will automatically configure the required entitlements

### Step 3: Add Info.plist Entry

1. With the **LinerNotesAdmin** target selected
2. Go to the "Info" tab
3. Click the "+" button to add a new entry
4. Add the following key-value pair:
   - **Key**: `NSAppleMusicUsageDescription`
   - **Type**: String
   - **Value**: `LinerNotes Admin searches Apple Music to populate treasure hunt songs with accurate metadata and artwork.`

### Step 4: Verify macOS Configuration

1. With the **LinerNotesAdmin** target selected
2. Go to "Build Settings"
3. Search for "SDK" and verify:
   - **Base SDK**: macOS
   - **Supported Platforms**: macOS

4. Search for "Deployment Target" and verify:
   - **macOS Deployment Target**: 14.0 or later

5. Remove any iOS-specific settings if present:
   - Search for "TARGETED_DEVICE_FAMILY" - should not be set
   - Search for "IPHONEOS_DEPLOYMENT_TARGET" - should not be set

### Step 5: Build and Test

1. Select the **LinerNotesAdmin** scheme from the scheme selector
2. Build the project: **⌘B**
3. Fix any remaining build errors (there shouldn't be any if files are added correctly)
4. Run the app: **⌘R**

### Step 6: Verify Functionality

Once the app launches, test the following:

1. **Create New Hunt**:
   - Click "New" button
   - Verify a hunt with 20 empty chain links is created

2. **Edit Hunt Metadata**:
   - Click "Info" button
   - Set hunt name and description
   - Verify changes are saved

3. **Edit Chain Link**:
   - Select a link from the sidebar
   - Enter clue text
   - Click "Search Music"

4. **MusicKit Authorization**:
   - Grant MusicKit permission when prompted
   - Search for a song (e.g., "Bohemian Rhapsody")
   - Select a song from results
   - Verify ISRC and album art are auto-populated

5. **Add Artist Variants**:
   - Add artist name variations
   - Verify chips appear and can be removed

6. **Preview**:
   - Click "Preview" after editing a few links
   - Verify all links display correctly

7. **Save**:
   - Complete all 20 links (or test with partially complete hunt)
   - Click "Save"
   - Choose a location and save as JSON
   - Open the JSON file to verify it's properly formatted

8. **Load**:
   - Click "New" to clear the current hunt
   - Click "Load"
   - Select the saved JSON file
   - Verify all data loads correctly

## Common Issues & Solutions

### Issue: "Cannot find [Type] in scope"
**Solution**: Files not added to correct targets. Ensure:
- Core models are added to BOTH LinerNotesClient and LinerNotesAdmin
- Admin-specific files are only added to LinerNotesAdmin

### Issue: MusicKit authorization fails
**Solution**: Verify:
- Apple Music capability is added
- NSAppleMusicUsageDescription is in Info.plist
- You have an Apple Music subscription (required for MusicKit)

### Issue: File save/load doesn't work
**Solution**: Verify entitlements file includes:
- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-write` = true

### Issue: Album art doesn't display
**Solution**: Verify:
- Network entitlement is set: `com.apple.security.network.client` = true
- Album art data is being downloaded (check console logs)

## Architecture Notes

### State Management
- `TreasureHuntViewModel` is the single source of truth
- Changes to chain links trigger automatic saves via `@Published`
- Metadata edits update `modifiedDate` automatically

### File Persistence
- JSON files are saved with pretty printing for readability
- Album art is stored as base64-encoded Data in JSON
- Default save location: `~/Documents/LinerNotes/TreasureHunts/`

### MusicKit Integration
- `MusicKitService` is an actor for thread-safety
- Authorization is requested on first search attempt
- Artwork downloads are async and can fail gracefully

### Validation
- Chain links require: non-empty clue, non-empty ISRC, at least one artist
- Hint and album art are optional
- Save button is disabled until all 20 links are valid

## Next Steps

After completing setup:

1. **Test End-to-End**: Create a complete 20-link treasure hunt
2. **Verify JSON Format**: Ensure exported JSON is valid and readable
3. **Test Edge Cases**: Try offline mode, denied permissions, invalid JSON loads
4. **Performance**: Test with large album art files

## Support

If you encounter issues:
1. Check the console for error messages
2. Verify all files are added to correct targets
3. Clean build folder: Product → Clean Build Folder
4. Restart Xcode if needed

Refer to the implementation plan in `/Users/rahul/.claude/projects/-Users-rahul-Coding-LinerNotes/93684109-b042-4c2c-b97a-63c92a383838.jsonl` for detailed architecture decisions.
