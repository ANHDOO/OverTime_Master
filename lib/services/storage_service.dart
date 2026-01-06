import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';

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
      version: 7,
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
        await db.execute('''
          CREATE TABLE debt(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            month TEXT,
            amount REAL,
            created_at TEXT,
            is_paid INTEGER DEFAULT 0,
            paid_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE cash_transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT,
            amount REAL,
            description TEXT,
            date TEXT,
            imagePath TEXT,
            note TEXT,
            project TEXT DEFAULT 'Mặc định',
            createdAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE overtime ADD COLUMN hourly_rate REAL DEFAULT 85275.0');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS debt(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              month TEXT,
              amount REAL,
              created_at TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS cash_transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              type TEXT,
              amount REAL,
              description TEXT,
              date TEXT,
              imagePath TEXT,
              createdAt TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE cash_transactions ADD COLUMN note TEXT');
          } catch (_) {}
          try {
            await db.execute("ALTER TABLE cash_transactions ADD COLUMN project TEXT DEFAULT 'Mặc định'");
          } catch (_) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE debt ADD COLUMN is_paid INTEGER DEFAULT 0');
          } catch (_) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('ALTER TABLE debt ADD COLUMN paid_at TEXT');
          } catch (_) {}
        }
      },
    );
  }

  // OT Entry methods
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

  Future<int> updateEntry(OvertimeEntry entry) async {
    final db = await database;
    return await db.update(
      'overtime',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('overtime');
  }

  // Debt Entry methods
  Future<int> insertDebtEntry(DebtEntry entry) async {
    final db = await database;
    return await db.insert('debt', entry.toMap());
  }

  Future<List<DebtEntry>> getAllDebtEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('debt', orderBy: 'month DESC');
    return List.generate(maps.length, (i) => DebtEntry.fromMap(maps[i]));
  }

  Future<int> deleteDebtEntry(int id) async {
    final db = await database;
    return await db.delete('debt', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateDebtEntry(DebtEntry entry) async {
    final db = await database;
    return await db.update(
      'debt',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  // Cash Transaction methods
  Future<int> insertCashTransaction(CashTransaction transaction) async {
    final db = await database;
    return await db.insert('cash_transactions', transaction.toMap());
  }

  Future<List<CashTransaction>> getAllCashTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cash_transactions', orderBy: 'date DESC');
    return List.generate(maps.length, (i) => CashTransaction.fromMap(maps[i]));
  }

  Future<int> deleteCashTransaction(int id) async {
    final db = await database;
    return await db.delete('cash_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCashTransaction(CashTransaction transaction) async {
    final db = await database;
    return await db.update(
      'cash_transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }
}
