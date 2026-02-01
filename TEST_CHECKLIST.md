# LinerNotes Testing Checklist

## Pre-Test Setup
Open the project in Xcode:
```bash
open LinerNotes.xcodeproj
```

---

## 🎮 Client App Testing (iOS)

### Build & Launch
- [ ] Select scheme: **LinerNotesClient**
- [ ] Select device: **iPhone 15 Simulator** (or any iOS device)
- [ ] Press **⌘R** to build and run
- [ ] **Expected:** App launches without crashes

### Test 1: Data Model Migration
- [ ] App home screen appears with "Start Demo Hunt" button
- [ ] Tap "Start Demo Hunt"
- [ ] **Expected:** Game view appears (no crash)
- [ ] **Expected:** First clue is visible
- [ ] Check Xcode console for any errors

**✅ PASS if:** No crashes, demo hunt loads successfully

### Test 2: New Playback Flow (Critical Change!)
- [ ] Game starts - observe: **NO MUSIC PLAYING**
- [ ] First clue shows: "This Pink Floyd masterpiece..."
- [ ] Type answer: `Pink Floyd`
- [ ] Tap Submit
- [ ] **Expected:** "Correct!" overlay appears
- [ ] **Expected:** Music STARTS PLAYING after overlay
- [ ] **Expected:** Second clue appears while music plays

**✅ PASS if:** Song plays AFTER answer (not before), next clue visible during playback

### Test 3: Answer Queue System
- [ ] While first song is playing, answer second clue
- [ ] Type: `Queen`
- [ ] Tap Submit
- [ ] **Expected:** "Correct!" overlay
- [ ] **Expected:** Second song is QUEUED (doesn't play yet)
- [ ] **Expected:** Third clue appears
- [ ] Wait for first song to finish naturally
- [ ] **Expected:** Second song auto-plays when first ends

**✅ PASS if:** Songs queue properly and auto-transition

### Test 4: Multiple Answer Variants
- [ ] Try answering with: `pink floyd` (lowercase)
- [ ] **Expected:** Accepted as correct
- [ ] Try: `the beatles` vs `beatles`
- [ ] **Expected:** Both work (fuzzy matching)

**✅ PASS if:** Answer variations all work

### Known Limitations (Expected)
- ⚠️ No hint button visible yet (timer runs in background)
- ⚠️ No song info card (will add in Sub-Project 4)
- ⚠️ No now playing bar (will add in Sub-Project 4)

---

## 🛠️ Admin App Testing (macOS)

### Build & Launch
- [ ] Select scheme: **LinerNotesAdmin**
- [ ] Select device: **My Mac**
- [ ] Press **⌘R** to build and run
- [ ] **Expected:** Admin app launches without crashes

### Test 1: Updated Field Names
- [ ] Click "New" to create new treasure hunt
- [ ] Select first link in sidebar
- [ ] Verify editor shows:
  - [ ] **"Hint 1 (Required)"** field (not just "Hint")
  - [ ] **"Hint 2 (Optional)"** field (NEW!)
  - [ ] **"Correct Answers"** section (not "Correct Artist Names")

**✅ PASS if:** All new fields visible, old names gone

### Test 2: Multiple Choice Options Validation
- [ ] Edit first link
- [ ] Scroll to find correct answers section
- [ ] Verify there's a way to add multiple answer variants
- [ ] Check if validation requires answers

**✅ PASS if:** Can add multiple answer variants

### Test 3: No 20-Item Limit
- [ ] Create new hunt
- [ ] Try to add more than 20 links (if possible in current UI)
- [ ] **Expected:** No artificial limit

**Note:** Current UI might still show 20 slots - that's OK, we'll fix in Sub-Project 5

### Test 4: Save/Load with New Format
- [ ] Create a simple hunt with:
  - Clue: "Test clue"
  - Hint 1: "Test hint 1"
  - Hint 2: "Test hint 2"
  - Correct Answers: "Answer1", "Answer2"
- [ ] Save to file (⌘S)
- [ ] Quit app
- [ ] Relaunch and load file (⌘O)
- [ ] **Expected:** All fields load correctly

**✅ PASS if:** Data persists across save/load

---

## 🐛 Common Issues to Watch For

### Issue 1: Import Errors
If you see: `Cannot find 'ChainLink' in scope`
- **Fix:** Make sure Core files are added to BOTH targets
- Check Target Membership in File Inspector

### Issue 2: Song Playback Fails
If music doesn't play:
- **Check:** Apple Music authorization prompt appeared?
- **Check:** Device has Apple Music subscription?
- **Try:** Use real device instead of simulator

### Issue 3: Timer Not Counting Down
If hint timer seems stuck:
- **Check:** Console for timer errors
- **Note:** UI won't show timer yet (that's next step)

---

## 📊 Expected Test Results

### Should Work ✅
- App builds without errors
- Demo hunt loads with new data model
- Songs play AFTER correct answers
- Songs queue and auto-play in sequence
- Save/load preserves new fields
- Admin shows updated field names

### Not Implemented Yet ⚠️
- Hint button UI (logic works, UI pending)
- Song info card display
- Now playing bar
- Table-based admin editor
- Character limit indicators

---

## 🆘 If Tests Fail

**Build Errors:**
1. Check Xcode console for specific error messages
2. Look for "Cannot find..." errors - usually means files not added to target
3. Clean build folder: **Shift+⌘K**, then rebuild

**Runtime Crashes:**
1. Check Xcode console for crash logs
2. Look for nil unwrapping errors
3. Check if old JSON files are incompatible

**Playback Issues:**
1. Verify Apple Music authorization
2. Check ISRCs are valid
3. Try different simulator/device

---

## 📝 Report Back

After testing, please report:
1. Which tests passed ✅
2. Which tests failed ❌
3. Any error messages from Xcode console
4. Screenshots of any unexpected behavior

**Ready to test!** Open Xcode and follow the checklist above.
