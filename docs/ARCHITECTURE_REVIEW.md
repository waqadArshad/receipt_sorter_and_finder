# 📋 Architecture Review: Receipt Sorter & Finder

## 1. High-Level Assessment

| Aspect | Rating |
|--------|--------|
| **Overall Quality** | **Strong** |
| **Implementation Readiness** | **Medium-High** (some gaps need addressing) |
| **Technical Depth** | Excellent |

### Strengths
- ✅ Well-documented on-device processing strategy (zero image upload)
- ✅ Comprehensive database schema with proper indexing
- ✅ Excellent rate limit management with batching strategy
- ✅ Clear parallel processing pipeline design
- ✅ Realistic cost analysis and timeline expectations
- ✅ Good error handling patterns

### Main Risks If Implemented As-Is

> [!CAUTION]
> **Critical Implementation Risks:**
> 1. **Perceptual hash library uncertainty** - `image_hash` package may not exist or behave as described
> 2. **No offline-first classification fallback** - App is unusable without network
> 3. **Background processing on iOS is severely limited** - Platform constraints not addressed
> 4. **No explicit state machine** for processing lifecycle - Edge cases will be missed
> 5. **FTS5 setup complexity** - Not natively supported by sqflite without FFI

---

## 2. Critical Gaps & Risks

### 2.1 Missing Components

| Gap | Impact | Priority |
|-----|--------|----------|
| **Offline classification fallback** | App unusable offline | High |
| **iOS background processing limits** | 30s max background time | High |
| **Perceptual hash package validation** | Core feature may not work | High |
| **Cancellation token propagation** | Can't cleanly stop operations | Medium |
| **FTS5 integration approach** | Search won't work as designed | Medium |
| **Multi-user support considerations** | Device sharing breaks data | Low |

### 2.2 Wrong Assumptions

1. **`image_hash` Dart package** - No such package exists on pub.dev with the described API. You likely need:
   - `phash` package (limited)
   - Native FFI to a C/C++ library like pHash
   - Or implement dHash/aHash manually

2. **Background isolate with database access** - SQLite isn't inherently isolate-safe; requires careful setup with `sqflite` or `drift`

3. **50 documents per batch classification** - This may exceed DeepSeek R1's context window depending on OCR text length. Average receipt = 500-1000 chars, 50 receipts = 25-50K chars. **Context limit risk.**

4. **FTS5 virtual table** - `sqflite` package does NOT support FTS5 out of the box. Requires `sqflite_ffi` or `drift` with native extensions.

### 2.3 Hidden Complexity

| Area | Hidden Issue |
|------|--------------|
| **Gallery access** | Android 13+ scoped storage changes; iOS requires PHPhotoLibrary authorization |
| **File path stability** | `file_path` can become stale after gallery cleanup/Android file manager |
| **Rate limit persistence** | Rate limiter state lost on app restart - need SQLite-backed tracking |
| **Batch result matching** | LLM may return results in different order or skip documents |
| **Memory pressure** | Loading 10K hashes into memory = ~640KB minimum, but hash check + image decode can spike |

### 2.4 Scaling Concerns

1. **SQLite performance at 100K+ rows** - Need explicit VACUUM scheduling and WAL mode
2. **Server sync bottleneck** - Batched sync of 50 records per request, but no deduplication on server side
3. **Classification queue persistence** - Queue is in-memory; lost on crash

### 2.5 Security & Privacy Gaps

| Issue | Risk Level |
|-------|------------|
| API key in Serverpod environment | Medium - Needs secrets management |
| OCR text sent to server | Low - But receipts contain PII |
| No data retention policy | Medium - Compliance risk |
| Session token storage | Needs secure storage (flutter_secure_storage) |

---

## 3. Section-by-Section Improvements

### Core Principles ✅ **Strong**
- What's good: Clear zero-upload philosophy is correct
- **Add**: Define explicit privacy policy for OCR text handling

---

### System Architecture ✅ **Good**
- What's good: Clear component diagram
- **Change**: Classification should happen on Serverpod, not client calling OpenRouter directly (keeps API key secure)
- **Add**: Mermaid sequence diagram for the happy path

---

### Already-Processed Detection ⚠️ **Needs Work**

**Issues:**
- `image_hash` package doesn't exist with this API
- Hybrid approach logic has race condition (check metadata → compute perceptual → insert, but another process could insert between check and insert)

**Recommended Implementation:**
```dart
// Use a real package like phash or implement dHash:
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

Future<String> computeDHash(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final image = img.decodeImage(bytes)!;
  
  // Resize to 9x8 grayscale
  final resized = img.copyResize(image, width: 9, height: 8);
  final grayscale = img.grayscale(resized);
  
  // Compare adjacent pixels
  final hash = StringBuffer();
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      final pixel = grayscale.getPixel(x, y);
      final nextPixel = grayscale.getPixel(x + 1, y);
      hash.write(img.getLuminance(pixel) > img.getLuminance(nextPixel) ? '1' : '0');
    }
  }
  
  return BigInt.parse(hash.toString(), radix: 2).toRadixString(16).padLeft(16, '0');
}
```

---

### Data Flow / Parallel Processing ✅ **Strong**
- What's good: Excellent separation of OCR and classification pipelines
- **Change**: Add explicit cancellation support
- **Add**: State machine for image processing states:
  ```
  PENDING → HASHING → OCR_IN_PROGRESS → OCR_COMPLETE → 
  CLASSIFICATION_QUEUED → CLASSIFICATION_IN_PROGRESS → 
  CLASSIFICATION_COMPLETE → SYNCED
  ```

---

### Local Database Schema ✅ **Good**

**Issues:**
- `UNIQUE(perceptual_hash)` constraint is too strict - near-duplicate images should be allowed
- Missing `processing_status` column for state machine
- Missing `content_uri` and `asset_id` columns mentioned in albums section

**Add these columns:**
```sql
ALTER TABLE processed_images ADD COLUMN content_uri TEXT;
ALTER TABLE processed_images ADD COLUMN asset_id TEXT;
ALTER TABLE processed_images ADD COLUMN is_deleted INTEGER DEFAULT 0;
ALTER TABLE processed_images ADD COLUMN processing_status TEXT DEFAULT 'pending';
```

**Remove:**
```sql
-- Remove this constraint:
UNIQUE(perceptual_hash)  -- Near-duplicates are valid
```

---

### Albums & In-App Browsing ✅ **Good**
- What's good: Smart approach using queries instead of copies
- **Add**: Explicit cache invalidation strategy when classifications change

---

### Gallery Processing Flow ⚠️ **Needs Work**

**iOS Background Limits:**
```dart
// iOS only allows ~30 seconds of background time
// Need to use BGTaskScheduler for longer processing

class IOSBackgroundProcessor {
  static void registerBackgroundTasks() {
    // Register with system
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: 'com.app.processImages',
      using: nil,
      launchHandler: handleBackgroundTask,
    );
  }
  
  static void handleBackgroundTask(BGTask task) {
    // Process only 5-10 images per background session
    // Schedule continuation task before expiration
  }
}
```

**Add**: Explicit handling for:
- App going to background mid-processing
- App killed during processing
- Resume logic on cold start

---

### Batch Classification ⚠️ **Critical Fix Needed**

**Context Window Risk:**
- DeepSeek R1 has ~32K-64K context window
- 50 receipts × 1000 chars average = 50K chars input + response
- **Reduce batch size to 20-30 for safety**

**Result Matching Issue:**
LLMs may skip documents or return in different order. Current code assumes 1:1 order:
```dart
// Current (fragile):
for (var i = 0; i < resultsList.length; i++) {
  results.add(ClassificationResult.fromJson(resultsList[i]));
}

// Fixed (robust):
Map<String, ClassificationResult> resultMap = {};
for (final result in resultsList) {
  resultMap[result['hash']] = ClassificationResult.fromJson(result);
}

for (final task in batch) {
  final result = resultMap[task.hash];
  if (result != null) {
    await db.updateClassificationResult(task.hash, result);
  } else {
    // Re-queue for retry
    await _queue.enqueue(task, priority: 2);
  }
}
```

---

### Error Handling ✅ **Good**
- What's good: Comprehensive error categories
- **Add**: Circuit breaker pattern for API calls
- **Add**: Error reporting/logging service integration (Sentry, Firebase Crashlytics)

---

### Sync Strategy ⚠️ **Needs Work**

**Issues:**
- No idempotency key for syncs - retry may cause duplicates
- Server schema doesn't show device_id - can't properly track multiple devices

**Add to sync request:**
```dart
class SyncRequest {
  final String deviceId;           // NEW
  final String idempotencyKey;     // NEW - UUID per sync attempt
  final List<ProcessedImageData> images;
  final DateTime? lastSyncTimestamp;
}
```

---

### Testing Strategy ⚠️ **Weak**

**What's missing:**
- No test commands specified
- No test file locations
- No mock strategy for OpenRouter API
- No integration test setup

**Should add:**
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# Golden tests for UI
flutter test --update-goldens
```

---

### Implementation Checklist ✅ **Good**
- What's good: Clear phases with realistic timeline
- **Change**: Week 1 should include package validation spike
- **Add**: "Week 0: Technical spikes for risky dependencies"

---

## 4. Implementation Readiness Checklist

### ✅ Ready to Implement Now
- [ ] Core database schema (with fixes noted above)
- [ ] OCR integration with Google ML Kit
- [ ] Metadata hash generation
- [ ] Processing queue system
- [ ] Basic UI structure
- [ ] Serverpod schema and endpoints

### ⚠️ Decisions Still Needed
1. **Perceptual hash implementation**: Use `image` package + manual dHash, or FFI?
2. **FTS5 approach**: Use `drift` with FFI, or fall back to LIKE queries?
3. **Batch size**: Test with real data to determine safe batch size (20-30 recommended)
4. **Offline handling**: Queue-only mode, or attempt local classification with smaller model?
5. **iOS background strategy**: BGTaskScheduler or foreground-only processing?

### 🔬 Should Prototype/Validate First
1. **Perceptual hash accuracy** - Test with 100 real receipts for false positive rate
2. **Batch classification** - Test with 20, 30, 50 documents to find context limit
3. **Gallery access** - Test on Android 13+ and iOS 17+ for scoped storage behavior
4. **Background processing** - Test iOS background time limits
5. **Rate limit persistence** - Verify rate limiter survives app restart

---

## 5. Suggested Next Steps

### Week 0: Technical Spikes (Before Main Development)
```
Priority Order:
1. Validate perceptual hash approach (2 days)
   - Implement dHash manually with `image` package
   - Test with 100 sample receipts
   - Measure false positive rate

2. Test batch classification limits (1 day)
   - Call DeepSeek R1 with 20, 30, 50 sample OCR texts
   - Measure response quality and errors

3. Validate FTS5/search approach (1 day)
   - Try sqflite_ffi or drift
   - Fall back to LIKE queries if needed

4. Test gallery access on modern OS (1 day)
   - Android 13+ scoped storage
   - iOS PHPhotoLibrary access
```

### Week 1-2: Foundation (With Validated Approach)
```
- Set up Flutter project
- Implement validated hash approach
- Set up SQLite with drift (for better FTS support)
- Implement OCR with ML Kit
- Build processing state machine
```

### Week 3-4: Core Processing
```
- Parallel pipeline with cancellation
- Classification queue with persistence
- Rate limit manager with SQLite backing
- Platform-specific background processing
```

### Week 5: Serverpod & Sync
```
- Deploy Serverpod
- Implement classification endpoint
- Build sync with idempotency
- Add search functionality
```

### Week 6: Polish & Testing
```
- Error handling refinement
- Performance testing at scale
- UI/UX polish
- Documentation
```

---

## 6. Refined Architecture Decisions

Based on the review, here are the **explicit decisions** you should make:

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| Hash library | **Implement dHash manually** | No reliable Dart package exists |
| Database ORM | **Use Drift instead of raw sqflite** | Better FTS support, type safety |
| Batch size | **25 documents max** | Context window safety margin |
| Background processing | **Foreground-only on iOS** | iOS limits too restrictive |
| Offline mode | **Queue OCR, defer classification** | Better than failing |
| Search | **Use Drift FTS5 or fall back to LIKE** | FTS5 requires native extensions |
| Rate limit storage | **SQLite-backed** | Survive app restart |

---

> [!IMPORTANT]
> The architecture is fundamentally sound and well-thought-out. The main risks are unvalidated third-party dependencies and platform-specific edge cases. A 5-day spike before main development will save weeks of debugging later.
