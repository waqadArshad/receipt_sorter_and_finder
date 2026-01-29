import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../db/database_helper.dart';
import '../models/processed_image.dart';
import 'image_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ProcessedImage> _results = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      
      // Basic text search using LIKE
      // In production, use FTS5 for better performance and matching
      final List<Map<String, dynamic>> rows = await db.query(
        'processed_images',
        where: 'ocr_text LIKE ?',
        whereArgs: ['%$query%'],
        limit: 50,
      );

      setState(() {
        _results = rows.map((row) => ProcessedImage.fromMap(row)).toList();
      });
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search receipts (e.g., "Total", "Starbucks")',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.receipt),
                      title: Text(
                        item.ocrText?.trim().split('\n').firstOrNull ?? 'Receipt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item.ocrText?.replaceAll('\n', ' ').substring(0, 
                          (item.ocrText!.length > 50) ? 50 : item.ocrText!.length
                        ) ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _navigateToDetail(item),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Search for merchant names, items, or totals'),
        ],
      ),
    );
  }

  Future<void> _navigateToDetail(ProcessedImage item) async {
    // We need the AssetEntity to display the image.
    // We stored the assetId in the DB.
    final asset = await AssetEntity.fromId(item.assetId ?? "");
    if (asset != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageDetailScreen(
            asset: asset, 
            processedData: item,
          ),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image not found in gallery')),
        );
      }
    }
  }
}

extension ListGet on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
