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
      where: (t) => userId != null ? t.userId.equals(userId) : Constant.bool(true),
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
