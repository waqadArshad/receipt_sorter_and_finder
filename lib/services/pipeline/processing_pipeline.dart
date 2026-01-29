
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../db/database_helper.dart';
import '../../models/processed_image.dart';
import '../image_hash_service.dart';
import '../receipt_validator.dart';
import '../ocr_service.dart';

import '../classification_service.dart';

class ProcessingPipeline {
  static final ProcessingPipeline _instance = ProcessingPipeline._internal();
  factory ProcessingPipeline() => _instance;
  ProcessingPipeline._internal();

  final _dbHelper = DatabaseHelper.instance;
  final _hashService = ImageHashService();
  final _ocrService = OCRService();
  final _classificationService = ClassificationService();

  // Reporting progress (0.0 to 1.0)
  final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
  
  // Simple in-memory flag to control processing loop
  bool _isProcessing = false;

  /// Starts processing the provided list of gallery assets.
  /// Runs in the background (asynchronous loop) with throttling.
  Future<void> processAssets(List<AssetEntity> assets) async {
    if (_isProcessing) return; 
    _isProcessing = true;
    progressNotifier.value = 0.0;

    final stopwatch = Stopwatch()..start();
    int processedCount = 0;
    int totalCount = assets.length;

    debugPrint('[Performance] Starting batch processing of $totalCount assets');

    try {
      for (final asset in assets) {
        if (!_isProcessing) break; 

        // 1. Get File (Required for hash)
        // Note: asset.file is generally fast but can be slow if cloud-synced
        final file = await asset.file;
        if (file == null) {
          processedCount++;
          continue;
        }

        // 2. Generate Hashes (Fast metadata only)
        final hashes = await _hashService.generateHashes(file);

        // 3. Fast Duplicate Check
        final db = await _dbHelper.database;
        final List<Map<String, dynamic>> existing = await db.query(
          'processed_images',
          where: 'metadata_hash = ?',
          whereArgs: [hashes.metadataHash],
          limit: 1,
        );

        // SKIP DUPLICATES INSTANTLY (No Throttling)
        if (existing.isNotEmpty) {
           processedCount++;
           // Only update UI occasionally for duplicates to avoid flooding
           if (processedCount % 50 == 0) {
              progressNotifier.value = processedCount / totalCount;
           }
           continue; 
        }

        // --- NEW ITEM FOUND ---
        
        // NOW we throttle, because we are about to do heavy work
        await Future.delayed(const Duration(milliseconds: 100)); // Generous throttle for OCR
        
        final itemStopwatch = Stopwatch()..start();

        // 4. Create initial DB entry
        final newImage = ProcessedImage(
          filePath: file.absolute.path,
          metadataHash: hashes.metadataHash,
          perceptualHash: hashes.perceptualHash,
          assetId: asset.id,
          processedAt: DateTime.now(),
          processingStatus: ProcessingStatus.hashing, 
        );
        
        final id = await db.insert('processed_images', newImage.toMap());
        
        // 5. Run OCR
        try {
          final ocrText = await _ocrService.extractText(file);
          
          // 6. Validate Text
          final isValid = ReceiptValidator.isValidReceipt(ocrText);
          final nextStatus = isValid ? ProcessingStatus.ocrComplete : ProcessingStatus.skipped;

          // 7. Save OCR Result
          await db.update(
            'processed_images',
            {
              'ocr_text': ocrText,
              'processing_status': nextStatus.name, 
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          
        } catch (e) {
           await db.update(
            'processed_images',
            {'processing_status': ProcessingStatus.failed.name},
            where: 'id = ?',
            whereArgs: [id],
          );
        }

        itemStopwatch.stop();
        if (itemStopwatch.elapsedMilliseconds > 500) {
           debugPrint('[Performance] Image ${asset.id} took ${itemStopwatch.elapsedMilliseconds}ms');
        }

        processedCount++;
        // Update UI more frequently for actual work
        if (processedCount % 5 == 0 || processedCount == totalCount) {
             progressNotifier.value = processedCount / totalCount;
        }
      }
    } finally {
      stopwatch.stop();
      debugPrint('[Performance] Batch finished in ${stopwatch.elapsed.inSeconds}s. Processed: $processedCount');
      _isProcessing = false;
      progressNotifier.value = 0.0; // Reset
    }
  }

  void stop() {
    _isProcessing = false;
  }
}
