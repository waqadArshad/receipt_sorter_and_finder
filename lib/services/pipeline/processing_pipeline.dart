
import 'package:photo_manager/photo_manager.dart';
import '../../db/database_helper.dart';
import '../../models/processed_image.dart';
import '../image_hash_service.dart';
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

  // Simple in-memory flag to control processing loop
  bool _isProcessing = false;

  /// Starts processing the provided list of gallery assets.
  /// Runs in the background (asynchronous loop).
  Future<void> processAssets(List<AssetEntity> assets) async {
    if (_isProcessing) return; // Prevent concurrent runs (simplification)
    _isProcessing = true;

    try {
      for (final asset in assets) {
        if (!_isProcessing) break; // User stopped?

        // 1. Get File
        final file = await asset.file;
        if (file == null) continue;

        // 2. Generate Hashes
        final hashes = await _hashService.generateHashes(file);

        // 3. Check for duplicates (Fast check: metadata hash)
        final db = await _dbHelper.database;
        
        // Fast check query
        final List<Map<String, dynamic>> existing = await db.query(
          'processed_images',
          where: 'metadata_hash = ?',
          whereArgs: [hashes.metadataHash],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          continue;
        }
        
        // 4. Create initial DB entry (pending status)
        final newImage = ProcessedImage(
          filePath: file.absolute.path,
          metadataHash: hashes.metadataHash,
          perceptualHash: hashes.perceptualHash,
          assetId: asset.id,
          processedAt: DateTime.now(),
          processingStatus: ProcessingStatus.hashing, // Just finished hashing
        );
        
        final id = await db.insert('processed_images', newImage.toMap());
        
        // 5. Run OCR immediately (Pipeline Stage 1)
        await db.update(
          'processed_images', 
          {'processing_status': ProcessingStatus.ocrInProgress.name},
          where: 'id = ?', 
          whereArgs: [id],
        );

        try {
          final ocrText = await _ocrService.extractText(file);
          
          // 6. Save OCR Result
          await db.update(
            'processed_images',
            {
              'ocr_text': ocrText,
              'processing_status': ProcessingStatus.ocrComplete.name, 
            },
            where: 'id = ?',
            whereArgs: [id],
          );
          
          // Trigger classification immediately
          _classificationService.processQueue();
          
        } catch (e) {
           await db.update(
            'processed_images',
            {
              'processing_status': ProcessingStatus.failed.name,
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  void stop() {
    _isProcessing = false;
  }
}
