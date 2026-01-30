import 'package:flutter/foundation.dart';
import 'package:receipt_backend_client/receipt_backend_client.dart';
import '../../db/database_helper.dart';
import '../../models/processed_image.dart';
import 'api_service.dart';
import 'receipt_validator.dart';

class ClassificationService {
  static final ClassificationService _instance = ClassificationService._internal();
  factory ClassificationService() => _instance;
  ClassificationService._internal();

  bool _isProcessing = false;

  Future<int> processQueue() async {
    if (_isProcessing) return 0;
    _isProcessing = true;
    int processedCount = 0;

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch pending items
      final pendingRows = await db.query(
        'processed_images',
        where: 'processing_status = ?',
        whereArgs: [ProcessingStatus.ocrComplete.name],
        limit: 10,
      );

      if (pendingRows.isEmpty) {
        debugPrint('[Classification] No pending items found.');
        return 0;
      }
      
      debugPrint('[Classification] Check batch of ${pendingRows.length} items...');

      final tasks = <ClassificationTask>[];
      final hashes = <String>[];

      for (var row in pendingRows) {
        final img = ProcessedImage.fromMap(row);
        if (img.ocrText != null && img.metadataHash != null) {
          // SAFETY CHECK
          if (!ReceiptValidator.isValidReceipt(img.ocrText!)) {
            debugPrint('[Classification] Safety Rejection: ${img.id}');
            await db.update(
              'processed_images',
              {'processing_status': ProcessingStatus.skipped.name},
              where: 'id = ?',
              whereArgs: [img.id],
            );
            continue; 
          }

          tasks.add(ClassificationTask(hash: img.metadataHash!, ocrText: img.ocrText!));
          hashes.add(img.metadataHash!);
        }
      }

      if (tasks.isEmpty) {
         debugPrint('[Classification] All items in batch were rejected as invalid.');
         return 0;
      }

      // 2. Mark as in progress
      debugPrint('[Classification] Sending ${tasks.length} valid receipts to Backend...');
      for (var hash in hashes) {
        await db.update(
          'processed_images',
          {'processing_status': ProcessingStatus.classificationInProgress.name},
          where: 'metadata_hash = ?',
          whereArgs: [hash],
        );
      }

      // 3. Call API
      try {
        final stopwatch = Stopwatch()..start();
        final response = await ApiService().client.classification.classifyBatch(tasks);
        stopwatch.stop();

        debugPrint('[Classification] Backend responded in ${stopwatch.elapsedMilliseconds}ms. Results: ${response.results.length}');

        // 4. Process results
        for (var result in response.results) {
          processedCount++;
          await db.update(
            'processed_images',
            {
              'processing_status': ProcessingStatus.completed.name,
              'document_type': result.documentType,
              'category': result.category,
              'merchant_name': result.merchantName,
              'sender_name': result.senderName,
              'recipient_name': result.recipientName,
              'amount': result.totalAmount,
              'currency': result.currency,
              'transaction_type': result.transactionType,
              'transaction_date': result.transactionDate?.toIso8601String(),
            },
            where: 'metadata_hash = ?',
            whereArgs: [result.hash],
          );
        }
      } catch (e) {
        debugPrint('[Classification] API Error: $e');
        // REVERT statuses to ocrComplete so they can be retried later? 
        // Or mark failed? marking failed is safer to avoid loops.
        // Actually, if connection refused, we might want to retry later.
        // For now, mark failed so user sees it in Trash/Failed tab.
        for (var hash in hashes) {
          await db.update(
            'processed_images',
            {'processing_status': ProcessingStatus.failed.name},
            where: 'metadata_hash = ?',
            whereArgs: [hash],
          );
        }
        rethrow; // Pass error up to UI
      }
    } finally {
      _isProcessing = false;
    }
    return processedCount;
  }
  // --------------------------------------------------------------------------
  // SYNC: Fetch classified data from Server and update local records
  // --------------------------------------------------------------------------
  Future<int> syncWithServer() async {
    try {
      debugPrint('[Sync] Starting synchronization with server...');
      
      // Fetch latest 500 receipts from server
      // (This assumes we are the only user, or userId logic is handled)
      final serverReceipts = await ApiService().client.receipt.getUserReceipts(limit: 500, offset: 0);
      
      if (serverReceipts.isEmpty) {
        debugPrint('[Sync] Server has no receipts to sync.');
        return 0;
      }

      int syncedCount = 0;
      final db = await DatabaseHelper.instance.database;

      // Batch update local DB
      await db.transaction((txn) async {
        for (var receipt in serverReceipts) {
          if (receipt.metadataHash == null) continue;

          // Check if we have this image locally (by hash)
          final localRows = await txn.query(
            'processed_images',
            columns: ['id', 'processing_status'],
            where: 'metadata_hash = ?',
            whereArgs: [receipt.metadataHash],
          );

          if (localRows.isNotEmpty) {
            final row = localRows.first;
            final currentStatus = row['processing_status'] as String;

            // Only update if local is NOT completed, OR we want to force refresh
            // Let's safe-guard: Update if local is processing, pending, OR failed
            // But also, if it IS completed, maybe server has better data (e.g. edited elsewhere)?
            // For now, let's sync EVERYTHING to ensure consistency.
            
            await txn.update(
              'processed_images',
              {
                'processing_status': ProcessingStatus.completed.name, // Force complete
                'document_type': receipt.documentType,
                'category': receipt.category,
                'merchant_name': receipt.merchantName,
                'sender_name': receipt.senderName,
                'recipient_name': receipt.recipientName,
                'amount': receipt.totalAmount,
                'currency': receipt.currency,
                'transaction_type': receipt.transactionType,
                'transaction_date': receipt.transactionDate?.toIso8601String(),
                'is_synced': 1, // Mark as synced
              },
              where: 'metadata_hash = ?',
              whereArgs: [receipt.metadataHash],
            );
            syncedCount++;
          }
        }
      });
      
      debugPrint('[Sync] Synced $syncedCount receipts from server.');
      return syncedCount;
    } catch (e) {
      debugPrint('[Sync] Failed to sync: $e');
      // Use rethrow? Or just silence it so UI doesn't crash?
      // Silence it, as this is a background optimization.
      return 0;
    }
  }
}
