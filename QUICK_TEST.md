# 🚀 Quick Test - 2 Minutes

## Start Here

```bash
open LinerNotes.xcodeproj
```

## Test 1: Client App (30 seconds)

1. **Build:** Select `LinerNotesClient` scheme → iPhone 15 → Press ⌘R
2. **Run:** Tap "Start Demo Hunt"
3. **Answer:** Type "Pink Floyd" → Submit
4. **Verify:**
   - ✅ Music plays AFTER answer (not before)
   - ✅ Next clue appears while music plays

**Expected NEW behavior:** Song = Reward for correct answer!

---

## Test 2: Admin App (30 seconds)

1. **Build:** Select `LinerNotesAdmin` scheme → My Mac → Press ⌘R
2. **Check:** Click any sidebar item
3. **Verify:**
   - ✅ See "Hint 1" and "Hint 2" fields
   - ✅ See "Correct Answers" (not "Correct Artist Names")

**Expected NEW fields:** Multiple hints + multiple answer variants!

---

## ✅ Success = Both apps launch without errors

## ❌ If build fails:
1. Check Xcode console (bottom panel)
2. Copy error message
3. Report back

---

## Full Details
- See `TEST_CHECKLIST.md` for comprehensive tests
- See `TESTING_GUIDE.md` for detailed instructions
