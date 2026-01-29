# OCR & Performance Optimization Plan

## 1. Questions & Analysis

### Q1: Why was `close()` replaced?
**Analysis:** You are absolutely correct. Removing `close()` was a mistake in the previous edit. It has nothing to do with `clearAllData()` and should remain in the class for proper resource management.
**Fixed Plan:** Restore `close()` method alongside `clearAllData()`.

### Q2: Are `ReceiptValidator` changes necessary?
**Analysis:** Yes, they are critical.
*   **The Issue:** The previous logic was too lenient. It "accumulated" points for every keyword. A text like "Date of transaction order" would get 3 separate points (Date+2, Transaction+2, Order+2 = 6), passing the threshold (4) even without any price or currency.
*   **The Fix:** The new logic *caps* keyword points and *requires* specific combinations (like Price + Date) to pass. Even with a fresh DB, the old validator would still incorrectly classify your selfies as receipts if they contained enough generic words.

### Q3: Classification Service & Hashing
**Analysis:** You observed that we aren't fully utilizing the hash for optimization in `ClassificationService`.
*   **Current State:** We use `metadataHash` as the lookup key (`where: 'metadata_hash = ?'`).
*   **Risk:** If we don't check for existing *completed* classifications effectively before queuing, we might re-process.
*   **Plan:** Ensure we check if a hash already exists with `status = completed` before adding it to the queue, although filtering by `ProcessingStatus.ocrComplete` implicitly handles this flow. We should verify this robustly.

---

## 2. critical Performance & UX Issues

### Issue A: Main Thread Jank (1000+ Images)
**Observation:** "OCR of over 1000 images on the main thread is janking the app."
**Root Cause:** The `ProcessingPipeline` runs `_ocrService.extractText(file)` which likely calls MethodChannels or heavy computation on the main UI isolate. When processing a loop of 1000 items, even async gaps aren't enough to prevent frame drops.
**Solution:** Move the entire OCR heavy task to a **Flutter Isolate (Compute)**. This runs it on a separate thread, leaving the UI butter smooth.

### Issue B: Progress Visibility
**Observation:** "No progress visibility for the OCR being done."
**Root Cause:** The user triggers the load, and it happens silently in the background. The only visual feedback is images popping in or status badges changing one by one (if visible).
**Solution:**
1.  Add a `ValueNotifier` or Stream for `processedCount / totalCount`.
2.  Show a linear progress indicator in the AppBar or a "Processing... 5/1000" banner when active.

### Issue C: Status Updates Lag
**Observation:** "OCR Done status only updates after the whole thing completes."
**Cause:** If `setState` is only called at the end of the batch loop in `GalleryScreen`, the UI won't reflect individual row updates until the loop finishes.
**Solution:** The database updates fine, but the UI (Gallery) needs to listen to a stream or refresh periodically to show live updates.

### Issue D: Performance Logging
**Requirement:** "Time spent logs for OCR process."
**Solution:** Implement `Stopwatch`:
*   Track total batch time.
*   Track individual image OCR time.
*   Log average time per image.

---

## 3. Implementation Plan

### Step 1: Fix DatabaseHelper
*   Restore `close()`.

### Step 2: Implement Background Isolate for OCR
*   Refactor `ProcessingPipeline` to use `compute()` or `Isolate.run()` for the heavy lifting of OCR.
*   *Note: usage of Platform Channels (ML Kit) in Isolates has limitations in older Flutter versions but is better in newer ones. If ML Kit requires main thread, we must throttle the loop (e.g., process 1, wait 50ms) to unblock UI.*
*   **Alternative:** Since `google_mlkit_text_recognition` uses platform channels, it might handle threading natively, but our *loop* is on the main thread. We should add `await Future.delayed(Duration.zero)` or a small delay between items to yield control to the UI.

### Step 3: Add Logging & Metrics
*   Add `Stopwatch` to `processAssets`.
*   Print `[Performance] Image 5/100: 350ms`.

### Step 4: UI Progress Indicator
*   Add a `ProcessingStatusNotifier` singleton.
*   Gallery listens to it and displays a progress bar.

---

## 4. User Verification
Please review this plan. If approved, I will proceed with:
1.  Restoring `close()`.
2.  Adding the Logging/Stopwatch.
3.  optimizing the Loop (Isolate or Throttling).
4.  Adding the Progress Bar.
