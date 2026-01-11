import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';
import '../models/citizen_profile.dart';

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
      version: 9,
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
            payment_type TEXT DEFAULT 'Hoá đơn giấy',
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE citizen_profiles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT,
            tax_id TEXT,
            license_plate TEXT,
            cccd_id TEXT,
            bhxh_id TEXT,
            is_default INTEGER DEFAULT 0
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
        if (oldVersion < 8) {
          try {
            await db.execute("ALTER TABLE cash_transactions ADD COLUMN payment_type TEXT DEFAULT 'Hoá đơn giấy'");
          } catch (_) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS citizen_profiles(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                label TEXT,
                tax_id TEXT,
                license_plate TEXT,
                cccd_id TEXT,
                bhxh_id TEXT,
                is_default INTEGER DEFAULT 0
              )
            ''');
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

  /// Close and clear cached database instance.
  Future<void> closeDatabase() async {
    if (_database != null) {
      try {
        await _database!.close();
      } catch (_) {}
      _database = null;
    }
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

  // Citizen Profile methods
  Future<int> insertCitizenProfile(CitizenProfile profile) async {
    final db = await database;
    return await db.insert('citizen_profiles', profile.toMap());
  }

  Future<List<CitizenProfile>> getAllCitizenProfiles() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('citizen_profiles', orderBy: 'id ASC');
    return List.generate(maps.length, (i) => CitizenProfile.fromMap(maps[i]));
  }

  Future<int> deleteCitizenProfile(int id) async {
    final db = await database;
    return await db.delete('citizen_profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateCitizenProfile(CitizenProfile profile) async {
    final db = await database;
    return await db.update(
      'citizen_profiles',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  /// Cleanup old files on first launch of a new version
  /// Call this from main.dart or splash_screen.dart
  static Future<void> performFirstLaunchCleanup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanupBuild = prefs.getInt('last_cleanup_build') ?? 0;
      
      // Get current build number from package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      
      debugPrint('🧹 Cleanup check: lastBuild=$lastCleanupBuild, currentBuild=$currentBuild');
      
      if (currentBuild > lastCleanupBuild) {
        debugPrint('🧹 Running cleanup for build $currentBuild...');
        
        int deletedFiles = 0;
        
        // 1. Clear temp directory
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final files = tempDir.listSync();
          for (var file in files) {
            try {
              await file.delete(recursive: true);
              deletedFiles++;
            } catch (_) {}
          }
          debugPrint('🧹 Cleared ${files.length} temp items');
        }
        
        // 2. Clear old APK downloads
        final appDocsDir = await getApplicationDocumentsDirectory();
        final apkFiles = appDocsDir.listSync().where((f) => f.path.endsWith('.apk')).toList();
        for (var apk in apkFiles) {
          try {
            await apk.delete();
            deletedFiles++;
            debugPrint('🧹 Deleted APK: ${apk.path}');
          } catch (_) {}
        }
        
        // 3. Clear old Excel exports (older than 7 days)
        final excelFiles = appDocsDir.listSync().where((f) => f.path.endsWith('.xlsx')).toList();
        final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
        for (var excel in excelFiles) {
          try {
            final stat = await excel.stat();
            if (stat.modified.isBefore(oneWeekAgo)) {
              await excel.delete();
              deletedFiles++;
              debugPrint('🧹 Deleted old Excel: ${excel.path}');
            }
          } catch (_) {}
        }
        
        // Mark as cleaned
        await prefs.setInt('last_cleanup_build', currentBuild);
        debugPrint('✅ Cleanup completed: $deletedFiles files deleted');
      } else {
        debugPrint('🧹 Cleanup skipped - already cleaned for this build');
      }
    } catch (e) {
      debugPrint('⚠️ Cleanup error: $e');
    }
  }
}
