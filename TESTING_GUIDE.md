# Quick Testing Guide

## How to Test in 5 Minutes

### Option 1: Test Client App (Recommended First)

```bash
# 1. Open project
open LinerNotes.xcodeproj

# 2. In Xcode:
#    - Top bar: Select "LinerNotesClient" scheme
#    - Select "iPhone 15" simulator
#    - Press ⌘R (or click Play button)

# 3. When app launches:
#    - Tap "Start Demo Hunt"
#    - Type "Pink Floyd" and submit
#    - 🎵 Music should start AFTER you answer (not before!)
#    - Next clue should appear while music plays
```

**What Changed:**
- **OLD:** Music played immediately when clue appeared
- **NEW:** Music plays as REWARD after correct answer

### Option 2: Test Admin App

```bash
# 1. Open project (if not already open)
open LinerNotes.xcodeproj

# 2. In Xcode:
#    - Top bar: Select "LinerNotesAdmin" scheme
#    - Select "My Mac"
#    - Press ⌘R

# 3. When app launches:
#    - Click sidebar item
#    - Look for "Hint 1" and "Hint 2" fields (not just "Hint")
#    - Look for "Correct Answers" (not "Correct Artist Names")
```

**What Changed:**
- **OLD:** Single "hint" field, "correctArtist" array
- **NEW:** "hint1", "hint2", "correctAnswers" with MC options support

---

## Expected Console Output

When running client app, you should see:
```
🔵 Button tapped!
🔵 Hunt created: Classic Rock Demo
🟢 Creating GameView with hunt: Classic Rock Demo
```

No errors should appear!

---

## Quick Troubleshooting

**If build fails:**
- Clean build: Shift+⌘K, then ⌘B
- Check Xcode console for error messages
- Common error: "Cannot find ChainLink" → Core files not in both targets

**If app crashes:**
- Check console for crash log
- Most likely: Old JSON file incompatibility
- Solution: Use demo hunt instead of loading files

**If music doesn't play:**
- Grant Apple Music permission when prompted
- Use real device if simulator has issues
- Check internet connection (streams from Apple Music)

---

## What You Should See

### Client App Flow:
1. **Home Screen** → Gold "Start Demo Hunt" button
2. **Game View** → First clue visible, NO music yet
3. **Type Answer** → "Pink Floyd"
4. **Submit** → "Correct!" overlay (1 sec)
5. **🎵 Music Starts** → Dark Side of the Moon plays
6. **Next Clue** → Appears while music continues

### Admin App:
1. **Editor View** → NavigationSplitView (sidebar + detail)
2. **Sidebar** → List of 20 numbered links (this will change later)
3. **Detail** → Form with:
   - "Clue" text editor
   - "Hint 1 (Required)" text editor
   - "Hint 2 (Optional)" text editor
   - "Correct Answers" tag editor
   - ISRC field with search button

---

## Success Criteria

✅ **Minimum Working State:**
- Both apps build without errors
- Client plays demo hunt
- Songs play AFTER answers (new behavior)
- Admin shows updated field names

⚠️ **Not Working Yet (Expected):**
- Hint button UI (timer exists, button doesn't)
- Song info popup
- Table-based editor (still using old UI)
- Character count limits (logic exists, UI doesn't show)

---

## Next Steps After Testing

Once you confirm everything works:
1. **Report results** - Tell me what passed/failed
2. **Continue implementation** - We'll build the UI components next
3. **Or pause** - Review code and architecture before proceeding

**Estimated test time: 5-10 minutes**
