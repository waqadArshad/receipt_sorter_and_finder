
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
                  
                  // OCR Results
                  if (processedData?.ocrText != null) ...[
                    Text(
                      'Extracted Text:',
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
}
