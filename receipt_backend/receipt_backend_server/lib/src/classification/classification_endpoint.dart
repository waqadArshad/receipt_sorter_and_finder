import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class ClassificationEndpoint extends Endpoint {
  
  Future<BatchClassificationResponse> classifyBatch(Session session, List<ClassificationTask> tasks) async {
    session.log('Received batch of ${tasks.length} tasks for classification');
    
    final results = <ClassificationResult>[];
    
    for (var task in tasks) {
      // Mock simple keyword matching for MVP demonstration
      final text = task.ocrText.toLowerCase();
      String type = 'other';
      String? merchant;
      double? amount;
      
      if (text.contains('starbucks')) {
        merchant = 'Starbucks';
        type = 'pos_receipt';
      } else if (text.contains('uber')) {
        merchant = 'Uber';
        type = 'digital_receipt';
      } else if (text.contains('total')) {
        type = 'receipt';
      }
      
      results.add(ClassificationResult(
        hash: task.hash,
        documentType: type,
        category: 'uncategorized',
        confidence: 0.9,
        merchantName: merchant,
        totalAmount: amount, // Null for now
        transactionDate: DateTime.now(),
        summary: 'Auto-classified based on keywords',
      ));
    }
    
    return BatchClassificationResponse(results: results);
  }
}
