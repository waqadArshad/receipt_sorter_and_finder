import 'package:flutter/foundation.dart';
import 'package:receipt_backend_client/receipt_backend_client.dart';
import '../../db/database_helper.dart';
import '../../models/processed_image.dart';
import 'api_service.dart';

class ClassificationService {
  static final ClassificationService _instance = ClassificationService._internal();
  factory ClassificationService() => _instance;
  ClassificationService._internal();

  bool _isProcessing = false;

  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final db = await DatabaseHelper.instance.database;
      
      // 1. Fetch pending items
      final pendingRows = await db.query(
        'processed_images',
        where: 'processing_status = ?',
        whereArgs: [ProcessingStatus.ocrComplete.name],
        limit: 10, // Batch size
      );

      if (pendingRows.isEmpty) return;

      final tasks = <ClassificationTask>[];
      final hashes = <String>[];

      for (var row in pendingRows) {
        final img = ProcessedImage.fromMap(row);
        if (img.ocrText != null && img.metadataHash != null) {
          // Use metadata hash as ID for now, or combine
          // Ideally use the consistent hash we agreed on (perceptual or metadata)
          tasks.add(ClassificationTask(
            hash: img.metadataHash!, 
            ocrText: img.ocrText!,
          ));
          hashes.add(img.metadataHash!);
        }
      }

      if (tasks.isEmpty) return;

      // 2. Call API
      // Mark as in progress locally (optional, but good for UI)
       // ... update DB status to 'classificationInProgress' ...

      try {
        final response = await ApiService().client.classification.classifyBatch(tasks);
        
        // 3. Process results
        for (var result in response.results) {
           await db.update(
            'processed_images',
            {
              'processing_status': ProcessingStatus.completed.name, // or completed
              'document_type': result.documentType,
              'category': result.category,
              'merchant_name': result.merchantName,
              'amount': result.totalAmount,
              // 'transaction_date': result.transactionDate, 
            },
            where: 'metadata_hash = ?', // Matching by hash
            whereArgs: [result.hash],
          );
        }
      } catch (e) {
        debugPrint('API Error: $e');
        // Mark failed? Or retry later?
        // Leaving as is for retry next time
      }

    } finally {
      _isProcessing = false;
    }
  }
}
