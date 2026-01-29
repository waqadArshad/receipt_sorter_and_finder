
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/processed_image.dart';

class ImageDetailScreen extends StatelessWidget {
  final AssetEntity asset;
  final ProcessedImage? processedData;

  const ImageDetailScreen({
    super.key,
    required this.asset,
    this.processedData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full Image
            SizedBox(
              height: 400,
              width: double.infinity,
              child: FutureBuilder(
                future: asset.thumbnailDataWithSize(const ThumbnailSize(1024, 1024)), // High res thumbnail
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            
            const Divider(),
            
            // Metadata & Status
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${asset.id}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _buildStatusBadge(context),
                  const SizedBox(height: 16),
                  
                  // Structured Data (if processed)
                  if (processedData?.processingStatus == ProcessingStatus.completed) ...[
                    Text(
                      'Receipt Details:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (processedData?.merchantName != null)
                              _buildDetailRow(Icons.store, 'Merchant', processedData!.merchantName!),
                            
                            // Sender (always show if available)
                            if (processedData?.senderName != null)
                              _buildDetailRow(
                                Icons.person_outline, 
                                'From', 
                                processedData!.senderName!
                              ),
                            
                            // Recipient (always show if available)
                            if (processedData?.recipientName != null)
                              _buildDetailRow(
                                Icons.person, 
                                'To', 
                                processedData!.recipientName!
                              ),
                            
                            if (processedData?.amount != null)
                              _buildDetailRow(
                                Icons.attach_money, 
                                processedData!.transactionType == 'credit' ? 'Received' : 
                                processedData!.transactionType == 'debit' ? 'Sent' :
                                processedData!.transactionType == 'third_party' ? 'Amount' : 'Amount',
                                '${processedData!.currency ?? "\$"}${processedData!.amount!.toStringAsFixed(2)}'
                              ),
                            if (processedData?.transactionDate != null)
                              _buildDetailRow(Icons.calendar_today, 'Date', processedData!.transactionDate!.toString().split(' ')[0]),
                            if (processedData?.category != null)
                              _buildDetailRow(Icons.category, 'Category', processedData!.category!),
                            if (processedData?.documentType != null)
                              _buildDetailRow(Icons.description, 'Type', processedData!.documentType!),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OCR Results
                  if (processedData?.ocrText != null) ...[
                    Text(
                      'Raw OCR Text:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        processedData!.ocrText!,
                        style: const TextStyle(
                          fontFamily: 'monospace', 
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ] else ...[
                     const Text('No text extracted or OCR pending.'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final status = processedData?.processingStatus ?? ProcessingStatus.pending;
    Color color;
    String label;

    switch (status) {
      case ProcessingStatus.pending:
        color = Colors.grey;
        label = 'Pending';
        break;
      case ProcessingStatus.hashing:
        color = Colors.blue;
        label = 'Hashing...';
        break;
      case ProcessingStatus.ocrInProgress:
        color = Colors.orange;
        label = 'Reading Text...';
        break;
      case ProcessingStatus.ocrComplete:
        color = Colors.green;
        label = 'OCR Complete';
        break;
      case ProcessingStatus.classificationQueued:
        color = Colors.indigo;
        label = 'Queued';
        break;
      case ProcessingStatus.classificationInProgress:
        color = Colors.purple;
        label = 'Classifying...';
        break;
      case ProcessingStatus.completed:
        color = Colors.green.shade700;
        label = 'Processed';
        break;
      case ProcessingStatus.failed:
        color = Colors.red;
        label = 'Failed';
        break;
      default:
        color = Colors.grey.shade400;
        label = 'Ignored';
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
