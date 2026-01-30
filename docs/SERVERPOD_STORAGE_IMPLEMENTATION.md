# Serverpod Storage Implementation Plan

## Objective
Add server-side data persistence to meet hackathon requirements for Serverpod + AI integration.

## Current State
- ✅ AI Classification working (OpenRouter LLM)
- ✅ Local SQLite storage on phone
- ❌ No server-side data persistence

## Target State
- ✅ Serverpod database models
- ✅ Receipt storage in Postgres
- ✅ Server-side search endpoints
- ✅ Client-server sync after classification

---

## Implementation Steps

### Phase 1: Create Serverpod Models (30 min)

#### 1.1 Create Receipt Model
**File:** `receipt_backend_server/lib/src/models/receipt.spy.yaml`

```yaml
class: Receipt
table: receipts
fields:
  id: int?, autoIncrement
  userId: int?  # For multi-user support later
  filePath: String
  metadataHash: String, index
  assetId: String?
  
  # OCR Data
  ocrText: String?
  
  # Classification Results (from AI)
  documentType: String?
  category: String?
  merchantName: String?
  senderName: String?
  recipientName: String?
  totalAmount: double?
  currency: String?
  transactionType: String?
  transactionDate: DateTime?
  
  # Metadata
  processedAt: DateTime
  processingStatus: String
  
  # Future: Embeddings for RAG
  # embedding: String?  # JSON array or use pgvector extension
```

#### 1.2 Generate Code
```bash
cd receipt_backend/receipt_backend_server
dart run serverpod generate
```

#### 1.3 Create Database Migration
```bash
dart run serverpod create-migration
```

#### 1.4 Apply Migration
```bash
# Stop server (Ctrl+C)
dart run bin/main.dart --apply-migrations
```

---

### Phase 2: Create Receipt Endpoint (1 hour)

#### 2.1 Create Endpoint File
**File:** `receipt_backend_server/lib/src/endpoints/receipt_endpoint.dart`

```dart
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class ReceiptEndpoint extends Endpoint {
  
  /// Store a receipt after classification
  Future<Receipt> storeReceipt(Session session, Receipt receipt) async {
    return await Receipt.db.insertRow(session, receipt);
  }
  
  /// Batch store multiple receipts
  Future<List<Receipt>> storeReceipts(Session session, List<Receipt> receipts) async {
    final stored = <Receipt>[];
    for (var receipt in receipts) {
      try {
        final result = await Receipt.db.insertRow(session, receipt);
        stored.add(result);
      } catch (e) {
        session.log('Failed to store receipt: $e', level: LogLevel.warning);
      }
    }
    return stored;
  }
  
  /// Get all receipts for a user
  Future<List<Receipt>> getUserReceipts(
    Session session, {
    int? userId,
    int limit = 100,
    int offset = 0,
  }) async {
    return await Receipt.db.find(
      session,
      where: (t) => userId != null ? t.userId.equals(userId) : null,
      orderBy: (t) => t.processedAt,
      orderDescending: true,
      limit: limit,
      offset: offset,
    );
  }
  
  /// Search receipts by text
  Future<List<Receipt>> searchReceipts(
    Session session,
    String query, {
    int? userId,
  }) async {
    return await Receipt.db.find(
      session,
      where: (t) {
        var condition = t.ocrText.like('%$query%') | 
                       t.merchantName.like('%$query%') |
                       t.category.like('%$query%');
        if (userId != null) {
          condition = condition & t.userId.equals(userId);
        }
        return condition;
      },
      orderBy: (t) => t.processedAt,
      orderDescending: true,
    );
  }
  
  /// Get receipt by hash (for deduplication)
  Future<Receipt?> getReceiptByHash(Session session, String metadataHash) async {
    final results = await Receipt.db.find(
      session,
      where: (t) => t.metadataHash.equals(metadataHash),
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }
  
  /// Get receipts by date range
  Future<List<Receipt>> getReceiptsByDateRange(
    Session session,
    DateTime startDate,
    DateTime endDate, {
    int? userId,
  }) async {
    return await Receipt.db.find(
      session,
      where: (t) {
        var condition = t.transactionDate.between(startDate, endDate);
        if (userId != null) {
          condition = condition & t.userId.equals(userId);
        }
        return condition;
      },
      orderBy: (t) => t.transactionDate,
      orderDescending: true,
    );
  }
}
```

#### 2.2 Update Classification Endpoint
**File:** `receipt_backend_server/lib/src/classification/classification_endpoint.dart`

Add storage after classification:

```dart
// After generating results, store them
for (var result in results) {
  try {
    final receipt = Receipt(
      metadataHash: result.hash,
      ocrText: tasks.firstWhere((t) => t.hash == result.hash).ocrText,
      documentType: result.documentType,
      category: result.category,
      merchantName: result.merchantName,
      senderName: result.senderName,
      recipientName: result.recipientName,
      totalAmount: result.totalAmount,
      currency: result.currency,
      transactionType: result.transactionType,
      transactionDate: result.transactionDate,
      processedAt: DateTime.now(),
      processingStatus: 'completed',
      filePath: '', // Will be synced from client later
    );
    
    await Receipt.db.insertRow(session, receipt);
    session.log('Stored receipt: ${result.hash}');
  } catch (e) {
    session.log('Failed to store receipt ${result.hash}: $e', level: LogLevel.warning);
  }
}
```

---

### Phase 3: Update Client Sync (30 min)

#### 3.1 Add Sync After Classification
**File:** `lib/services/classification_service.dart`

After updating local database, optionally sync to server:

```dart
// After db.update in processQueue()
try {
  // Optional: Upload to server for cloud backup
  final receipt = Receipt(
    metadataHash: result.hash,
    filePath: '', // Add if needed
    ocrText: img.ocrText,
    documentType: result.documentType,
    category: result.category,
    merchantName: result.merchantName,
    senderName: result.senderName,
    recipientName: result.recipientName,
    totalAmount: result.totalAmount,
    currency: result.currency,
    transactionType: result.transactionType,
    transactionDate: result.transactionDate,
    processedAt: DateTime.now(),
    processingStatus: 'completed',
  );
  
  await ApiService().client.receipt.storeReceipt(receipt);
  debugPrint('[Sync] Uploaded receipt to server: ${result.hash}');
} catch (e) {
  debugPrint('[Sync] Failed to upload receipt: $e');
  // Don't fail the whole process if sync fails
}
```

---

## Demo Script for Judges

### 1. **Show the Problem**
"Managing receipts is tedious. People lose them, can't search them, and manual categorization is time-consuming."

### 2. **Show OCR**
"Our app uses Google ML Kit to extract text from receipt photos automatically."

### 3. **Show AI Classification**
"We send the OCR text to our Serverpod backend, which uses OpenRouter's LLM to intelligently classify receipts - extracting merchant names, amounts, dates, and categories."

### 4. **Show Database**
"All classified receipts are stored in Postgres via Serverpod's ORM, enabling:"
- Multi-device sync
- Server-side search
- Analytics and insights
- Future RAG capabilities

### 5. **Show Search**
"Users can search their receipts semantically - 'food expenses last month' - powered by our Serverpod backend."

### 6. **Future Vision**
"We're ready to add pgvector embeddings for true semantic search and RAG-powered insights like 'How much did I spend on restaurants this quarter?'"

---

## Testing Checklist

- [ ] Receipt model generated successfully
- [ ] Migration applied to database
- [ ] Server starts without errors
- [ ] Classification endpoint stores receipts
- [ ] Receipt endpoint returns stored data
- [ ] Client can query receipts from server
- [ ] Search functionality works
- [ ] No duplicate receipts (hash check)

---

## Future Enhancements (Post-Hackathon)

1. **RAG Integration**
   - Add pgvector extension to Postgres
   - Generate embeddings for each receipt
   - Implement semantic search endpoint

2. **Multi-User Support**
   - Add Serverpod Auth
   - User-specific receipt filtering
   - Sharing and collaboration features

3. **Analytics Dashboard**
   - Spending trends
   - Category breakdowns
   - Merchant analytics

4. **Mobile Optimizations**
   - Offline-first with sync queue
   - Conflict resolution
   - Background sync

---

## Notes

- Keep local SQLite as cache for offline access
- Server storage enables cloud features
- This architecture satisfies hackathon requirements while maintaining good UX
