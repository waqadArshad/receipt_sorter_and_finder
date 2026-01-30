import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/pipeline/processing_pipeline.dart';
import '../services/classification_service.dart';
import '../db/database_helper.dart';
import '../models/processed_image.dart';
import '../models/filter_criteria.dart';
import 'search_screen.dart';
import 'image_detail_screen.dart';
import 'filter_screen.dart';
import 'chat_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _isProcessingQueue = false;
  PermissionState _permissionState = PermissionState.notDetermined;
  final _pipeline = ProcessingPipeline();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
    
    // LIVE UPDATES: Refresh tabs when pipeline makes progress
    _pipeline.progressNotifier.addListener(_onPipelineProgress);
  }

  @override
  void dispose() {
    _pipeline.progressNotifier.removeListener(_onPipelineProgress);
    super.dispose();
  }

  int _lastRefreshTime = 0;
  void _onPipelineProgress() {
    // Only refresh when batch completes or resets
    final val = _pipeline.progressNotifier.value;
    if (val >= 1.0 || val == 0.0) {
      // Small debounce to prevent double-firing
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRefreshTime > 1000) {
        _lastRefreshTime = now;
        if (mounted) _loadTabAssets();
      }
    }
  }

  Future<void> _requestPermissionAndLoad() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    setState(() {
      _permissionState = ps;
    });

    if (ps.isAuth) {
      await _loadAssets();
      
      // BACKGROUND SYNC: Try to fetch latest data from server to recover "Lost/Failed" items
      // Don't await this to keep UI snappy
      ClassificationService().syncWithServer().then((count) {
        if (count > 0 && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Synced $count items from Cloud')));
           _loadTabAssets(); // Refresh UI after sync
        }
      });
      
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  FilterCriteria _filterCriteria = FilterCriteria();
  bool get _isFiltered => !_filterCriteria.isEmpty;

  // Tab-specific asset lists
  List<AssetEntity> _processedAssets = [];
  List<AssetEntity> _pendingAssets = [];
  List<AssetEntity> _skippedAssets = [];

  Future<List<AssetEntity>> _loadAssetsByStatus(List<ProcessingStatus> statuses) async {
    final db = await DatabaseHelper.instance.database;
    final statusNames = statuses.map((s) => s.name).toList();
    final placeholders = List.filled(statusNames.length, '?').join(',');
    
    final results = await db.query(
      'processed_images',
      where: 'processing_status IN ($placeholders)',
      whereArgs: statusNames,
    );

    List<AssetEntity> assets = [];
    for (var row in results) {
      final assetId = row['asset_id'] as String?;
      if (assetId != null) {
        final asset = await AssetEntity.fromId(assetId);
        if (asset != null) assets.add(asset);
      }
    }
    return assets;
  }


  // Modified _loadAssets to handle both cases
  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
    });

    if (_isFiltered) {
      // Load from DB based on filters
      final db = DatabaseHelper.instance;
      debugPrint('Filtering with criteria: types=${_filterCriteria.documentTypes}, merchants=${_filterCriteria.merchants}');
      final results = await db.getFilteredImages(_filterCriteria);
      debugPrint('Filter returned ${results.length} rows');

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
        filterOption: FilterOptionGroup(orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)]),
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> assets = await albums[0].getAssetListRange(start: 0, end: 1000);

        setState(() {
          _assets = assets;
          _isLoading = false;
        });

        // Trigger pipeline in background only for fresh gallery load
        _pipeline.processAssets(assets);
        
        // Load tab-specific lists
        _loadTabAssets();
      } else {
        setState(() {
          _assets = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTabAssets() async {
    if (_isFiltered) {
      // If filtering is active, queries are based on metadata (Merchant, Date, etc.)
      // This primarily applies to Completed receipts.
      final db = DatabaseHelper.instance;
      final results = await db.getFilteredImages(_filterCriteria);
      
      List<AssetEntity> validAssets = [];
      for (var row in results) {
        final pid = row['asset_id'] as String?;
        if (pid != null) {
          final asset = await AssetEntity.fromId(pid);
          if (asset != null) validAssets.add(asset);
        }
      }

      setState(() {
        _processedAssets = validAssets;
        // Filters (Merchant/Amount) don't apply to pending items usually
        _pendingAssets = []; 
        _skippedAssets = [];
      });
    } else {
      // Normal View - Split by Status
      final processed = await _loadAssetsByStatus([ProcessingStatus.completed]);
      final pending = await _loadAssetsByStatus([
        ProcessingStatus.pending,
        ProcessingStatus.hashing,
        ProcessingStatus.ocrInProgress,
        ProcessingStatus.ocrComplete,
        ProcessingStatus.classificationQueued,
        ProcessingStatus.classificationInProgress,
      ]);
      final skipped = await _loadAssetsByStatus([ProcessingStatus.skipped, ProcessingStatus.failed]);

      setState(() {
        _processedAssets = processed;
        _pendingAssets = pending;
        _skippedAssets = skipped;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 4,
      initialIndex: 1, // Default to Receipts tab
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isFiltered ? 'Filtered Results' : 'Receipt Gallery'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.photo_library), text: 'All Photos'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Receipts'),
              Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
              Tab(icon: Icon(Icons.delete_outline), text: 'Trash'),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list, color: _isFiltered ? Colors.amber : null),
              onPressed: _openFilters,
            ),
            IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              },
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _requestPermissionAndLoad),
            // DEV ONLY: Clear DB Button
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red), 
              onPressed: () async {
                 final confirm = await showDialog<bool>(
                   context: context,
                   builder: (context) => AlertDialog(
                     title: const Text('Reset Everything?'),
                     content: const Text('This will wipe the local database. All images will need to be re-scanned.'),
                     actions: [
                       TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                       TextButton(child: const Text('NUKE IT', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(context, true)),
                     ],
                   ),
                 );
                 
                 if (confirm == true) {
                   // Force stop UI processing visual
                   setState(() => _isProcessingQueue = false); 
                   
                   final count = await DatabaseHelper.instance.clearAllData();
                   
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Deleted $count records. Rescanning...')),
                     );
                     
                     setState(() {
                       _assets = [];
                       _processedAssets = [];
                       _pendingAssets = [];
                       _skippedAssets = [];
                     });
                     
                     // Small delay to ensure DB transaction commits
                     await Future.delayed(const Duration(milliseconds: 500));
                     
                     await _requestPermissionAndLoad(); 
                   }
                 }
              }
            ),
          ],
        ),

        body: Column(
          children: [
            _buildPermissionWarningIfNeeded(),
            
            // Progress Bar for Background Processing
            ValueListenableBuilder<double>(
              valueListenable: _pipeline.progressNotifier,
              builder: (context, value, child) {
                if (value <= 0 || value >= 1.0) return const SizedBox.shrink();
                return Column(
                  children: [
                    LinearProgressIndicator(value: value, minHeight: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        'Scanning Gallery: ${(value * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                );
              },
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: All Photos
                  _assets.isEmpty ? const Center(child: Text('No images found')) : _buildGrid(_assets),

                  // Tab 2: Processed Receipts Only
                  _processedAssets.isEmpty 
                    ? const Center(child: Text('No processed receipts yet.\nImages will appear here after AI classification.'))
                    : _buildGrid(_processedAssets),

                  // Tab 3: Pending
                  _pendingAssets.isEmpty
                    ? const Center(child: Text('No pending items'))
                    : _buildGrid(_pendingAssets),

                  // Tab 4: Trash/Skipped
                  _skippedAssets.isEmpty
                    ? const Center(child: Text('No ignored items'))
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Failed/Skipped Items'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                              onPressed: () async {
                                final db = await DatabaseHelper.instance.database;
                                
                                // 1. Only retry FAILED items (Network/Timeout errors)
                                // Do NOT retry 'skipped' items (Invalid/No Text) because they are legitimate trash.
                                await db.update(
                                  'processed_images',
                                  {'processing_status': 'ocrComplete'}, 
                                  where: "processing_status = 'failed'",
                                );

                                setState(() {
                                  _skippedAssets = [];
                                });
                                
                                // 2. Trigger Sync to see if Server already has them
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Retrying failed items... Checking Cloud first...')),
                                );
                                
                                final synced = await ClassificationService().syncWithServer();
                                
                                await _requestPermissionAndLoad();
                                
                                if (synced > 0) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Recovered $synced items from Cloud! Rest queued for AI.')),
                                   );
                                } else {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text('Items moved to Pending queue')),
                                   );
                                }
                              },
                            ),
                          ),
                          Expanded(child: _buildGrid(_skippedAssets)),
                        ],
                      ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _pendingAssets.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isProcessingQueue ? null : () async {
                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Process with AI'),
                    content: const Text('Send up to 50 validated receipts to AI for classification?\n\nThis will use API credits.'),
                    actions: [
                      TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                      TextButton(
                        child: const Text('Start Processing'), 
                        onPressed: () => Navigator.pop(context, true)
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  setState(() => _isProcessingQueue = true);
                  try {
                    final processedCount = await ClassificationService().processQueue();
                    if (mounted) {
                      if (processedCount > 0) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Successfully processed $processedCount receipts!')),
                         );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('No valid items found to process.')),
                         );
                      }
                      // Refresh lists to move items from Pending to Receipts
                      await _loadTabAssets();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isProcessingQueue = false);
                  }
                }
              },
              label: _isProcessingQueue 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Process AI Queue'),
              icon: _isProcessingQueue ? null : const Icon(Icons.auto_awesome),
              backgroundColor: Colors.purple,
            )
          : null,
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
              child: const Text('Limited Photos Access. Tap to manage.', style: TextStyle(color: Colors.black87)),
            ),
            TextButton(onPressed: () => PhotoManager.openSetting(), child: const Text('Manage')),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildGrid(List<AssetEntity> assets) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () async {
            // Fetch latest status before navigating
            final entity = assets[index];
            final db = await DatabaseHelper.instance.database;
            final res = await db.query('processed_images', where: 'asset_id = ?', whereArgs: [entity.id], limit: 1);

            final processed = res.isNotEmpty ? ProcessedImage.fromMap(res.first) : null;

            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageDetailScreen(asset: entity, processedData: processed),
                ),
              );
            }
          },
          child: AssetThumbnail(asset: assets[index]),
        );
      },
    );
  }

  Future<void> _openFilters() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => FilterScreen(initialFilters: _filterCriteria)));

    if (result != null && result is FilterCriteria) {
      setState(() {
        _filterCriteria = result;
      });
      _loadAssets();
      _loadTabAssets(); // Refresh Receipts tab too!
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
    final List<Map<String, dynamic>> results = await db.query('processed_images', where: 'asset_id = ?', whereArgs: [asset.id], limit: 1);

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
              return Image.memory(snapshot.data!, fit: BoxFit.cover);
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
                  child: const Text('OCR Done', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              );
            } else if (status == ProcessingStatus.ocrInProgress) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
