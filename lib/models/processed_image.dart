
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

class ProcessedImage {
  final int? id;
  final String? metadataHash;
  final String? perceptualHash;
  final String filePath;
  final String? contentUri;
  final String? assetId;
  
  final String? ocrText;
  final ProcessingStatus processingStatus;
  
  final String? documentType;
  final String? category;
  
  final DateTime? transactionDate;
  final double? amount;
  final String? merchantName;
  
  final DateTime processedAt;
  final bool isSynced;
  final bool isDeleted;

  ProcessedImage({
    this.id,
    this.metadataHash,
    this.perceptualHash,
    required this.filePath,
    this.contentUri,
    this.assetId,
    this.ocrText,
    this.processingStatus = ProcessingStatus.pending,
    this.documentType,
    this.category,
    this.transactionDate,
    this.amount,
    this.merchantName,
    required this.processedAt,
    this.isSynced = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'metadata_hash': metadataHash,
      'perceptual_hash': perceptualHash,
      'file_path': filePath,
      'content_uri': contentUri,
      'asset_id': assetId,
      'ocr_text': ocrText,
      'processing_status': processingStatus.name,
      'document_type': documentType,
      'category': category,
      'transaction_date': transactionDate?.toIso8601String(),
      'amount': amount,
      'merchant_name': merchantName,
      'processed_at': processedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  factory ProcessedImage.fromMap(Map<String, dynamic> map) {
    return ProcessedImage(
      id: map['id'],
      metadataHash: map['metadata_hash'],
      perceptualHash: map['perceptual_hash'],
      filePath: map['file_path'],
      contentUri: map['content_uri'],
      assetId: map['asset_id'],
      ocrText: map['ocr_text'],
      processingStatus: ProcessingStatus.values.firstWhere(
        (e) => e.name == map['processing_status'],
        orElse: () => ProcessingStatus.pending,
      ),
      documentType: map['document_type'],
      category: map['category'],
      transactionDate: map['transaction_date'] != null 
          ? DateTime.parse(map['transaction_date']) 
          : null,
      amount: map['amount'],
      merchantName: map['merchant_name'],
      processedAt: DateTime.parse(map['processed_at']),
      isSynced: map['is_synced'] == 1,
      isDeleted: map['is_deleted'] == 1,
    );
  }
}
