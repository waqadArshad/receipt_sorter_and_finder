import 'package:serverpod/serverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../generated/protocol.dart';

class ChatEndpoint extends Endpoint {
  
  // Basic chat method
  Future<String> ask(Session session, String question) async {
    try {
      // 1. Get relevant receipts (naive approach first: fetch last 50)
      // In a real implementation, we'd use LLM to generating search filters first
      final receipts = await Receipt.db.find(
        session,
        limit: 200, // Increased to 500: Gemini Flash has a huge context window (1M tokens).
                   // We can feed it almost your entire history!
        orderBy: (t) => t.transactionDate,
        orderDescending: true,
      );

      // 2. Prepare context for LLM
      final contextData = receipts.map((r) {
        String details = "${r.merchantName}";
        if (r.senderName != null || r.recipientName != null) {
          details += " | From: ${r.senderName ?? 'N/A'} -> To: ${r.recipientName ?? 'N/A'}";
        }
        return "- ${r.transactionDate.toString().split(' ')[0]} [${r.transactionType ?? 'transaction'}]: $details (${r.category}) - ${r.currency} ${r.totalAmount}";
      }).join('\n');

      final systemPrompt = """
You are a helpful receipt assistant. 
Today is: ${DateTime.now().toString().split(' ')[0]}

Answer the user's question based ONLY on the receipt data provided below.
If the answer is not in the data, say "I couldn't find that information in your recent receipts."

Receipt Data:
$contextData
""";

      // 3. Call OpenRouter
      // We reuse the API key logic from ClassificationEndpoint
      var apiKey = session.serverpod.getPassword('OPENROUTER_KEY') ?? 'sk-or-v1-...'; 
      // If retrieval fails (e.g. local dev), fallback to hardcoded or error.
      // Ideally inject this properly.
      
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-r1-0528:free', // User preferred free model
          'max_tokens': 5000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      ).timeout(Duration(seconds: 300));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? "No response content.";
      } else {
        return "Error calling AI: ${response.statusCode}";
      }

    } catch (e) {
      return "Something went wrong: $e";
    }
  }
}
