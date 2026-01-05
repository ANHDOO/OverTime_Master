import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/overtime_entry.dart';

class StorageService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'overtime.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE overtime(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            start_hour INTEGER,
            start_minute INTEGER,
            end_hour INTEGER,
            end_minute INTEGER,
            is_sunday INTEGER,
            hours_15 REAL,
            hours_18 REAL,
            hours_20 REAL,
            hourly_rate REAL,
            total_pay REAL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE overtime ADD COLUMN hourly_rate REAL DEFAULT 85275.0');
        }
      },
    );
  }

  Future<int> insertEntry(OvertimeEntry entry) async {
    final db = await database;
    return await db.insert('overtime', entry.toMap());
  }

  Future<List<OvertimeEntry>> getAllEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('overtime', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => OvertimeEntry.fromMap(maps[i]));
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete('overtime', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('overtime');
  }
}
