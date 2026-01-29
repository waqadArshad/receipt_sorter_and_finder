import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';
import '../generated/protocol.dart';

class ClassificationEndpoint extends Endpoint {
  
  Future<BatchClassificationResponse> classifyBatch(Session session, List<ClassificationTask> tasks) async {
    session.log('Received batch of ${tasks.length} tasks for classification');

    // 1. Get API Key from config
    final apiKey = session.serverpod.getPassword('openrouterApiKey');
    if (apiKey == null || apiKey.isEmpty || apiKey == '\${OPENROUTER_KEY}') {
       session.log('OpenRouter API Key not set! Falling back to mock.', level: LogLevel.warning);
       return _mockClassify(tasks);
    }
    
    final results = <ClassificationResult>[];
    final client = http.Client();

    try {
      for (var task in tasks) {
        try {
          // Prepare Prompt
          final prompt = _buildPrompt(task.ocrText);
          
          final response = await client.post(
            Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              // 'HTTP-Referer': 'https://your-site.com', // Required by OpenRouter for ranking
              // 'X-Title': 'ReceiptFinder', 
            },
            body: jsonEncode({
              // "model": "google/gemini-2.0-flash-lite-preview-02-05:free", // cost-effective
              "model": "google/gemini-2.0-flash-lite-preview-02-05:free",
              "messages": [
                {
                  "role": "system", 
                  "content": "You are a receipt data extraction assistant. Output STRICT JSON only. No markdown formatting. "
                             "Extract: merchant_name (string - for purchases/retail, or bank/service name for transfers), "
                             "sender_name (string - who sent the money, null for purchases), "
                             "recipient_name (string - who received the money, null for purchases), "
                             "total_amount (number - always positive), "
                             "currency (string - ISO 4217 code like USD, PKR, EUR, INR or symbol like \$, ₨, Rs, ₹, €), "
                             "transaction_type (string - 'credit' if user received money, 'debit' if user sent money, 'purchase' for retail, 'third_party' if neither), "
                             "transaction_date (ISO8601 string or null), "
                             "document_type (pos_receipt, digital_receipt, invoice, bank_statement, transfer_receipt, other), "
                             "category (string - e.g., Food, Transfer, Shopping, etc)."
                },
                {"role": "user", "content": "Extract data from this text:\n${task.ocrText}"}
              ]
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final content = data['choices'][0]['message']['content'];
            
            // Parse JSON content (handle potential markdown blocks)
            final cleanJson = content.replaceAll('```json', '').replaceAll('```', '').trim();
            final extracted = jsonDecode(cleanJson);
            
            results.add(ClassificationResult(
              hash: task.hash,
              documentType: extracted['document_type'] ?? 'other',
              category: extracted['category'] ?? 'uncategorized',
              confidence: 0.9,
              merchantName: extracted['merchant_name'],
              senderName: extracted['sender_name'],
              recipientName: extracted['recipient_name'],
              totalAmount: (extracted['total_amount'] is num) ? (extracted['total_amount'] as num).toDouble() : null,
              currency: extracted['currency'],
              transactionType: extracted['transaction_type'],
              transactionDate: DateTime.tryParse(extracted['transaction_date'] ?? '') ?? DateTime.now(),
              summary: 'LLM Extracted',
            ));
          } else {
             session.log('OpenRouter API Error: ${response.statusCode} - ${response.body}', level: LogLevel.error);
             // Fallback to basic
             results.add(_mockSingle(task));
          }
        } catch (e) {
          session.log('Error processing task: $e', level: LogLevel.error);
          results.add(_mockSingle(task));
        }
      }
    } finally {
      client.close();
    }
    
    return BatchClassificationResponse(results: results);
  }

  // Fallback methods
  BatchClassificationResponse _mockClassify(List<ClassificationTask> tasks) {
    return BatchClassificationResponse(results: tasks.map((t) => _mockSingle(t)).toList());
  }

  ClassificationResult _mockSingle(ClassificationTask task) {
       final text = task.ocrText.toLowerCase();
       return ClassificationResult(
        hash: task.hash,
        documentType: text.contains('receipt') ? 'pos_receipt' : 'other',
        category: 'uncategorized',
        confidence: 0.5,
        merchantName: null,
        totalAmount: null,
        transactionDate: DateTime.now(),
        summary: 'Mock Fallback',
      );
  }
  
  String _buildPrompt(String text) {
    // Kept simple for now, handled in the request body usually
    return text;
  }
}
