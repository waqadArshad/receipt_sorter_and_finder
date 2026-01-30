// import 'dart:io';
// import 'package:receipt_backend_client/receipt_backend_client.dart';
// import 'package:receipt_backend_server/src/generated/protocol.dart';
// import 'package:serverpod_client/serverpod_client.dart';
//
// void main() async {
//   final client = Client('http://127.0.0.1:8080/', authenticationKeyManager: ProtocolAuthenticationKeyManager())
//     ..connectivityMonitor = null; // No monitor needed for CLI
//
//   print('Connecting to server...');
//
//   try {
//     // 1. Check health
//     final health = await client.insights.checkHealth();
//     print('Server Health: $health');
//
//     // 2. Try to insert a receipt
//     final receipt = Receipt(
//        filePath: '/test/path.jpg',
//        metadataHash: 'TEST_HASH_123',
//        ocrText: 'TEST RECEIPT CONTENT',
//        processedAt: DateTime.now(),
//        processingStatus: 'test',
//     );
//
//     print('Attempting to store receipt...');
//     await client.receipt.storeReceipt(receipt);
//     print('✅ Receipt Stored Successfully!');
//
//   } catch (e) {
//     print('❌ Connection Failed: $e');
//   }
// }
