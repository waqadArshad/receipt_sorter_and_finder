import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/filter_criteria.dart';


class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('receipt_finder.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for transaction details (v1 → v2)
      await db.execute('ALTER TABLE processed_images ADD COLUMN sender_name TEXT');
      await db.execute('ALTER TABLE processed_images ADD COLUMN recipient_name TEXT');
      await db.execute('ALTER TABLE processed_images ADD COLUMN currency TEXT');
      await db.execute('ALTER TABLE processed_images ADD COLUMN transaction_type TEXT');
    }
    
    if (oldVersion < 3) {
      // Add currency column if upgrading from v2 (v2 → v3)
      // Check if column exists first to avoid errors
      final tableInfo = await db.rawQuery('PRAGMA table_info(processed_images)');
      final hasCurrency = tableInfo.any((col) => col['name'] == 'currency');
      
      if (!hasCurrency) {
        await db.execute('ALTER TABLE processed_images ADD COLUMN currency TEXT');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const boolType = 'INTEGER NOT NULL'; // 0 or 1
    const realType = 'REAL';

    await db.execute('''
CREATE TABLE processed_images (
  id $idType,
  metadata_hash $textType,
  perceptual_hash $textType,
  file_path $textType,
  content_uri $textType,
  asset_id $textType,
  
  ocr_text $textType,
  processing_status $textType DEFAULT 'pending',
  
  document_type $textType,
  category $textType,
  
  transaction_date $textType,
  amount $realType,
  currency $textType,
  merchant_name $textType,
  sender_name $textType,
  recipient_name $textType,
  transaction_type $textType,
  
  processed_at $textType,
  is_synced $boolType DEFAULT 0,
  is_deleted $boolType DEFAULT 0
)
    ''');
    
    // Indexes for fast lookups
    await db.execute('CREATE INDEX idx_metadata_hash ON processed_images(metadata_hash)');
    await db.execute('CREATE INDEX idx_perceptual_hash ON processed_images(perceptual_hash)');
    await db.execute('CREATE INDEX idx_document_type ON processed_images(document_type)');
    await db.execute('CREATE INDEX idx_processing_status ON processed_images(processing_status)');
  }

  Future<List<Map<String, dynamic>>> getFilteredImages(FilterCriteria criteria) async {
    final db = await database;
    String whereClause = '1=1'; // Default true
    List<dynamic> args = [];

    if (criteria.documentTypes != null && criteria.documentTypes!.isNotEmpty) {
      whereClause += ' AND document_type IN (${List.filled(criteria.documentTypes!.length, '?').join(',')})';
      args.addAll(criteria.documentTypes!);
    }

    if (criteria.merchants != null && criteria.merchants!.isNotEmpty) {
      whereClause += ' AND merchant_name IN (${List.filled(criteria.merchants!.length, '?').join(',')})';
      args.addAll(criteria.merchants!);
    }

    if (criteria.startDate != null) {
      whereClause += ' AND transaction_date >= ?';
      args.add(criteria.startDate!.toIso8601String());
    }

    if (criteria.endDate != null) {
      whereClause += ' AND transaction_date <= ?';
      args.add(criteria.endDate!.toIso8601String());
    }

    return await db.query(
      'processed_images',
      where: whereClause,
      whereArgs: args,
      orderBy: 'transaction_date DESC, processed_at DESC',
    );
  }

  Future<List<String>> getDistinctMerchants() async {
    final db = await database;
    final result = await db.query(
      'processed_images',
      columns: ['merchant_name'],
      distinct: true,
      where: 'merchant_name IS NOT NULL',
      orderBy: 'merchant_name ASC',
    );
    return result.map((e) => e['merchant_name'] as String).toList();
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<int> clearAllData() async {
    final db = await instance.database;
    try {
      final count = await db.delete('processed_images');
      // Optional: Reset AutoIncrement
      await db.delete('sqlite_sequence', where: 'name = ?', whereArgs: ['processed_images']);
      return count;
    } catch (e) {
      print('Error clearing data: $e');
      return -1;
    }
  }
}
