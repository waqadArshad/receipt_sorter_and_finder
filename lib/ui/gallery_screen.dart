import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/pipeline/processing_pipeline.dart';
import '../db/database_helper.dart';
import '../models/processed_image.dart';
import '../models/filter_criteria.dart';
import 'search_screen.dart';
import 'image_detail_screen.dart';
import 'filter_screen.dart';


class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  PermissionState _permissionState = PermissionState.notDetermined;
  final _pipeline = ProcessingPipeline();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    setState(() {
      _permissionState = ps;
    });

    if (ps.isAuth) {
      await _loadAssets();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  FilterCriteria _filterCriteria = FilterCriteria();
  bool get _isFiltered => !_filterCriteria.isEmpty;

  // ... (initState)

  // Modified _loadAssets to handle both cases
  Future<void> _loadAssets() async {
    setState(() { _isLoading = true; });

    if (_isFiltered) {
       // Load from DB based on filters
       final db = DatabaseHelper.instance;
       final results = await db.getFilteredImages(_filterCriteria);
       
       // We need to map these back to AssetEntities if possible, 
       // but wait, AssetEntity is valid only if the image is in gallery.
       // We stored the 'assetId'.
       
       List<AssetEntity> validAssets = [];
       for (var row in results) {
         final pid = row['asset_id'] as String?;
         if (pid != null) {
           final asset = await AssetEntity.fromId(pid);
           if (asset != null) validAssets.add(asset);
         }
       }
       
       setState(() {
         _assets = validAssets;
         _isLoading = false;
       });
       
    } else {
      // Normal gallery load
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false,
            ),
          ],
        ),
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> assets = await albums[0].getAssetListRange(
          start: 0, 
          end: 100, 
        );
        
        setState(() {
          _assets = assets;
          _isLoading = false;
        });

        // Trigger pipeline in background only for fresh gallery load
        _pipeline.processAssets(assets);
      } else {
        setState(() {
          _assets = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isFiltered ? 'Filtered Results' : 'Receipt Gallery'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: _isFiltered ? Colors.amber : null),
            onPressed: _openFilters,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestPermissionAndLoad,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPermissionWarningIfNeeded(),
          Expanded(
            child: _assets.isEmpty
                ? const Center(child: Text('No images found'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () async {
                           // Fetch latest status before navigating
                           final entity = _assets[index];
                           final db = await DatabaseHelper.instance.database;
                           final res = await db.query(
                             'processed_images', 
                             where: 'asset_id = ?', 
                             whereArgs: [entity.id],
                             limit: 1
                           );
                           
                           final processed = res.isNotEmpty ? ProcessedImage.fromMap(res.first) : null;
                           
                           if (context.mounted) {
                             Navigator.push(
                               context,
                               MaterialPageRoute(
                                 builder: (_) => ImageDetailScreen(
                                   asset: entity,
                                   processedData: processed,
                                 ),
                               ),
                             );
                           }
                        },
                        child: AssetThumbnail(asset: _assets[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarningIfNeeded() {
    if (_permissionState == PermissionState.limited) {
      return Container(
        color: Colors.amber.shade100,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: const Text(
                'Limited Photos Access. Tap to manage.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            TextButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Manage'),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilterScreen(initialFilters: _filterCriteria),
      ),
    );

    if (result != null && result is FilterCriteria) {
      setState(() {
        _filterCriteria = result;
      });
      _loadAssets();
    }
  }
}

class AssetThumbnail extends StatelessWidget {
  final AssetEntity asset;

  const AssetThumbnail({super.key, required this.asset});

  Future<ProcessedImage?> _getProcessedStatus() async {
    final db = await DatabaseHelper.instance.database;
    // We need a stable way to find the image. 
    // Ideally we use the asset ID if we stored it, or hash.
    // For now, let's query by asset_id since we store it.
    final List<Map<String, dynamic>> results = await db.query(
      'processed_images',
      where: 'asset_id = ?',
      whereArgs: [asset.id],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return ProcessedImage.fromMap(results.first);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Image
        FutureBuilder(
          future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              );
            }
            return Container(color: Colors.grey[300]);
          },
        ),
        
        // Status Overlay (Polled for now, ideally Stream)
        // Using a FutureBuilder here just checks ONCE when scrolled into view.
        // For real-time updates (like watching OCR progress), we'd need a Stream.
        FutureBuilder<ProcessedImage?>(
          future: _getProcessedStatus(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            
            final status = snapshot.data!.processingStatus;
            
            if (status == ProcessingStatus.ocrComplete) {
               return Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: const Text(
                    'OCR Done', 
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              );
            } else if (status == ProcessingStatus.ocrInProgress) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
