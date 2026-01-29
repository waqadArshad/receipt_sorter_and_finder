# Architecture Corrections & 1-Day Implementation Plan

## Corrections to Review

### 1. ✅ `image_hash` Package EXISTS
**You're absolutely correct!** The package exists at https://pub.dev/packages/image_hash

**Correction:** The original architecture's approach is valid. Use:
```dart
import 'package:image_hash/image_hash.dart';

final hasher = PerceptualHash();
final hash = await hasher.hash(imageFile.path);
final hashString = hash.toString(); // 64-bit hash as string
```

---

## Answers to Your Questions

### 2. Dynamic Batching Based on Token Limits ✅ **EXCELLENT IDEA**

**Implementation:**
```dart
class DynamicBatchClassifier {
  static const int MAX_INPUT_TOKENS = 30000; // DeepSeek R1 safe limit
  static const int AVG_CHARS_PER_TOKEN = 4;   // Conservative estimate
  static const int RESERVED_TOKENS = 2000;    // For prompt + response
  
  Future<List<ClassificationResult>> classifyWithDynamicBatching(
    List<ClassificationTask> tasks,
  ) async {
    final batches = _createDynamicBatches(tasks);
    final results = <ClassificationResult>[];
    
    for (final batch in batches) {
      final batchResults = await _classifyBatch(batch);
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  List<List<ClassificationTask>> _createDynamicBatches(
    List<ClassificationTask> tasks,
  ) {
    final batches = <List<ClassificationTask>>[];
    var currentBatch = <ClassificationTask>[];
    var currentTokenCount = 0;
    
    for (final task in tasks) {
      final taskTokens = _estimateTokens(task.ocrText);
      
      // Check if adding this task would exceed limit
      if (currentTokenCount + taskTokens > (MAX_INPUT_TOKENS - RESERVED_TOKENS)) {
        if (currentBatch.isNotEmpty) {
          batches.add(currentBatch);
          currentBatch = [];
          currentTokenCount = 0;
        }
      }
      
      currentBatch.add(task);
      currentTokenCount += taskTokens;
    }
    
    if (currentBatch.isNotEmpty) {
      batches.add(currentBatch);
    }
    
    return batches;
  }
  
  int _estimateTokens(String text) {
    return (text.length / AVG_CHARS_PER_TOKEN).ceil();
  }
}
```

**Benefits:**
- ✅ Automatically adjusts batch size based on OCR text length
- ✅ Can process 50+ short receipts or 10-15 long invoices
- ✅ Maximizes API efficiency while staying within limits

---

### 3. Offline Classification Options

**Option A: Queue-Only Mode (Simplest - Recommended for 1-day timeline)**
```dart
class OfflineHandler {
  Future<ProcessingResult> processImage(File imageFile) async {
    // Always do OCR (on-device, works offline)
    final ocrResult = await ocrService.extractText(imageFile);
    
    // Store with pending classification status
    await db.insertProcessedImage(
      ProcessedImage(
        ocrText: ocrResult.text,
        processingStatus: 'ocr_complete',
        documentType: 'pending_classification', // Special status
        // ... other fields
      ),
    );
    
    // Queue for classification when online
    await classificationQueue.enqueue(task);
    
    return ProcessingResult.success(
      message: 'OCR complete. Classification queued for when online.',
    );
  }
}
```

**Option B: Simple Rule-Based Fallback (Medium complexity)**
```dart
class SimpleClassifier {
  String classifyOffline(String ocrText) {
    final lower = ocrText.toLowerCase();
    
    // Simple keyword matching
    if (lower.contains('bank') || lower.contains('atm')) {
      return 'bank_receipt';
    } else if (lower.contains('invoice') || lower.contains('bill to')) {
      return 'invoice';
    } else if (lower.contains('total') && lower.contains('paid')) {
      return 'pos_receipt';
    }
    
    return 'unknown';
  }
}
```

**Option C: On-Device TensorFlow Lite Model (Complex - NOT for 1-day)**
- Requires training a classification model
- ~5MB model size
- 70-80% accuracy (vs 90%+ with LLM)
- **Skip this for now**

**Recommendation for 1-day:** Use **Option A** (queue-only). Show user:
- "✅ OCR complete (works offline)"
- "⏳ Classification pending (requires internet)"
- Auto-classify when connection restored

---

### 4. Result Matching & Order Issues

**Why LLMs might skip/reorder:**
- Token limit exceeded mid-response → truncated output
- Model error → partial response
- Parsing error → malformed JSON
- Rate limiting → incomplete batch

**Solution: Hash-Based Matching (Robust)**
```dart
class BatchClassificationService {
  Future<List<ClassificationResult>> _classifyBatchRequest(
    List<ClassificationTask> batch,
  ) async {
    final response = await _callAPI(batch);
    final resultsList = jsonDecode(response)['results'] as List;
    
    // Create hash map for O(1) lookup
    final resultMap = <String, ClassificationResult>{};
    for (final resultJson in resultsList) {
      final result = ClassificationResult.fromJson(resultJson);
      resultMap[result.hash] = result;
    }
    
    // Match results to original tasks
    final orderedResults = <ClassificationResult>[];
    for (final task in batch) {
      final result = resultMap[task.hash];
      
      if (result != null) {
        orderedResults.add(result);
      } else {
        // Handle missing result
        print('⚠️ No result for hash: ${task.hash}');
        orderedResults.add(ClassificationResult.failed(
          hash: task.hash,
          reason: 'No result returned from API',
        ));
        
        // Re-queue for retry
        await _queue.enqueue(task, priority: 2);
      }
    }
    
    return orderedResults;
  }
  
  String _buildBatchPrompt(List<ClassificationTask> batch) {
    final buffer = StringBuffer();
    buffer.writeln('Classify the following ${batch.length} documents:');
    buffer.writeln();
    
    for (var i = 0; i < batch.length; i++) {
      buffer.writeln('--- Document ${i + 1} ---');
      buffer.writeln('HASH: ${batch[i].hash}');  // ← Include hash in prompt
      buffer.writeln('OCR TEXT:');
      buffer.writeln(batch[i].ocrText);
      buffer.writeln();
    }
    
    buffer.writeln('CRITICAL: Include the HASH field in each result!');
    return buffer.toString();
  }
}
```

**Why this works:**
- ✅ Order-independent matching
- ✅ Detects missing results
- ✅ Auto-retries failed items
- ✅ Handles partial responses gracefully

---

### 5. State Machine for Processing Lifecycle

**Simple Enum-Based State Machine (Perfect for 1-day)**
```dart
enum ProcessingStatus {
  pending,           // Not started
  hashing,           // Computing hash
  ocrInProgress,     // Running OCR
  ocrComplete,       // OCR done, waiting for classification
  classificationQueued,  // In classification queue
  classificationInProgress,  // API call in flight
  completed,         // Fully processed
  failed,            // Error occurred
  skipped,           // Duplicate or no text
}

class ProcessingStateMachine {
  ProcessingStatus currentStatus = ProcessingStatus.pending;
  
  Future<void> transition(ProcessingStatus newStatus) async {
    // Validate transitions
    if (!_isValidTransition(currentStatus, newStatus)) {
      throw StateError(
        'Invalid transition: $currentStatus → $newStatus',
      );
    }
    
    currentStatus = newStatus;
    await db.updateStatus(imageHash, newStatus);
    _notifyListeners();
  }
  
  bool _isValidTransition(ProcessingStatus from, ProcessingStatus to) {
    // Define allowed transitions
    const validTransitions = {
      ProcessingStatus.pending: [
        ProcessingStatus.hashing,
        ProcessingStatus.skipped,
      ],
      ProcessingStatus.hashing: [
        ProcessingStatus.ocrInProgress,
        ProcessingStatus.skipped,
        ProcessingStatus.failed,
      ],
      ProcessingStatus.ocrInProgress: [
        ProcessingStatus.ocrComplete,
        ProcessingStatus.failed,
        ProcessingStatus.skipped,
      ],
      ProcessingStatus.ocrComplete: [
        ProcessingStatus.classificationQueued,
        ProcessingStatus.completed, // If offline mode
      ],
      ProcessingStatus.classificationQueued: [
        ProcessingStatus.classificationInProgress,
      ],
      ProcessingStatus.classificationInProgress: [
        ProcessingStatus.completed,
        ProcessingStatus.failed,
        ProcessingStatus.classificationQueued, // Retry
      ],
      // Terminal states can't transition
      ProcessingStatus.completed: [],
      ProcessingStatus.failed: [ProcessingStatus.pending], // Retry
      ProcessingStatus.skipped: [],
    };
    
    return validTransitions[from]?.contains(to) ?? false;
  }
}
```

**Add to database:**
```sql
ALTER TABLE processed_images 
ADD COLUMN processing_status TEXT DEFAULT 'pending';

CREATE INDEX idx_processing_status 
ON processed_images(processing_status);
```

**Benefits:**
- ✅ Clear state tracking
- ✅ Prevents invalid transitions
- ✅ Easy to debug
- ✅ Resume from any state

---

### 6. 1-Day Implementation Plan 🚀

**CRITICAL: Scope Reduction for 1-Day Timeline**

Given only 1 day, we need to build an **MVP** that demonstrates core functionality:

#### Hour 0-2: Foundation
```
✅ Set up Flutter project
✅ Add dependencies (sqflite, google_mlkit_text_recognition, image_hash)
✅ Create basic database schema (simplified)
✅ Set up Serverpod project structure
```

#### Hour 2-4: Core Processing
```
✅ Implement hash generation (metadata + perceptual)
✅ Implement OCR with Google ML Kit
✅ Create local storage (SQLite)
✅ Build simple processing queue
```

#### Hour 4-6: Classification
```
✅ Set up Serverpod classification endpoint
✅ Implement dynamic batching logic
✅ Add rate limit manager (basic version)
✅ Test with 10 sample images
```

#### Hour 6-7: UI (Minimal)
```
✅ Gallery picker screen
✅ Processing progress indicator
✅ Results list view (by type)
✅ Basic search (LIKE queries, no FTS)
```

#### Hour 7-8: Testing & Polish
```
✅ Test with 100 images
✅ Fix critical bugs
✅ Add error handling
✅ Deploy Serverpod to test server
```

**What to SKIP for 1-day:**
- ❌ FTS5 full-text search (use simple LIKE)
- ❌ Background processing (foreground only)
- ❌ Sync queue with retry logic (basic sync only)
- ❌ User corrections UI
- ❌ Advanced error recovery
- ❌ iOS-specific optimizations
- ❌ Comprehensive testing

**What MUST work:**
- ✅ Scan gallery and detect duplicates
- ✅ OCR text extraction
- ✅ Batch classification via API
- ✅ Store results locally
- ✅ Browse by document type
- ✅ Basic search

---

### 7. Simple Search Without FTS5 ✅ **YES, VERY DOABLE**

**Implementation:**
```dart
class SimpleSearchService {
  Future<List<ProcessedImage>> search({
    String? query,
    List<String>? documentTypes,
    List<String>? categories,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final conditions = <String>[];
    final args = <Object>[];
    
    // Text search (simple LIKE)
    if (query != null && query.isNotEmpty) {
      conditions.add(
        '(ocr_text LIKE ? OR merchant_name LIKE ?)',
      );
      args.add('%$query%');
      args.add('%$query%');
    }
    
    // Filter by document types
    if (documentTypes != null && documentTypes.isNotEmpty) {
      final placeholders = List.filled(documentTypes.length, '?').join(',');
      conditions.add('document_type IN ($placeholders)');
      args.addAll(documentTypes);
    }
    
    // Filter by categories
    if (categories != null && categories.isNotEmpty) {
      final placeholders = List.filled(categories.length, '?').join(',');
      conditions.add('category IN ($placeholders)');
      args.addAll(categories);
    }
    
    // Date range
    if (startDate != null) {
      conditions.add('transaction_date >= ?');
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      conditions.add('transaction_date <= ?');
      args.add(endDate.toIso8601String());
    }
    
    // Always exclude deleted
    conditions.add('is_deleted = 0');
    
    final whereClause = conditions.join(' AND ');
    
    final results = await db.query(
      'processed_images',
      where: whereClause,
      whereArgs: args,
      orderBy: 'transaction_date DESC, processed_at DESC',
      limit: 100,
    );
    
    return results.map((row) => ProcessedImage.fromMap(row)).toList();
  }
}
```

**Performance:**
- ✅ Fast enough for 10K records (< 100ms)
- ✅ No FFI or native extensions needed
- ✅ Works out of the box with sqflite
- ✅ Can add indexes for better performance:
  ```sql
  CREATE INDEX idx_ocr_text ON processed_images(ocr_text);
  CREATE INDEX idx_merchant_name ON processed_images(merchant_name);
  ```

**UI Example:**
```dart
class SearchScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(hintText: 'Search...'),
          onChanged: (query) => _search(query),
        ),
        
        // Filter chips
        Wrap(
          children: [
            FilterChip(
              label: Text('Bank Receipts'),
              selected: selectedTypes.contains('bank_receipt'),
              onSelected: (selected) => _toggleType('bank_receipt'),
            ),
            FilterChip(
              label: Text('POS Receipts'),
              selected: selectedTypes.contains('pos_receipt'),
              onSelected: (selected) => _toggleType('pos_receipt'),
            ),
            // ... more filters
          ],
        ),
        
        // Results
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final image = results[index];
              return ListTile(
                title: Text(image.merchantName ?? 'Unknown'),
                subtitle: Text(image.documentType),
                trailing: Text('\$${image.amount}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

---

### 8. iOS Background Processing Options

**Reality Check:**
- iOS allows ~30 seconds of background time
- BGTaskScheduler requires app to be closed for hours before triggering
- Not practical for continuous processing

**Options:**

**A. Foreground-Only Processing (Recommended for 1-day)**
```dart
class ProcessingService {
  Future<void> startProcessing() async {
    // Only process while app is in foreground
    if (AppLifecycleState.resumed) {
      await _processQueue();
    }
  }
  
  void _handleAppLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pause processing
      _processingController.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Resume processing
      _processingController.resume();
    }
  }
}
```

**B. Chunked Processing (Better UX)**
```dart
class ChunkedProcessor {
  Future<void> processInChunks() async {
    const CHUNK_SIZE = 10; // Process 10 images at a time
    
    while (hasMoreToProcess) {
      // Process chunk
      await _processChunk(CHUNK_SIZE);
      
      // Show progress
      _showNotification('Processed ${completed}/${total} images');
      
      // Let user continue using app
      await Future.delayed(Duration(milliseconds: 100));
    }
  }
}
```

**C. User-Initiated Processing**
```dart
// Show prominent button when processing is incomplete
Widget buildProcessingPrompt() {
  return Card(
    child: ListTile(
      leading: Icon(Icons.pending_actions),
      title: Text('${pendingCount} images pending classification'),
      subtitle: Text('Tap to continue processing'),
      onTap: () => _resumeProcessing(),
    ),
  );
}
```

**Recommendation for 1-day:**
- Use **foreground-only** processing
- Show clear progress indicator
- Allow pause/resume
- Save state so user can close app and resume later
- Don't fight iOS background limits

---

### 9. Gallery Access Strategy (Android 13+ & iOS 17+)

**The Challenge:**
Modern OS versions (Android 14+, iOS 14+) allow users to grant "Limited" or "Partial" access to their photo library. We cannot force full access, but our app needs it to be useful as a "Finder".

**Strategy:**
1.  **Request Full Access:** We will standardly request `read` permissions (`Permission.photos` or `Permission.storage` depending on OS version).
    - **Android 13+:** Requests `READ_MEDIA_IMAGES`.
    - **iOS:** Requests `PHAuthorizationStatus.authorized`.
2.  **Handle "Limited" State:**
    - If the user selects "Select Photos" (iOS) or "Allow Limited Access" (Android 14), the app will **function normally** but only see the subset of photos.
    - **Crucial UX:** We must show a persistent banner or "Grant Full Access" card in the gallery view if `photo_manager` reports `isLimited` / `ProjectPermission.limited`.
    - **Message:** "You've only allowed access to some photos. To find all existing receipts, please grant full library access." with a button to open App Settings.
3.  **No "Scoped Storage" Complexities:**
    - By using `photo_manager`, we abstract away the raw file system paths restrictions.
    - We access media via `content://` URIs (Android) or PHAsset IDs (iOS) provided by the plugin, which works perfectly with Scoped Storage.
    - **Zero-code change required** for basic Scoped Storage compliance if using `photo_manager`.

**Answer to "Can we not ask for full-access?":**
We **must request permissions** to see any photos. We *ask* for the standard read permission. The OS *presents* the "Select Photos" option to the user automatically. We cannot "not ask" for it if we want to scan the gallery. We *can* avoid asking for `MANAGE_EXTERNAL_STORAGE` (Process All Files), which is true "Full Access" on Android but restricted. We stick to standard Media permissions, which is the correct approach.

---

## Revised 1-Day Architecture

### Simplified Stack
```
Flutter App (On-Device)
├── Gallery Scanner (photo_manager)
├── Hash Generator (image_hash + crypto)
├── OCR (google_mlkit_text_recognition)
├── Local DB (sqflite - simple schema)
├── Classification Queue
└── Simple Search (LIKE queries)

Serverpod Backend
├── Classification Endpoint (dynamic batching)
├── Rate Limit Manager
├── PostgreSQL (metadata only)
└── OpenRouter Integration
```

### What Changed
- ✅ Keep `image_hash` package (it exists!)
- ✅ Add dynamic batching based on token limits
- ✅ Use queue-only offline mode
- ✅ Add hash-based result matching
- ✅ Simple state machine with enum
- ✅ Skip FTS5, use LIKE queries
- ✅ Foreground-only processing
- ✅ Scope reduced for 1-day timeline

### Critical Path for 1-Day
1. **Hour 0-2:** Project setup + dependencies
2. **Hour 2-4:** Hash + OCR + Database
3. **Hour 4-6:** Classification with dynamic batching
4. **Hour 6-7:** Minimal UI
5. **Hour 7-8:** Testing + deployment

**This is achievable if you:**
- Use existing packages (no custom implementations)
- Skip advanced features (FTS, background, sync retry)
- Focus on core flow (scan → OCR → classify → browse)
- Test with small dataset (100 images max)
