import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:receipt_sorter_and_finder/db/database_helper.dart';
import 'package:receipt_sorter_and_finder/models/processed_image.dart';

void main() {
  // Initialize FFI
  sqfliteFfiInit();
  // Set global factory
  databaseFactory = databaseFactoryFfi;

  group('Database Tests', () {
    test('Database initialization and schema creation', () async {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      
      // Verify table creation
      final tables = await db.query('sqlite_master', where: 'name = ?', whereArgs: ['processed_images']);
      expect(tables.length, 1);
      
      // Basic Insert/Read
      final image = ProcessedImage(
        filePath: '/tmp/test.jpg',
        processedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      );
      
      final id = await db.insert('processed_images', image.toMap());
      expect(id, isPositive);
      
      final result = await db.query('processed_images', where: 'id = ?', whereArgs: [id]);
      expect(result.length, 1);
      expect(result.first['file_path'], '/tmp/test.jpg');
      
      await dbHelper.close();
    });
  });
}
