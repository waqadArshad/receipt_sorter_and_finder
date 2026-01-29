# 📐 Receipt Sorter & Finder - Architecture & Design Document

## Overview

This document outlines the complete architecture for a **zero-cost, zero-bandwidth** screenshot classification and OCR system. The system processes images entirely on-device, only sending minimal metadata to the server, making it scalable to handle 10,000+ images efficiently.

---

## Table of Contents

1. [Core Principles](#core-principles)
2. [System Architecture](#system-architecture)
3. [Already-Processed Detection](#already-processed-detection)
4. [Data Flow](#data-flow)
5. [Local Database Schema](#local-database-schema)
6. [Albums & In-App Browsing by Type](#albums--in-app-browsing-by-type)
7. [Gallery Processing Flow](#gallery-processing-flow)
8. [Bandwidth Analysis](#bandwidth-analysis)
9. [Serverpod Backend](#serverpod-backend)
10. [Authentication & User Management](#authentication--user-management)
11. [API Contracts (Flutter ↔ Serverpod)](#api-contracts-flutter--serverpod)
12. [Search Functionality](#search-functionality)
13. [Error Handling Strategy](#error-handling-strategy)
14. [Sync Strategy](#sync-strategy)
15. [Deployment & Environment Setup](#deployment--environment-setup)
16. [Complete Batch Classification Prompt](#complete-batch-classification-prompt)
17. [Testing Strategy](#testing-strategy)
18. [Cost Analysis](#cost-analysis)
19. [Performance Optimizations](#performance-optimizations)
20. [Implementation Checklist](#implementation-checklist)
21. [Key Metrics & Targets](#key-metrics--targets)
22. [Security & Privacy](#security--privacy)
23. [Future Enhancements](#future-enhancements)

---

## Core Principles

### 1. **Never Upload Images**
- All OCR processing happens **on-device**
- Only OCR text (~5-10 KB) is sent to server
- Images remain on device (privacy + bandwidth savings)

### 2. **Zero Server Processing**
- Serverpod stores metadata only
- No image processing on server
- No Python scripts or external dependencies

### 3. **Smart Duplicate Detection**
- Hash-based detection of already-processed images
- Fast in-memory lookups
- Skip processing for duplicates

### 4. **Incremental Processing**
- Process only new/unprocessed images
- Resume from last checkpoint
- Background processing with progress tracking

---

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Flutter App (On-Device)                                 │
│  ┌───────────────────────────────────────────────────┐  │
│  │  1. Image Hash Generation (Perceptual/Metadata)   │  │
│  │     ↓                                             │  │
│  │  2. Check Local Database (Already Processed?)    │  │
│  │     ↓                                             │  │
│  │  3. OCR Processing (Google ML Kit - On-Device)   │  │
│  │     ↓                                             │  │
│  │  4. Classification (DeepSeek R1 via OpenRouter)  │  │
│  │     ↓                                             │  │
│  │  5. Local Storage (SQLite)                        │  │
│  │     ↓                                             │  │
│  │  6. Sync Metadata to Serverpod (OCR text only)   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                        │
                        │ Only OCR text + hash (~5-10 KB)
                        │ (No images uploaded)
                        ▼
┌─────────────────────────────────────────────────────────┐
│  Serverpod Backend                                       │
│  ┌───────────────────────────────────────────────────┐  │
│  │  PostgreSQL Database                               │  │
│  │  - Image hash (unique identifier)                  │  │
│  │  - OCR text                                        │  │
│  │  - Classification result                            │  │
│  │  - Extracted fields (merchant, amount, date, etc) │  │
│  │  - Metadata (file path, size, modified date)      │  │
│  │  - Timestamps                                      │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  OpenRouter API Integration                        │  │
│  │  - DeepSeek R1 0528 (free) classification        │  │
│  │  - Rate limit management                           │  │
│  │  - Queue system                                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### **Client-Side (Flutter)**
- **Image Hash Generator**: Creates unique identifiers for images
- **Local Database (SQLite)**: Stores processed image metadata
- **OCR Engine (Google ML Kit)**: On-device text extraction
- **Classification Client**: Sends OCR text to Serverpod for classification
- **Gallery Scanner**: Scans device gallery and queues unprocessed images
- **Progress Tracker**: Shows processing status and allows pause/resume

#### **Server-Side (Serverpod)**
- **Metadata Storage**: Stores OCR text and classification results
- **Classification Service**: Calls OpenRouter API (DeepSeek R1)
- **Rate Limit Manager**: Handles API rate limits and queuing
- **Search/Query API**: Enables searching across processed images
- **Sync Service**: Syncs metadata from client to server

---

## Already-Processed Detection

### Problem Statement

When processing 10,000+ images, we need to:
- **Skip images already processed** (avoid duplicate work)
- **Detect duplicates** even if file moved/renamed
- **Handle image modifications** (compression, resizing)
- **Fast lookup** (milliseconds, not seconds)

### Method 1: Perceptual Hash (Recommended)

**Why Perceptual Hash?**
- Detects duplicates even if file moved/renamed
- Handles minor edits (compression, resizing, format conversion)
- Fast comparison (64-bit hash)
- Industry standard (used by Google Photos, Dropbox, etc.)

**Implementation:**
```dart
import 'package:image_hash/image_hash.dart';
import 'dart:io';

Future<String> generatePerceptualHash(File imageFile) async {
  final hash = await ImageHash.computeHash(imageFile);
  return hash.toHexString(); // Returns 64-character hex string
}

// Check if already processed
Future<bool> isAlreadyProcessed(String hash) async {
  final result = await db.query(
    'processed_images',
    where: 'hash = ?',
    whereArgs: [hash],
    limit: 1,
  );
  return result.isNotEmpty;
}
```

**Pros:**
- Handles image modifications
- Detects visual duplicates
- Works across file formats

**Cons:**
- Requires image decoding (10-50ms per image)
- May have false positives for very similar images

**Performance:**
- **Per image:** 10-50ms (depends on image size and device)
- **10,000 images:** ~100-500 seconds (1.5-8 minutes)
- **Bottleneck:** Image decoding and processing (not the hash algorithm itself)

### Method 2: File Metadata Hash (Faster Alternative)

**Why Metadata Hash?**
- Extremely fast (no image decoding)
- Perfect for exact file duplicates
- Works even if image not loaded into memory

**Implementation:**
```dart
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:convert';

Future<String> generateMetadataHash(File imageFile) async {
  final stat = await imageFile.stat();
  final hashInput = '${imageFile.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
  final hash = sha256.convert(utf8.encode(hashInput)).toString();
  return hash;
}
```

**Pros:**
- Instant (no image processing)
- Perfect for exact duplicates
- Very low CPU usage

**Cons:**
- Doesn't detect modified images
- Fails if file moved (path changes)

**Performance:**
- **Per image:** < 1ms (essentially instant)
- **10,000 images:** ~5-10 seconds total
- **Bottleneck:** File system I/O (reading file metadata)
- **Speed advantage:** 10-50x faster than perceptual hash

### Method 3: Hybrid Approach (Best Performance)

**Combine Both Methods:**
1. **Fast Check**: Use metadata hash for instant duplicate detection
2. **Deep Check**: Use perceptual hash for visual duplicates
3. **Store Both**: Store both hashes in database for maximum flexibility

**Implementation:**
```dart
class ImageHashService {
  Future<ImageHashes> generateHashes(File imageFile) async {
    // Fast metadata hash
    final metadataHash = await generateMetadataHash(imageFile);
    
    // Perceptual hash (only if needed)
    final perceptualHash = await generatePerceptualHash(imageFile);
    
    return ImageHashes(
      metadataHash: metadataHash,
      perceptualHash: perceptualHash,
    );
  }
  
  Future<bool> isAlreadyProcessed(ImageHashes hashes) async {
    // Fast check: metadata hash
    final metadataMatch = await db.query(
      'processed_images',
      where: 'metadata_hash = ?',
      whereArgs: [hashes.metadataHash],
      limit: 1,
    );
    
    if (metadataMatch.isNotEmpty) return true;
    
    // Deep check: perceptual hash (for moved/renamed files)
    final perceptualMatch = await db.query(
      'processed_images',
      where: 'perceptual_hash = ?',
      whereArgs: [hashes.perceptualHash],
      limit: 1,
    );
    
    return perceptualMatch.isNotEmpty;
  }
}
```

**Performance Comparison:**

| Method | Per Image | 10,000 Images | Use Case |
|--------|-----------|---------------|----------|
| **Metadata Hash** | < 1ms | ~5-10 seconds | Fast duplicate check (exact files) |
| **Perceptual Hash** | 10-50ms | ~100-500 seconds | Visual duplicate detection |
| **Hybrid (Smart)** | 1-50ms* | ~10-500 seconds* | Best of both worlds |

\* *Hybrid approach: Uses fast metadata hash first (< 1ms), only computes perceptual hash when metadata hash doesn't match (10-50ms). For most cases (exact duplicates), it's as fast as metadata hash. For visual duplicates, it's as accurate as perceptual hash.*

**Real-World Performance (Hybrid Approach):**
- **90% of images** (exact duplicates): < 1ms per image → ~10 seconds for 10K images
- **10% of images** (need perceptual check): 10-50ms per image → ~10-50 seconds for 1K images
- **Total for 10K images:** ~20-60 seconds (vs 100-500 seconds for pure perceptual)

### Performance Optimization: In-Memory Hash Set

For large galleries (10,000+ images), loading all hashes into memory is faster than database queries:

```dart
class FastDuplicateChecker {
  Set<String>? _processedHashes;
  
  Future<void> loadProcessedHashes() async {
    final hashes = await db.getAllHashes(); // Single query
    _processedHashes = Set.from(hashes);
  }
  
  bool isAlreadyProcessed(String hash) {
    return _processedHashes?.contains(hash) ?? false;
  }
  
  Future<List<ImageFile>> filterUnprocessed(List<ImageFile> images) async {
    await loadProcessedHashes();
    
    final unprocessed = <ImageFile>[];
    for (final image in images) {
      final hash = await generateHash(image);
      if (!isAlreadyProcessed(hash)) {
        unprocessed.add(image);
      }
    }
    
    return unprocessed;
  }
}
```

**Performance:**
- Database query: ~10-50ms per image
- In-memory lookup: ~0.001ms per image
- **10,000x faster** for batch operations

---

## Data Flow

### Parallel Processing Pipeline (Non-Blocking)

**Key Principle:** OCR and Classification run in **parallel pipelines** - OCR doesn't wait for classification API calls.

```
┌─────────────────────────────────────────────────────────────────┐
│ Pipeline Stage 1: Image Discovery & Hash Check                 │
│ ┌───────────────────────────────────────────────────────────┐ │
│ │ - Scan device gallery                                      │ │
│ │ - Generate metadata hash (fast)                             │ │
│ │ - Check if already processed (in-memory lookup)             │ │
│ │ - Queue unprocessed images                                 │ │
│ └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────┴───────────────┐
        │                               │
        ↓                               ↓
┌───────────────────┐         ┌───────────────────┐
│ OCR Pipeline      │         │ Classification     │
│ (Parallel)        │         │ Queue             │
│                   │         │ (Separate Worker) │
│ Processes images  │         │                   │
│ continuously      │         │ Processes OCR     │
│ without waiting   │         │ results as API    │
│ for classification│         │ allows            │
└───────────────────┘         └───────────────────┘
        │                               │
        │                               │
        ↓                               ↓
┌─────────────────────────────────────────────────────────────┐
│ OCR Worker (Isolate/Thread)                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Image 1: OCR → Queue for classification                  │ │
│ │ Image 2: OCR → Queue for classification                  │ │
│ │ Image 3: OCR → Queue for classification                  │ │
│ │ ... (continues without waiting)                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
        │                               │
        │ OCR Results                   │
        └───────────────┬───────────────┘
                        ↓
        ┌───────────────────────────────┐
        │ Classification Queue           │
        │ (FIFO with rate limiting)     │
        └───────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Classification Worker (Separate Isolate)                      │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ - Respects API rate limits (10 req/min)                 │ │
│ │ - Processes queue items as API allows                   │ │
│ │ - Sends OCR text to Serverpod → OpenRouter               │ │
│ │ - Receives classification results                        │ │
│ │ - Stores results asynchronously                          │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────────┐
│ Storage & Sync (Non-blocking)                                 │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ - Store OCR + classification in SQLite                  │ │
│ │ - Queue for server sync (background)                    │ │
│ │ - Update progress tracking                               │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Parallel Processing Flow (Detailed)

**Timeline Example (Processing 5 images):**

```
Time    OCR Pipeline              Classification Queue        Classification Worker
─────────────────────────────────────────────────────────────────────────────────────
0ms     Image 1: Start OCR        [empty]                     [idle]
500ms   Image 1: OCR done →       [Image 1 OCR]               [idle]
        Image 2: Start OCR
1000ms  Image 2: OCR done →       [Image 1, Image 2]         Image 1: API call
        Image 3: Start OCR
1500ms  Image 3: OCR done →       [Image 1, Image 2,          Image 1: Waiting...
        Image 4: Start OCR         Image 3]                   (API rate limit)
2000ms  Image 4: OCR done →       [Image 1, Image 2,          Image 1: Still waiting
        Image 5: Start OCR         Image 3, Image 4]         (10 req/min limit)
2500ms  Image 5: OCR done         [Image 1, Image 2,          Image 1: API response
        [All OCR complete]         Image 3, Image 4,          → Store result
                                   Image 5]                    Image 2: API call
3000ms  [OCR idle]                [Image 2, Image 3,          Image 2: Waiting...
                                   Image 4, Image 5]
3500ms  [OCR idle]                [Image 2, Image 3,          Image 2: API response
                                   Image 4, Image 5]           → Store result
                                                                 Image 3: API call
...     [OCR idle]                [Processing queue...]       [Processing queue...]
```

**Key Benefits:**
- ✅ OCR completes all images in ~2.5 seconds (parallel)
- ✅ Classification processes as API allows (respects rate limits)
- ✅ No blocking: OCR doesn't wait for classification
- ✅ Maximum throughput: Both pipelines work simultaneously

### Parallel Pipeline Implementation

```dart
class ParallelImageProcessor {
  final OCRQueue _ocrQueue = OCRQueue();
  final ClassificationQueue _classificationQueue = ClassificationQueue();
  final ClassificationWorker _classificationWorker = ClassificationWorker();
  
  // Start processing pipeline
  Future<void> startProcessing(List<ImageFile> images) async {
    // Start classification worker (runs independently)
    _classificationWorker.start();
    
    // Process images through OCR pipeline (doesn't wait for classification)
    await _processOCRPipeline(images);
  }
  
  // OCR Pipeline: Processes images continuously
  Future<void> _processOCRPipeline(List<ImageFile> images) async {
    // Process multiple images in parallel (limited concurrency)
    final semaphore = Semaphore(5); // Max 5 OCR operations at once
    
    await Future.wait(
      images.map((image) async {
        await semaphore.acquire();
        try {
          await _processOCR(image);
        } finally {
          semaphore.release();
        }
      }),
    );
  }
  
  // OCR Processing: Doesn't wait for classification
  Future<void> _processOCR(ImageFile image) async {
    try {
      // 1. Hash check
      final hash = await generateHash(image);
      if (await isAlreadyProcessed(hash)) {
        return; // Skip – already processed or duplicate
      }
      
      // 2. OCR (on-device, fast)
      final ocrText = await performOCR(image);
      
      // 2a. Skip rule: no meaningful text
      // - Always run OCR, but only classify if there is enough signal.
      // - Use a small length threshold on non-whitespace characters.
      final normalized = ocrText.replaceAll(RegExp(r'\s+'), '');
      if (normalized.length < 8) {
        await db.storeNoTextResult(
          hash: hash,
          image: image,
          ocrText: ocrText,
          reason: 'No meaningful text detected (below length threshold)',
        );
        return; // Do not send to classifier
      }
      
      // 2b. Optional skip rule: extremely long text with no receipt signals
      if (shouldSkipAsOutOfScope(ocrText)) {
        await db.storeOutOfScopeResult(
          hash: hash,
          image: image,
          ocrText: ocrText,
          reason: 'Text too long and no strong receipt/bill/invoice signals',
        );
        return; // Avoid burning tokens on non-relevant documents
      }
      
      // 3. Store OCR result immediately (don't wait for classification)
      await db.storeOCRResult(hash, image, ocrText);
      
      // 4. Queue for classification (non-blocking, batched later)
      await _classificationQueue.enqueue(
        ClassificationTask(
          hash: hash,
          ocrText: ocrText,
        ),
      );
      
      // OCR is done! Continue with next image immediately
      
    } catch (e) {
      // Log error, continue with next image
      await db.markAsFailed(hash, e.toString());
    }
  }
}

// Classification Worker: Processes queue independently with rate limiting
class ClassificationWorker {
  final ClassificationQueue _queue;
  final RateLimitManager _rateLimiter;
  bool _isRunning = false;
  
  Future<void> start() async {
    _isRunning = true;
    while (_isRunning) {
      final task = await _queue.dequeue();
      if (task == null) {
        await Future.delayed(Duration(seconds: 1)); // Wait if queue empty
        continue;
      }
      
      // CRITICAL: Check and wait for rate limits BEFORE processing
      final canProcess = await _rateLimiter.checkAndWait();
      if (!canProcess) {
        // Daily limit reached - pause until next day
        await _queue.enqueue(task, priority: 1); // Re-queue for later
        await Future.delayed(Duration(minutes: 60)); // Wait 1 hour, then retry
        continue;
      }
      
      // Process classification (rate limiter ensures proper spacing)
      await _processClassification(task);
    }
  }
  
  Future<void> _processClassification(ClassificationTask task) async {
    try {
      // Call classification API
      final classification = await classifyText(task.ocrText);
      
      // Update database with classification result
      await db.updateClassificationResult(
        task.hash,
        classification,
      );
      
      // Queue for server sync (non-blocking)
      syncToServer(task.hash, task.ocrText, classification)
          .catchError((error) {
        markAsUnsynced(task.hash);
      });
      
    } catch (e) {
      // Retry later if rate limited or API error
      if (e is RateLimitException) {
        await _queue.enqueue(task, priority: 1); // Re-queue
      } else {
        await db.markClassificationFailed(task.hash, e.toString());
      }
    }
  }
  
  void stop() {
    _isRunning = false;
  }
}

// Classification Queue: FIFO with priority
class ClassificationQueue {
  final Queue<ClassificationTask> _queue = Queue();
  final Completer<ClassificationTask>? _waiting;
  
  Future<void> enqueue(ClassificationTask task) async {
    _queue.add(task);
    // Notify waiting worker
  }
  
  Future<ClassificationTask?> dequeue() async {
    if (_queue.isEmpty) return null;
    return _queue.removeFirst();
  }
}
```

### Performance Benefits

**Sequential Approach (Old):**
```
Image 1: OCR (500ms) → Wait for API (5s) → Next image
Image 2: OCR (500ms) → Wait for API (5s) → Next image
Total: 10 images × (500ms + 5000ms) = 55 seconds
```

**Parallel Pipeline (New):**
```
OCR Pipeline:     Image 1-10: All OCR done in ~2.5 seconds (parallel)
Classification:   Processes queue as API allows (10 req/min)
Image 1: 5s, Image 2: 5s, ... Image 10: 5s
Total: OCR (2.5s) + Classification (50s) = ~52.5 seconds
But: OCR doesn't block, user sees progress immediately
```

**Key Advantage:**
- OCR completes quickly (all images processed)
- Classification happens in background (respects rate limits)
- User sees OCR results immediately
- Classification results appear as API responds
- **No waiting**: OCR pipeline never blocks on API calls

### Answering Key Questions

**Q: Will we keep waiting during OpenRouter API calls?**
**A: NO** - OCR continues processing other images while classification API calls are in flight. They run in separate pipelines.

**Q: Will OCR wait for classification to complete?**
**A: NO** - OCR completes immediately and queues the result for classification. OCR pipeline moves to next image without waiting.

**Q: Will we send data after whole OCR is done, or in batches?**
**A: Batched classification** - Each OCR result is queued immediately when ready. Classification worker collects batches of 50 OCR texts and sends them in **one API request**, dramatically reducing the number of API calls needed.

**Q: Will batching take too long with rate limits?**
**A: NO** - With batching, we need **200 requests** instead of 10,000:
- **10,000 images ÷ 50 per batch = 200 API requests**
- At 20 req/min: 200 ÷ 20 = **10 minutes** (if unlimited)
- With 1,000/day limit: All 200 requests can be processed in **1 day** ✅
- **10x faster** than one-by-one approach!

**Q: How does batching work?**
**A:** Classification worker:
1. Collects 50 OCR texts from queue
2. Sends all 50 in **one API request** with structured prompt
3. Receives JSON array with 50 classification results
4. Stores all results immediately
5. Repeats until queue is empty

**Q: Will OCR have to wait for batch completion?**
**A: NO** - OCR completes independently and queues results immediately. Classification worker processes batches in background, respecting rate limits (3 seconds between batch requests).

**Rate Limit Reality Check (WITH Batching):**
- **10,000 images** = 200 API requests (50 per batch)
- **With $10 deposit:** 200 requests/day → **1 day** to complete ✅
- **Without deposit:** 50 requests/day → **4 days** to complete
- **Recommendation:** Deposit $10 for 1-day processing, or use batching for 4-day processing without deposit

**Processing Flow Summary:**
1. **OCR Pipeline**: Processes images continuously, queues results immediately
2. **Classification Queue**: Receives OCR results as they complete (FIFO)
3. **Classification Worker**: Processes queue items one-by-one, respects API rate limits
4. **Storage**: Results stored asynchronously when classification completes
5. **No Blocking**: OCR never waits, classification never blocks OCR

---

## Local Database Schema

### Client-Side Database Technology

On the device (Flutter app), we use **SQLite** via the `sqflite` package:

- Battle-tested, widely used in Flutter production apps.
- Matches our relational schema design below.
- Works well with optional higher-level ORMs like `drift` if we later want type-safe queries.

On the server (Serverpod backend), we use **PostgreSQL**, which is Serverpod’s default and integrates with its ORM and migration tooling.

---

## Albums & In-App Browsing by Type

### Goal

Allow users to **browse images inside the app grouped by classification**, without duplicating any images or doing heavy sync work. Examples:

- “Bank receipts” album (`bank_receipt`)
- “POS receipts” album (`pos_receipt`)
- “Bills & invoices” (`bill`, `invoice`)
- “Wallet receipts” (`digital_wallet_receipt`)
- “Shopping / orders” (`shopping_order`)

### How Albums Work (Conceptually)

- We **never copy images**.  
- We store **references** (paths / URIs / hashes) in `processed_images`.  
- Albums are just **queries** over that table:
  - `WHERE document_type = 'bank_receipt'`
  - `WHERE document_type IN ('bill', 'invoice')`
  - `WHERE category = 'shopping'`, etc.
- Flutter screens render those queries as:
  - `GridView` / `ListView` of thumbnails using `Image.file` or a gallery plugin that accepts a URI / asset ID.

### Extra Columns Needed for Albums

We already have:

- `file_path`, `file_name`, `file_size`, `modified_date`
- `document_type`, `category`, `processed_at`

Add **two optional columns** to make album browsing more robust across platforms:

```sql
  content_uri TEXT,      -- Android MediaStore URI (e.g. content://…)
  asset_id TEXT,         -- iOS PHAsset.localIdentifier
  is_deleted INTEGER DEFAULT 0,  -- 0 = exists, 1 = deleted/missing
```

- **`content_uri` / `asset_id`**:  
  - Let us re-open the image even if its filesystem path changes (common in gallery apps).
  - Filled when we first scan the gallery (via `photo_manager` / `image_gallery_saver`-style APIs).
- **`is_deleted`**:
  - Mark entries where the underlying image can no longer be found.
  - Album queries exclude `is_deleted = 1` so users don’t see broken images.

### Keeping Albums Up-To-Date

1. **New image appears in gallery**
   - Gallery scan finds it, computes hash, runs OCR + classification.
   - We `INSERT` a row into `processed_images` with `document_type`, `category`, `file_path`/`content_uri`/`asset_id`.
   - It **automatically appears** in the correct album because the album UI just runs a filtered query.

2. **Image is deleted outside the app**
   - Periodic rescan (or on app launch) checks that each `file_path`/`content_uri`/`asset_id` still resolves.
   - If not, we set `is_deleted = 1` (or hard-delete the row).
   - Album queries use `WHERE is_deleted = 0` to hide missing images.

3. **Image is moved/renamed by the system**
   - Next scan finds a “new” file with **same `metadata_hash` or `perceptual_hash`** but a different path/URI.
   - We **update the existing row** with the new `file_path` / `content_uri` / `asset_id` instead of inserting a new one.
   - This keeps albums stable and avoids duplicates.

### Example Album Queries

**Bank receipts album:**

```sql
SELECT *
FROM processed_images
WHERE document_type = 'bank_receipt'
  AND is_deleted = 0
ORDER BY transaction_date DESC, processed_at DESC;
```

**POS receipts album:**

```sql
SELECT *
FROM processed_images
WHERE document_type = 'pos_receipt'
  AND is_deleted = 0
ORDER BY processed_at DESC;
```

**Bills & invoices:**

```sql
SELECT *
FROM processed_images
WHERE document_type IN ('bill', 'invoice')
  AND is_deleted = 0
ORDER BY transaction_date DESC, processed_at DESC;
```

**“All financial docs” album:**

```sql
SELECT *
FROM processed_images
WHERE document_type IN (
    'bank_receipt',
    'pos_receipt',
    'digital_wallet_receipt',
    'invoice',
    'bill',
    'shopping_order'
  )
  AND is_deleted = 0
ORDER BY processed_at DESC;
```

### Flutter UI Pattern (High-Level)

- Each album screen is a simple **DB-backed list**:

```dart
Stream<List<ProcessedImage>> watchAlbum(String whereClause, List<Object?> args);
```

- The UI subscribes to the stream and renders:

```dart
GridView.builder(
  itemCount: images.length,
  itemBuilder: (context, index) {
    final img = images[index];
    return GestureDetector(
      onTap: () => openDetail(img),
      child: ImageWidget.fromReference(img), // file_path or content_uri/asset_id
    );
  },
);
```

- `ImageWidget.fromReference` chooses the best available reference:
  - If `content_uri` exists → load via gallery plugin.
  - Else if `file_path` exists → `Image.file(File(file_path))`.
  - Else → placeholder / “image missing” indicator.

### Overhead & Performance

- No image duplication – only lightweight metadata rows.
- All album changes are **implicit**: they follow from new/updated rows in `processed_images`.
- Queries are fast with existing indexes on `document_type`, `category`, `processed_at`, and `is_deleted`.

This gives you:

- “Albums by type” in-app (bank receipts, POS, bills, etc.).
- Automatic updating as new images are processed or deleted.
- Minimal additional complexity on top of the architecture you already have.

---

### SQLite Schema

```sql
-- Main table for processed images
CREATE TABLE processed_images (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  
  -- Hash identifiers
  metadata_hash TEXT NOT NULL,          -- Fast duplicate detection
  perceptual_hash TEXT,                  -- Visual duplicate detection
  
  -- File metadata
  file_path TEXT NOT NULL,               -- Original file path
  file_name TEXT,                        -- File name
  file_size INTEGER,                     -- File size in bytes
  modified_date INTEGER,                 -- Last modified timestamp
  created_date INTEGER,                  -- File creation date
  
  -- OCR results
  ocr_text TEXT,                         -- Extracted text
  ocr_confidence REAL,                    -- OCR confidence (0.0-1.0)
  ocr_language TEXT,                     -- Detected language
  
  -- Classification results
  document_type TEXT,                     -- bank_receipt, pos_receipt, etc.
  classification_confidence REAL,         -- Classification confidence (0.0-1.0)
  category TEXT,                         -- food, transport, shopping, etc.
  
  -- Extracted fields
  merchant_name TEXT,
  transaction_date TEXT,                  -- ISO 8601 format
  transaction_time TEXT,                 -- HH:mm format
  amount REAL,
  currency TEXT,
  payment_method TEXT,
  transaction_id TEXT,
  tax_amount REAL,
  
  -- Processing metadata
  processed_at INTEGER NOT NULL,          -- When processed (timestamp)
  processing_duration_ms INTEGER,        -- How long processing took
  ocr_duration_ms INTEGER,                -- OCR processing time
  classification_duration_ms INTEGER,    -- Classification API call time
  
  -- Sync status
  synced_to_server INTEGER DEFAULT 0,     -- 0 = not synced, 1 = synced
  sync_attempts INTEGER DEFAULT 0,       -- Number of sync attempts
  last_sync_attempt INTEGER,              -- Last sync attempt timestamp
  sync_error TEXT,                        -- Last sync error message
  
  -- User corrections
  user_corrected INTEGER DEFAULT 0,       -- 1 if user manually corrected
  user_corrections TEXT,                  -- JSON of user corrections
  
  -- Indexes
  UNIQUE(metadata_hash),
  UNIQUE(perceptual_hash)
);

-- Indexes for fast queries
CREATE INDEX idx_metadata_hash ON processed_images(metadata_hash);
CREATE INDEX idx_perceptual_hash ON processed_images(perceptual_hash);
CREATE INDEX idx_document_type ON processed_images(document_type);
CREATE INDEX idx_category ON processed_images(category);
CREATE INDEX idx_processed_at ON processed_images(processed_at);
CREATE INDEX idx_synced_to_server ON processed_images(synced_to_server);
CREATE INDEX idx_merchant_name ON processed_images(merchant_name);
CREATE INDEX idx_transaction_date ON processed_images(transaction_date);

-- Table for processing queue
CREATE TABLE processing_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  image_path TEXT NOT NULL,
  metadata_hash TEXT,
  priority INTEGER DEFAULT 0,            -- Higher = process first
  status TEXT DEFAULT 'pending',          -- pending, processing, completed, failed
  created_at INTEGER NOT NULL,
  started_at INTEGER,
  completed_at INTEGER,
  error_message TEXT,
  retry_count INTEGER DEFAULT 0
);

CREATE INDEX idx_queue_status ON processing_queue(status);
CREATE INDEX idx_queue_priority ON processing_queue(priority DESC);

-- Table for sync queue (failed syncs)
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  processed_image_id INTEGER NOT NULL,
  sync_data TEXT NOT NULL,                -- JSON of data to sync
  created_at INTEGER NOT NULL,
  last_attempt INTEGER,
  attempt_count INTEGER DEFAULT 0,
  FOREIGN KEY (processed_image_id) REFERENCES processed_images(id)
);

CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);
```

### Dart Model Classes

```dart
class ProcessedImage {
  final int? id;
  final String metadataHash;
  final String? perceptualHash;
  final String filePath;
  final String? fileName;
  final int? fileSize;
  final DateTime? modifiedDate;
  final String? ocrText;
  final double? ocrConfidence;
  final String? documentType;
  final double? classificationConfidence;
  final String? category;
  final String? merchantName;
  final DateTime? transactionDate;
  final String? transactionTime;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String? transactionId;
  final double? taxAmount;
  final DateTime processedAt;
  final bool syncedToServer;
  
  // ... constructors, toMap, fromMap methods
}

class ProcessingQueueItem {
  final int? id;
  final String imagePath;
  final String? metadataHash;
  final int priority;
  final ProcessingStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final int retryCount;
  
  // ... methods
}

enum ProcessingStatus {
  pending,
  processing,
  completed,
  failed,
}
```

---

## Gallery Processing Flow

### Initial Gallery Scan

```dart
class GalleryProcessor {
  final LocalDatabase db;
  final ImageHashService hashService;
  final OCRService ocrService;
  final ClassificationService classificationService;
  
  Future<ProcessingStats> processGallery({
    bool background = false,
    Function(int current, int total)? onProgress,
  }) async {
    final stats = ProcessingStats();
    
    // 1. Get all images from gallery
    final allImages = await getGalleryImages();
    stats.totalImages = allImages.length;
    
    // 2. Load processed hashes into memory (fast lookup)
    await db.loadProcessedHashes();
    
    // 3. Filter unprocessed images
    final unprocessed = <ImageFile>[];
    for (final image in allImages) {
      final hash = await hashService.generateHash(image);
      if (!db.isAlreadyProcessed(hash)) {
        unprocessed.add(image);
      } else {
        stats.skipped++;
      }
    }
    
    stats.toProcess = unprocessed.length;
    
    // 4. Add to processing queue
    await db.addToQueue(unprocessed);
    
    // 5. Process queue
    await processQueue(
      onProgress: onProgress,
      background: background,
    );
    
    return stats;
  }
  
  Future<void> processQueue({
    Function(int current, int total)? onProgress,
    bool background = false,
  }) async {
    final queue = await db.getQueueItems(status: 'pending');
    final total = queue.length;
    var processed = 0;
    
    for (final item in queue) {
      try {
        // Update status
        await db.updateQueueStatus(item.id!, 'processing');
        
        // Process image
        final result = await processImage(item.imagePath);
        
        if (result.success) {
          await db.updateQueueStatus(item.id!, 'completed');
          processed++;
        } else {
          await db.updateQueueStatus(item.id!, 'failed', result.error);
        }
        
        // Progress callback
        onProgress?.call(processed, total);
        
        // Rate limiting (for classification API)
        if (!background) {
          await Future.delayed(Duration(milliseconds: 100));
        }
        
      } catch (e) {
        await db.updateQueueStatus(item.id!, 'failed', e.toString());
      }
    }
  }
  
  Future<ProcessingResult> processImage(String imagePath) async {
    final imageFile = File(imagePath);
    
    // 1. Generate hash
    final hashes = await hashService.generateHashes(imageFile);
    
    // 2. Check if already processed (double-check)
    if (await db.isAlreadyProcessed(hashes.metadataHash)) {
      return ProcessingResult.skipped();
    }
    
    // 3. OCR
    final ocrStart = DateTime.now();
    final ocrResult = await ocrService.extractText(imageFile);
    final ocrDuration = DateTime.now().difference(ocrStart).inMilliseconds;
    
    if (ocrResult.text.isEmpty) {
      return ProcessingResult.failed('No text detected');
    }
    
    // 4. Classification
    final classificationStart = DateTime.now();
    final classification = await classificationService.classify(ocrResult.text);
    final classificationDuration = DateTime.now()
        .difference(classificationStart)
        .inMilliseconds;
    
    // 5. Store locally
    final processedImage = ProcessedImage(
      metadataHash: hashes.metadataHash,
      perceptualHash: hashes.perceptualHash,
      filePath: imagePath,
      fileName: imageFile.path.split('/').last,
      fileSize: await imageFile.length(),
      modifiedDate: await imageFile.lastModified(),
      ocrText: ocrResult.text,
      ocrConfidence: ocrResult.confidence,
      documentType: classification.documentType,
      classificationConfidence: classification.confidence,
      category: classification.category,
      merchantName: classification.merchantName,
      transactionDate: classification.transactionDate,
      transactionTime: classification.transactionTime,
      amount: classification.amount,
      currency: classification.currency,
      paymentMethod: classification.paymentMethod,
      transactionId: classification.transactionId,
      taxAmount: classification.taxAmount,
      processedAt: DateTime.now(),
      syncedToServer: false,
    );
    
    await db.insertProcessedImage(processedImage);
    
    // 6. Queue for server sync (non-blocking)
    syncToServer(processedImage).catchError((error) {
      // Log error, will retry later
    });
    
    return ProcessingResult.success(processedImage);
  }
}
```

### Background Processing

```dart
class BackgroundProcessor {
  static Future<void> startBackgroundProcessing() async {
    // Process queue in background isolate
    await compute(_processQueueInBackground, null);
  }
  
  static Future<void> _processQueueInBackground(dynamic _) async {
    final processor = GalleryProcessor();
    await processor.processQueue(
      background: true,
      onProgress: (current, total) {
        // Update progress (can use shared preferences or database)
      },
    );
  }
}
```

### Pause/Resume Functionality

```dart
class ProcessingController {
  bool _isPaused = false;
  bool _isCancelled = false;
  
  void pause() {
    _isPaused = true;
  }
  
  void resume() {
    _isPaused = false;
  }
  
  void cancel() {
    _isCancelled = true;
  }
  
  Future<void> processWithControl(List<ImageFile> images) async {
    for (final image in images) {
      // Check if paused
      while (_isPaused && !_isCancelled) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      // Check if cancelled
      if (_isCancelled) {
        break;
      }
      
      // Process image
      await processImage(image);
    }
  }
}
```

---

## Bandwidth Analysis

### Problem: Image Upload Bandwidth

**Scenario:** User has 10,000 images in gallery
- Screenshots: 140 KB average
- Camera photos: 2-5 MB average
- Mixed: ~1 MB average

**If we uploaded images:**
```
10,000 images × 1 MB = 10,000 MB = 10 GB
```

This is **completely impractical** for:
- Mobile data plans
- User experience (hours of upload time)
- Server storage costs
- Network infrastructure

### Solution: Send Only OCR Text

**Our approach:**
- OCR happens on-device (no upload)
- Only send OCR text (~5-10 KB per image)
- Send classification result (~1 KB)
- Total per image: ~6-11 KB

**Bandwidth comparison:**

| Approach | Data per Image | 10,000 Images | Savings |
|----------|---------------|---------------|---------|
| Upload Images | 1 MB | 10 GB | - |
| Send OCR Text Only | 10 KB | 100 MB | **99% reduction** |

**Real-world example:**
- User with 10,000 images
- Old approach: 10 GB upload (hours, expensive)
- New approach: 100 MB upload (minutes, cheap)
- **99% bandwidth savings**

### Network Efficiency

```dart
class NetworkOptimizer {
  // Batch sync to reduce HTTP overhead
  Future<void> syncBatch(List<ProcessedImage> images) async {
    final batchSize = 50; // Sync 50 at a time
    
    for (var i = 0; i < images.length; i += batchSize) {
      final batch = images.sublist(
        i,
        i + batchSize > images.length ? images.length : i + batchSize,
      );
      
      // Compress JSON payload
      final payload = jsonEncode(batch.map((img) => img.toSyncJson()).toList());
      final compressed = gzip.encode(utf8.encode(payload));
      
      // Send to server
      await serverpodClient.syncBatch(compressed);
    }
  }
  
  // Only sync changed data
  Future<void> syncIncremental() async {
    final unsynced = await db.getUnsyncedImages();
    if (unsynced.isEmpty) return;
    
    await syncBatch(unsynced);
  }
}
```

---

## Serverpod Backend

### Serverpod Capabilities

**What Serverpod Can Do:**
- ✅ Run Dart code natively
- ✅ Store data in PostgreSQL
- ✅ Make HTTP API calls (to OpenRouter)
- ✅ Handle authentication
- ✅ File storage (for metadata, not images)
- ✅ Background tasks
- ✅ WebSocket connections

**What Serverpod Cannot Do Easily:**
- ❌ Run Python scripts (would need process spawning)
- ❌ Run pytesseract (Python dependency)
- ❌ Heavy image processing (not designed for it)

**Our Solution:**
- Keep OCR on-device (Google ML Kit)
- Serverpod only stores metadata
- Serverpod calls OpenRouter for classification

### Serverpod Schema

```dart
// server/lib/src/models/processed_image.dart
class ProcessedImage extends Table {
  @Column()
  String metadataHash;
  
  @Column()
  String? perceptualHash;
  
  @Column()
  String filePath;
  
  @Column()
  String? fileName;
  
  @Column()
  int? fileSize;
  
  @Column()
  DateTime? modifiedDate;
  
  @Column()
  String? ocrText;
  
  @Column()
  double? ocrConfidence;
  
  @Column()
  String? documentType;
  
  @Column()
  double? classificationConfidence;
  
  @Column()
  String? category;
  
  @Column()
  String? merchantName;
  
  @Column()
  DateTime? transactionDate;
  
  @Column()
  String? transactionTime;
  
  @Column()
  double? amount;
  
  @Column()
  String? currency;
  
  @Column()
  String? paymentMethod;
  
  @Column()
  String? transactionId;
  
  @Column()
  double? taxAmount;
  
  @Column()
  DateTime processedAt;
  
  @Column()
  int userId; // Foreign key to User table
}
```

### Classification Endpoint

```dart
// server/lib/src/endpoints/classification_endpoint.dart
class ClassificationEndpoint extends Endpoint {
  Future<ClassificationResult> classifyText(
    Session session,
    String ocrText,
  ) async {
    // Call OpenRouter API
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${env.openRouterApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-r1-0528:free',
        'messages': [
          {
            'role': 'system',
            'content': _getClassificationPrompt(),
          },
          {
            'role': 'user',
            'content': ocrText,
          },
        ],
        'response_format': {'type': 'json_object'},
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ClassificationResult.fromJson(
        jsonDecode(data['choices'][0]['message']['content']),
      );
    } else {
      throw Exception('Classification failed: ${response.statusCode}');
    }
  }
  
  String _getClassificationPrompt() {
    // Use prompt from SRS.md
    return '''
You are a document classification assistant.
Classify the following OCR text into one of these types:
- bank_receipt
- pos_receipt
- digital_wallet_receipt
- invoice
- bill
- shopping_order

Return JSON with document_type, confidence, category, and extracted fields.
''';
  }
}
```

### Rate Limit Management (Critical for Large-Scale Processing)

**OpenRouter Free Tier Limits:**
- **Per Minute:** 20 requests/minute (1 request every 3 seconds)
- **Per Day:** 50 requests/day (default) OR 1,000 requests/day (with $10 deposit)

**For 10,000 images (WITHOUT batching - one-by-one):**
- At 20 req/min: Would take 500 minutes = **8.3 hours** (if unlimited daily)
- But daily limit: Only **1,000 images/day** (with deposit) or **50/day** (without)
- **Reality:** Processing 10,000 images takes **10 days** (with $10 deposit) or **200 days** (without)

**For 10,000 images (WITH batching - 50 per request):**
- 10,000 images ÷ 50 = **200 API requests** needed
- At 20 req/min: 200 ÷ 20 = **10 minutes** (if unlimited daily)
- With daily limit: **200 requests/day** (well under 1,000 limit)
- **Reality:** Processing 10,000 images takes **~1 day** (with $10 deposit) ✅
- **10x faster** than one-by-one approach!

```dart
class RateLimitManager {
  // OpenRouter free tier limits
  static const int REQUESTS_PER_MINUTE = 20; // Max 20 requests per minute
  static const int REQUESTS_PER_DAY_WITH_DEPOSIT = 1000; // With $10 deposit
  static const int REQUESTS_PER_DAY_FREE = 50; // Without deposit
  
  final int maxRequestsPerDay;
  final Duration minTimeBetweenRequests = Duration(seconds: 3); // 60s / 20 = 3s
  
  int _requestsToday = 0;
  DateTime _lastReset = DateTime.now();
  DateTime? _lastRequestTime;
  final Queue<DateTime> _recentRequests = Queue();
  
  RateLimitManager({bool hasDeposit = false})
      : maxRequestsPerDay = hasDeposit 
          ? REQUESTS_PER_DAY_WITH_DEPOSIT 
          : REQUESTS_PER_DAY_FREE;
  
  /// Check if we can make a request and wait if needed
  /// Returns true if request can proceed, false if daily limit reached
  Future<bool> checkAndWait() async {
    final now = DateTime.now();
    
    // Reset daily counter at midnight
    if (now.difference(_lastReset).inDays >= 1) {
      _requestsToday = 0;
      _lastReset = now;
    }
    
    // Check daily limit
    if (_requestsToday >= maxRequestsPerDay) {
      return false; // Daily limit reached
    }
    
    // Enforce per-minute limit: Remove requests older than 1 minute
    _recentRequests.removeWhere(
      (time) => now.difference(time).inMinutes >= 1,
    );
    
    // If we've made 20 requests in the last minute, wait
    if (_recentRequests.length >= REQUESTS_PER_MINUTE) {
      final oldest = _recentRequests.first;
      final waitTime = Duration(seconds: 60) - now.difference(oldest);
      if (waitTime.inMilliseconds > 0) {
        await Future.delayed(waitTime);
      }
    }
    
    // Enforce minimum time between requests (3 seconds)
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = now.difference(_lastRequestTime!);
      if (timeSinceLastRequest < minTimeBetweenRequests) {
        final waitTime = minTimeBetweenRequests - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    
    // Record this request
    _requestsToday++;
    _lastRequestTime = DateTime.now();
    _recentRequests.add(_lastRequestTime!);
    
    return true; // Can proceed
  }
  
  /// Get remaining requests for today
  int get remainingToday => maxRequestsPerDay - _requestsToday;
  
  /// Get estimated time to process remaining queue
  Duration estimateTimeForRequests(int queueSize) {
    final remaining = math.min(queueSize, remainingToday);
    final minutes = (remaining / REQUESTS_PER_MINUTE).ceil();
    return Duration(minutes: minutes);
  }
}
```

**Rate Limit Strategy:**

1. **Per-Minute Limit (20 req/min):**
   - Wait **3 seconds** between each request (60s ÷ 20 = 3s)
   - Track requests in sliding 1-minute window
   - If 20 requests made, wait until oldest request is > 1 minute old

2. **Daily Limit (50 or 1,000):**
   - Track requests made today
   - Reset at midnight
   - If limit reached, pause processing until next day
   - Queue items remain, will be processed next day

3. **Queue Management:**
   - OCR continues (no limits)
   - Classification queue grows as OCR completes
   - Classification worker processes queue respecting limits
   - User sees progress: "Processing 150/10,000 (1,000/day limit, ~10 days remaining)"

**Example Timeline (10,000 images with $10 deposit):**

**WITHOUT Batching (one-by-one):**
```
Day 1: Process 1,000 images (20 req/min × 50 min = 1,000 req)
       OCR completes all 10,000 in ~2 hours
       Classification: 1,000 done, 9,000 queued
       
Day 2: Process next 1,000 images
       Classification: 2,000 done, 8,000 queued
       
...
Day 10: Process final 1,000 images
        Classification: 10,000 done, queue empty
```

**WITH Batching (50 per request):**
```
Hour 1: OCR completes all 10,000 images (~2 hours)
        Queue: 10,000 OCR results ready

Hour 2-3: Classification processing
          - 200 batches × 50 documents = 10,000 classifications
          - At 20 req/min: 200 requests ÷ 20 = 10 minutes
          - Total: ~1-2 hours for all classifications
          
Result: All 10,000 images processed in ~1 day! ✅
```

**Without $10 deposit (50/day limit):**
- Would take **200 days** to process 10,000 images
- **Recommendation:** Deposit $10 for 1,000/day limit

### ⚡ Batch Classification Optimization (CRITICAL)

**Problem:** Processing 10,000 images one-by-one = 10,000 API requests = 10 days (with $10 deposit)

**Solution:** **Batch multiple OCR texts in a single API request!**

While OpenRouter doesn't have a dedicated batch API, we can send **multiple documents in one request** by including them all in a single prompt. This dramatically reduces API calls.

**Batch Classification Strategy:**

```dart
class BatchClassificationService {
  static const int BATCH_SIZE = 50; // Classify 50 documents per request
  
  Future<List<ClassificationResult>> classifyBatch(
    List<ClassificationTask> tasks,
  ) async {
    // Group tasks into batches
    final batches = <List<ClassificationTask>>[];
    for (var i = 0; i < tasks.length; i += BATCH_SIZE) {
      batches.add(tasks.sublist(
        i,
        i + BATCH_SIZE > tasks.length ? tasks.length : i + BATCH_SIZE,
      ));
    }
    
    final results = <ClassificationResult>[];
    for (final batch in batches) {
      // Send all OCR texts in one request
      final batchResult = await _classifyBatchRequest(batch);
      results.addAll(batchResult);
    }
    
    return results;
  }
  
  Future<List<ClassificationResult>> _classifyBatchRequest(
    List<ClassificationTask> batch,
  ) async {
    // Build prompt with all OCR texts
    final prompt = _buildBatchPrompt(batch);
    
    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${env.openRouterApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-r1-0528:free',
        'messages': [
          {
            'role': 'system',
            'content': _getBatchClassificationPrompt(),
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'response_format': {'type': 'json_object'},
        'max_tokens': 8000, // Enough for 50 classifications
      }),
    );
    
    final data = jsonDecode(response.body);
    final content = jsonDecode(data['choices'][0]['message']['content']);
    
    // Parse batch results
    return _parseBatchResults(content, batch);
  }
  
  String _buildBatchPrompt(List<ClassificationTask> batch) {
    final buffer = StringBuffer();
    buffer.writeln('Classify the following ${batch.length} OCR texts:');
    buffer.writeln();
    
    for (var i = 0; i < batch.length; i++) {
      buffer.writeln('--- Document ${i + 1} (Hash: ${batch[i].hash}) ---');
      buffer.writeln(batch[i].ocrText);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  String _getBatchClassificationPrompt() {
    return '''
You are a document classification assistant.
You will receive multiple OCR texts. Classify each one into one of these types:
- bank_receipt
- pos_receipt
- digital_wallet_receipt
- invoice
- bill
- shopping_order

Return a JSON object with this structure:
{
  "results": [
    {
      "hash": "document_hash_1",
      "document_type": "pos_receipt",
      "confidence": 0.87,
      "category": "food",
      "merchant_name": "McDonald's",
      "transaction_date": "2025-01-12",
      "transaction_time": "14:32",
      "amount": 1450,
      "currency": "PKR",
      "payment_method": "card",
      "transaction_id": null,
      "tax_amount": null
    },
    {
      "hash": "document_hash_2",
      ...
    }
  ]
}

For each document, extract all available fields. If a field is not present, use null.
Never hallucinate or guess missing data.
''';
  }
  
  List<ClassificationResult> _parseBatchResults(
    Map<String, dynamic> json,
    List<ClassificationTask> batch,
  ) {
    final results = <ClassificationResult>[];
    final resultsList = json['results'] as List;
    
    for (var i = 0; i < resultsList.length; i++) {
      final resultJson = resultsList[i] as Map<String, dynamic>;
      results.add(ClassificationResult.fromJson(resultJson));
    }
    
    return results;
  }
}
```

**Performance Improvement with Batching:**

| Approach | API Requests | Time (with $10 deposit) | Speed Improvement |
|----------|--------------|------------------------|-------------------|
| **One-by-one** | 10,000 requests | 10 days (1,000/day) | Baseline |
| **Batch (50 per request)** | 200 requests | **1 day** (200/day) | **10x faster** |
| **Batch (100 per request)** | 100 requests | **1 day** (100/day) | **10x faster** |

**New Timeline (10,000 images with batching):**

```
With 50 documents per request:
- 10,000 images ÷ 50 = 200 API requests
- At 20 req/min: 200 ÷ 20 = 10 minutes per batch cycle
- With 1,000/day limit: Can process all 200 requests in 1 day!
- Total time: ~1 day (instead of 10 days)
```

**Updated Classification Worker with Batching:**

```dart
class ClassificationWorker {
  final ClassificationQueue _queue;
  final RateLimitManager _rateLimiter;
  final BatchClassificationService _batchService;
  static const int BATCH_SIZE = 50;
  bool _isRunning = false;
  
  Future<void> start() async {
    _isRunning = true;
    while (_isRunning) {
      // Collect batch of tasks
      final batch = await _collectBatch(BATCH_SIZE);
      
      if (batch.isEmpty) {
        await Future.delayed(Duration(seconds: 1));
        continue;
      }
      
      // Check rate limits (1 request for entire batch!)
      final canProcess = await _rateLimiter.checkAndWait();
      if (!canProcess) {
        // Re-queue batch
        for (final task in batch) {
          await _queue.enqueue(task, priority: 1);
        }
        await Future.delayed(Duration(minutes: 60));
        continue;
      }
      
      // Process entire batch in one API call
      await _processBatch(batch);
    }
  }
  
  Future<List<ClassificationTask>> _collectBatch(int size) async {
    final batch = <ClassificationTask>[];
    while (batch.length < size) {
      final task = await _queue.dequeue();
      if (task == null) break;
      batch.add(task);
    }
    return batch;
  }
  
  Future<void> _processBatch(List<ClassificationTask> batch) async {
    try {
      // Single API call for entire batch
      final results = await _batchService.classifyBatch(batch);
      
      // Store all results
      for (var i = 0; i < batch.length; i++) {
        await db.updateClassificationResult(
          batch[i].hash,
          results[i],
        );
        
        // Queue for server sync
        syncToServer(batch[i].hash, batch[i].ocrText, results[i])
            .catchError((error) {
          markAsUnsynced(batch[i].hash);
        });
      }
      
    } catch (e) {
      // Re-queue batch on error
      for (final task in batch) {
        await _queue.enqueue(task, priority: 1);
      }
    }
  }
}
```

**Key Benefits:**
- ✅ **10x fewer API requests** (200 instead of 10,000)
- ✅ **10x faster processing** (1 day instead of 10 days)
- ✅ **Same rate limits** (20 req/min, 1,000/day)
- ✅ **More efficient** (one API call processes 50 documents)

**Optimal Batch Size:**
- **50 documents/request**: Good balance (200 requests for 10K images)
- **100 documents/request**: Even better (100 requests), but may hit token limits
- **Test and adjust** based on OCR text length and API response limits

### Handling Large-Scale Processing with Rate Limits

**Strategy 1: Smart Prioritization**
```dart
// Prioritize new screenshots over old gallery images
class SmartQueue {
  Future<void> prioritizeNewImages() async {
    // New screenshots (last 24 hours): Priority 10
    // Recent images (last week): Priority 5
    // Old images: Priority 1
    
    await db.updateQueuePriority(
      where: 'created_at > ?',
      priority: 10,
      args: [DateTime.now().subtract(Duration(days: 1))],
    );
  }
}
```

**Strategy 2: User Feedback**
- Show progress: "1,000/10,000 classified (1,000/day limit)"
- Estimate completion: "~9 days remaining"
- Allow pause/resume
- Show which images are pending classification

**Strategy 3: Background Processing**
- Process classification queue in background
- Continue even when app is closed (if possible)
- Resume on app launch
- Notify user when daily limit reached

**Strategy 4: Alternative for Unlimited Processing**
If daily limits are too restrictive, consider:
- **Ollama (local LLM)**: Unlimited free processing (requires server setup)
- **Multiple API keys**: Won't help (limits are per account, not per key)
- **Paid tier**: Check OpenRouter pricing for higher limits

**Recommended Approach:**
1. **Deposit $10** to OpenRouter (one-time) → 1,000/day limit
2. **Process new screenshots first** (priority queue)
3. **Background processing** for old gallery images
4. **User sees progress** and understands timeline
5. **10 days** to process 10,000 images (acceptable for initial scan)

---

## Cost Analysis

### Client-Side Costs

| Component | Cost | Notes |
|-----------|------|-------|
| Google ML Kit OCR | $0 | Free, on-device |
| Local SQLite Database | $0 | Free, built into Flutter |
| Image Hashing | $0 | Free, open-source libraries |
| **Total Client Cost** | **$0** | |

### Server-Side Costs

#### Option 1: Self-Hosted (Recommended for $0)

**Requirements:**
- PostgreSQL database (can run on same server)
- Serverpod server (Dart runtime)
- Minimal resources (only stores metadata)

**Cost Breakdown:**
- Server: $0 (if you have existing server)
- Database: $0 (PostgreSQL is free)
- **Total: $0**

**Recommended Setup:**
- VPS: $5-10/month (DigitalOcean, Linode, etc.)
- Or use existing infrastructure

#### Option 2: Cloud Hosted

**AWS/GCP/Azure:**
- Database: $10-20/month (small PostgreSQL instance)
- Compute: $10-20/month (small server)
- **Total: $20-40/month**

**Serverpod Cloud (if available):**
- Check Serverpod pricing
- Likely $10-30/month

### API Costs

| Service | Free Tier | Paid Tier |
|---------|-----------|-----------|
| OpenRouter (DeepSeek R1) | $0 (free model) | N/A |
| **Total API Cost** | **$0** | |

### Total System Cost

| Scenario | Monthly Cost |
|----------|--------------|
| Self-hosted | $0-10 |
| Cloud-hosted | $20-40 |
| **With $10 OpenRouter deposit** | **+$10 one-time** |

**Recommendation:**
- Start with self-hosted: **$0/month**
- Move to cloud if needed: **$20-40/month**
- OpenRouter deposit (optional): **$10 one-time** (increases daily limit)

---

## Performance Optimizations

### 1. Batch Operations

**Database:**
```dart
// Instead of individual inserts
for (final image in images) {
  await db.insert(image); // Slow: N queries
}

// Use batch insert
await db.batchInsert(images); // Fast: 1 query
```

**API Calls:**
```dart
// Batch classification requests (if API supports)
final results = await classificationService.classifyBatch(ocrTexts);
```

### 2. Parallel Processing

```dart
// Process multiple images concurrently
final results = await Future.wait(
  images.take(5).map((img) => processImage(img)),
);
```

**Considerations:**
- Limit concurrency (don't overload device)
- Respect API rate limits
- Monitor memory usage

### 3. Caching

```dart
class ClassificationCache {
  final Map<String, ClassificationResult> _cache = {};
  
  Future<ClassificationResult> classify(String ocrText) async {
    final hash = sha256.convert(utf8.encode(ocrText)).toString();
    
    if (_cache.containsKey(hash)) {
      return _cache[hash]!;
    }
    
    final result = await classificationService.classify(ocrText);
    _cache[hash] = result;
    return result;
  }
}
```

### 4. Smart Queue Prioritization

```dart
class SmartQueue {
  Future<void> prioritizeNewImages() async {
    // New screenshots: priority 10
    // Recent images: priority 5
    // Old images: priority 1
    
    await db.updateQueuePriority(
      where: 'created_at > ?',
      priority: 10,
      args: [DateTime.now().subtract(Duration(days: 1))],
    );
  }
}
```

### 5. Incremental Sync

```dart
// Only sync new/updated records
Future<void> syncIncremental() async {
  final unsynced = await db.getUnsyncedImages(limit: 100);
  if (unsynced.isEmpty) return;
  
  await serverpodClient.syncBatch(unsynced);
  await db.markAsSynced(unsynced.map((img) => img.id).toList());
}
```

### 6. Progress Tracking

```dart
class ProgressTracker {
  int total = 0;
  int processed = 0;
  int skipped = 0;
  int failed = 0;
  
  Stream<ProgressUpdate> get progress => _progressController.stream;
  
  void update(int processed, int skipped, int failed) {
    _progressController.add(ProgressUpdate(
      processed: processed,
      skipped: skipped,
      failed: failed,
      total: total,
      percentage: (processed / total * 100).round(),
    ));
  }
}
```

---

## Implementation Checklist

### Phase 1: Foundation (Week 1)

- [ ] Set up Flutter project structure
- [ ] Add dependencies:
  - [ ] `sqflite` (local database)
  - [ ] `google_mlkit_text_recognition` (OCR)
  - [ ] `image_hash` or `dart_imagehash` (hashing)
  - [ ] `crypto` (metadata hashing)
  - [ ] `serverpod_client` (server communication)
- [ ] Create local database schema
- [ ] Implement database helper classes
- [ ] Set up basic UI structure

### Phase 2: Core Features (Week 2)

- [ ] Implement image hash generation (perceptual + metadata)
- [ ] Implement already-processed detection
- [ ] Integrate Google ML Kit OCR
- [ ] Create OCR service with error handling
- [ ] Implement local storage (SQLite)
- [ ] Build processing queue system
- [ ] Add progress tracking UI

### Phase 3: Classification (Week 3)

- [ ] Set up Serverpod backend
- [ ] Create Serverpod schema for processed images
- [ ] Implement OpenRouter API integration
- [ ] Create classification endpoint
- [ ] Implement rate limit management
- [ ] Add retry logic for failed classifications
- [ ] Parse and store classification results

### Phase 4: Gallery Processing (Week 4)

- [ ] Implement gallery scanner
- [ ] Build batch processing system
- [ ] Add pause/resume functionality
- [ ] Implement background processing
- [ ] Create progress UI with statistics
- [ ] Add error handling and recovery
- [ ] Optimize for large galleries (10,000+ images)

### Phase 5: Sync & Search (Week 5)

- [ ] Implement server sync (incremental)
- [ ] Add sync queue for failed syncs
- [ ] Create search functionality (local + server)
- [ ] Build filter UI (by type, date, category)
- [ ] Implement full-text search over OCR text
- [ ] Add export functionality

### Phase 6: Polish & Testing (Week 6)

- [ ] Add user corrections UI
- [ ] Implement re-classification after edits
- [ ] Add confidence indicators
- [ ] Create detailed view for processed images
- [ ] Performance testing (10,000+ images)
- [ ] Error handling improvements
- [ ] UI/UX polish
- [ ] Documentation

---

## Key Metrics & Targets

### Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Hash generation | < 50ms | Per image |
| OCR processing | < 2s | Per image (depends on size) |
| Classification API | < 5s | Including network |
| Database lookup | < 10ms | Hash check |
| Total per image | < 8s | End-to-end |
| Gallery scan (10K) | < 2 hours | Background processing |

### Accuracy Targets

| Metric | Target |
|--------|--------|
| Classification accuracy | > 85% |
| OCR accuracy | > 90% (for clear images) |
| Duplicate detection | > 99% |

### Resource Usage

| Resource | Target |
|----------|--------|
| Local database size | < 100 MB (for 10K images) |
| Memory usage | < 200 MB (during processing) |
| Battery impact | Minimal (background processing) |

---

## Security & Privacy

### Data Privacy

- ✅ **Images never leave device** (OCR on-device)
- ✅ **Only OCR text sent to server** (no visual data)
- ✅ **Hashes are one-way** (cannot reconstruct image)
- ✅ **User data encrypted** (in transit and at rest)
- ✅ **Local database encrypted** (SQLite encryption)

### API Security

- ✅ **API keys stored securely** (environment variables)
- ✅ **Rate limiting** (prevent abuse)
- ✅ **Authentication required** (user-specific data)
- ✅ **HTTPS only** (encrypted communication)

---

## Future Enhancements

### Potential Improvements

1. **Offline Classification**
   - Train lightweight on-device model
   - Fallback when API unavailable

2. **Smart Categorization**
   - Learn from user corrections
   - Improve category assignment

3. **Export Features**
   - Export to CSV/Excel
   - Generate spending reports
   - Tax document generation

4. **Multi-Device Sync**
   - Sync across user's devices
   - Conflict resolution

5. **Advanced Search**
   - Semantic search (vector embeddings)
   - Date range queries
   - Amount filtering

---

## Authentication & User Management

### Serverpod Authentication

Serverpod provides built-in authentication modules. We'll use **email-based authentication** for simplicity:

**User Model:**
```dart
// server/lib/src/models/user.dart
class User extends Table {
  @Column()
  String email;
  
  @Column()
  String? name;
  
  @Column()
  DateTime createdAt;
  
  @Column()
  DateTime? lastLoginAt;
}
```

**Authentication Flow:**
1. User registers/logs in via Flutter app
2. Serverpod generates session token
3. All API calls include session token in headers
4. Serverpod validates session and provides `userId` in `Session` object

**Implementation:**
- Use Serverpod's `serverpod_auth_email` package
- Flutter client uses generated `client.authenticationKeyManager`
- All endpoints require authenticated `Session`

---

## API Contracts (Flutter ↔ Serverpod)

### Classification API

**Endpoint:** `ClassificationEndpoint.classifyBatch`

**Request:**
```dart
class BatchClassificationRequest {
  final List<ClassificationTask> tasks; // Up to 50 tasks
  
  BatchClassificationRequest({
    required this.tasks,
  });
}

class ClassificationTask {
  final String hash;
  final String ocrText;
  
  ClassificationTask({
    required this.hash,
    required this.ocrText,
  });
}
```

**Response:**
```dart
class BatchClassificationResponse {
  final List<ClassificationResult> results;
  
  BatchClassificationResponse({
    required this.results,
  });
}

class ClassificationResult {
  final String hash;
  final String documentType;
  final double confidence;
  final String category;
  final String? merchantName;
  final DateTime? transactionDate;
  final String? transactionTime;
  final double? amount;
  final String? currency;
  final String? paymentMethod;
  final String? transactionId;
  final double? taxAmount;
  
  // ... fromJson, toJson methods
}
```

### Sync API

**Endpoint:** `SyncEndpoint.syncProcessedImages`

**Request:**
```dart
class SyncRequest {
  final List<ProcessedImageData> images;
  final DateTime? lastSyncTimestamp;
  
  SyncRequest({
    required this.images,
    this.lastSyncTimestamp,
  });
}
```

**Response:**
```dart
class SyncResponse {
  final int syncedCount;
  final List<String> failedHashes; // Hashes that failed to sync
  final DateTime serverTimestamp;
  
  SyncResponse({
    required this.syncedCount,
    required this.failedHashes,
    required this.serverTimestamp,
  });
}
```

### Search API

**Endpoint:** `SearchEndpoint.searchImages`

**Request:**
```dart
class SearchRequest {
  final String? query; // Full-text search over OCR text
  final List<String>? documentTypes; // Filter by types
  final List<String>? categories; // Filter by categories
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final int limit;
  final int offset;
  
  SearchRequest({
    this.query,
    this.documentTypes,
    this.categories,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.limit = 50,
    this.offset = 0,
  });
}
```

**Response:**
```dart
class SearchResponse {
  final List<ProcessedImageData> results;
  final int totalCount;
  
  SearchResponse({
    required this.results,
    required this.totalCount,
  });
}
```

---

## Search Functionality

### Local Search (On-Device)

**Full-Text Search:**
- SQLite FTS5 virtual table for fast OCR text search
- Index on `ocr_text` column
- Search across all processed images instantly

**Structured Filters:**
- Filter by `document_type`, `category`, `merchant_name`
- Date range filtering (`transaction_date`, `processed_at`)
- Amount range filtering
- Combined filters (e.g., "bank receipts from last month over $100")

**Implementation:**
```sql
-- Create FTS5 virtual table for full-text search
CREATE VIRTUAL TABLE processed_images_fts USING fts5(
  ocr_text,
  merchant_name,
  content='processed_images',
  content_rowid='id'
);

-- Search query example
SELECT p.*
FROM processed_images p
JOIN processed_images_fts fts ON p.id = fts.rowid
WHERE processed_images_fts MATCH 'McDonald'
  AND p.document_type = 'pos_receipt'
  AND p.transaction_date >= '2025-01-01'
ORDER BY p.transaction_date DESC;
```

### Server Search (Cross-Device)

- Same search capabilities as local
- Searches across all user's synced images
- Useful for multi-device scenarios
- Can combine local + server results

---

## Error Handling Strategy

### Client-Side Error Handling

**OCR Errors:**
- Image too large → Resize before OCR
- No text detected → Mark as `no_text`, skip classification
- OCR fails → Log error, mark as failed, continue with next image

**Classification Errors:**
- API rate limit → Re-queue task, wait and retry
- Network error → Re-queue task, retry with exponential backoff
- Invalid response → Log error, mark classification as failed
- Parse error → Log raw response, mark as failed

**Database Errors:**
- Constraint violation (duplicate hash) → Skip, already processed
- Database locked → Retry with backoff
- Corrupt database → Backup and recreate

**Error Recovery:**
```dart
class ErrorRecovery {
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (attempt < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
    
    throw Exception('Max retries exceeded');
  }
}
```

### Server-Side Error Handling

**OpenRouter API Errors:**
- Rate limit (429) → Return rate limit error, client will retry
- Invalid API key → Log error, return authentication error
- Service unavailable → Return service error, client will retry
- Invalid response format → Log raw response, return parse error

**Database Errors:**
- Constraint violations → Return conflict error
- Connection errors → Retry with backoff
- Query timeouts → Return timeout error

---

## Sync Strategy

### Incremental Sync

**Strategy:**
- Only sync new/updated records since last sync
- Track `last_sync_timestamp` per device
- Server returns `serverTimestamp` for next sync

**Sync Flow:**
1. Client queries local DB for `synced_to_server = 0` OR `processed_at > last_sync_timestamp`
2. Sends batch of unsynced records to server
3. Server validates and stores records
4. Server returns `serverTimestamp` and list of successfully synced hashes
5. Client marks records as `synced_to_server = 1`
6. Client updates `last_sync_timestamp`

**Conflict Resolution:**
- If server has newer version (by `processed_at`), server wins
- If client has newer version, client wins
- User corrections always take precedence

**Sync Queue:**
- Failed syncs go to `sync_queue` table
- Retry with exponential backoff
- Manual "retry sync" option in UI

---

## Deployment & Environment Setup

### Serverpod Backend Deployment

**Requirements:**
- PostgreSQL database (version 12+)
- Dart runtime (Dart SDK 3.0+)
- Serverpod server (can run on VPS, cloud, or Docker)

**Environment Variables:**
```bash
# .env file
OPENROUTER_API_KEY=sk-or-v1-...
DATABASE_URL=postgresql://user:pass@localhost:5432/receipt_sorter
REDIS_URL=redis://localhost:6379  # Optional, for caching
SERVER_SECRET_KEY=...  # For session encryption
```

**Deployment Options:**
1. **Self-Hosted VPS** (DigitalOcean, Linode, etc.)
   - Install Dart SDK
   - Run Serverpod server
   - Set up PostgreSQL
   - Use systemd for service management

2. **Docker Deployment**
   - Use Serverpod's Docker setup
   - Deploy to any container platform

3. **Cloud Platforms**
   - AWS (EC2, ECS)
   - Google Cloud (Compute Engine, Cloud Run)
   - Azure (App Service, Container Instances)

### Flutter App Deployment

**Android:**
- Build APK/AAB with release configuration
- Sign with release keystore
- Upload to Google Play Store

**iOS:**
- Build with Xcode
- Archive and upload to App Store Connect
- Configure App Store metadata

**Environment Configuration:**
- Use `flutter_dotenv` or build-time configuration
- Store Serverpod server URL
- Store API endpoints

---

## Complete Batch Classification Prompt

This is the **full prompt** to use for batch classification (50 documents per request):

```dart
String getBatchClassificationPrompt() {
  return '''
You are a document classification and information extraction assistant operating inside a personal screenshot management system.

You receive OCR-extracted plain text from MULTIPLE images (screenshots, receipts, or documents) in a single request.

Your task is to classify EACH screenshot and extract structured information where applicable.

You do NOT see the images. You only see OCR text, which may be noisy, incomplete, misordered, or partially incorrect.

You must prioritize accuracy, restraint, and explainability over guessing.

## CLASSIFICATION (MANDATORY FOR EACH DOCUMENT)

Classify each screenshot into exactly ONE of the following types:
- bank_receipt
- pos_receipt
- digital_wallet_receipt
- invoice
- bill
- shopping_order
- unknown (if confidence < 0.6 or outside these types)

## CATEGORY ASSIGNMENT (MANDATORY FOR EACH DOCUMENT)

Assign ONE spending or content category if applicable:
- food, transport, shopping, utilities, subscriptions, entertainment, health, education, business, personal, other

If the screenshot is NOT financial, use: personal, business, or other

Do NOT invent categories.

## FIELD EXTRACTION (CONDITIONAL FOR EACH DOCUMENT)

Only extract fields if the document type supports them and they are explicitly present:

Financial Documents May Include:
- merchant_name
- transaction_date (format: YYYY-MM-DD)
- transaction_time (format: HH:MM, 24-hour)
- amount (numeric, smallest currency unit)
- currency (e.g. PKR, USD, EUR)
- payment_method (e.g. cash, card, digital_wallet)
- transaction_id
- tax_amount

If a field is NOT explicitly present, return null.

CRITICAL RULES:
- Never infer numeric values
- Never fabricate dates, amounts, or merchant names
- Never guess missing data
- If text is too short or ambiguous, use document_type = "unknown"

## OUTPUT FORMAT

Return ONLY valid JSON with this exact structure:

{
  "results": [
    {
      "hash": "document_hash_string",
      "document_type": "pos_receipt",
      "confidence": 0.87,
      "category": "food",
      "merchant_name": "McDonald's",
      "transaction_date": "2025-01-12",
      "transaction_time": "14:32",
      "amount": 1450,
      "currency": "PKR",
      "payment_method": "card",
      "transaction_id": null,
      "tax_amount": null,
      "notes": null
    },
    {
      "hash": "next_document_hash",
      ...
    }
  ]
}

For each document in the input, provide one entry in the "results" array.
Use the "hash" field to match each result to its corresponding input document.

If confidence is below 0.6, set document_type to "unknown" and confidence to the actual value.
''';
}
```

---

## Testing Strategy

### Unit Tests

**Client-Side:**
- Hash generation (metadata, perceptual)
- OCR text processing (normalization, cleaning)
- Database operations (CRUD, queries)
- Queue management
- Error handling

**Server-Side:**
- Classification endpoint
- Rate limit manager
- Batch processing
- Database operations

### Integration Tests

**End-to-End Flow:**
1. Image → Hash → OCR → Classification → Storage
2. Gallery scan → Processing → Album display
3. Sync → Server → Conflict resolution

### Performance Tests

**Targets:**
- Process 100 images in < 5 minutes
- Process 1,000 images in < 30 minutes
- Process 10,000 images in < 2 hours (OCR only)
- Database queries < 50ms for album views

### Test Data

**Create test dataset:**
- 50+ sample images (bank receipts, POS receipts, invoices, etc.)
- Known expected classifications
- Edge cases (no text, very long text, ambiguous types)

---

## Conclusion

This architecture provides:

✅ **Zero bandwidth waste** (no image uploads)  
✅ **Zero server processing costs** (OCR on-device)  
✅ **Scalable** (handles 10,000+ images)  
✅ **Fast duplicate detection** (hash-based)  
✅ **Cost-effective** ($0-10/month)  
✅ **Privacy-focused** (images stay on device)  
✅ **User-friendly** (progress tracking, pause/resume)  

The system is designed to be **production-ready**, **scalable**, and **cost-effective** while maintaining **privacy** and **performance**.
