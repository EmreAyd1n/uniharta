import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/event_model.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'uniharita_cache.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await _cleanupExpiredEvents(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_events (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        category TEXT,
        latitude REAL,
        longitude REAL,
        start_time TEXT,
        end_time TEXT,
        is_active INTEGER,
        organizer_id TEXT,
        building_id TEXT,
        created_at TEXT
      )
    ''');
  }

  Future<void> _cleanupExpiredEvents(Database db) async {
    // 2 gün öncesinden eski etkinlikleri sil (end_time genelde boş olabilir diye start_time kullanıyoruz)
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
    try {
      await db.delete(
        'cached_events',
        where: 'start_time < ?',
        whereArgs: [twoDaysAgo],
      );
    } catch (e) {
      print('Cleanup cached events error: $e');
    }
  }

  Future<void> cacheEvents(List<EventModel> events) async {
    final db = await database;
    Batch batch = db.batch();

    for (final event in events) {
      final data = event.toJson();
      // SQLite'da boolean yerine 0/1 kullanılır, toJson is_active'i bool dönüyor.
      data['is_active'] = data['is_active'] == true ? 1 : 0;
      data['id'] = event.id; // EventModel.toJson() id'yi içermiyor.
      data['created_at'] = event.createdAt.toIso8601String(); // toJson() içinde yok.

      batch.insert(
        'cached_events',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    try {
      await batch.commit(noResult: true);
    } catch (e) {
      print('Cache events error: $e');
    }
  }

  Future<List<EventModel>> getCachedEvents({String? category}) async {
    try {
      final db = await database;
      
      String whereClause = 'is_active = ?';
      List<dynamic> whereArgs = [1];
      
      if (category != null) {
        whereClause += ' AND category = ?';
        whereArgs.add(category);
      }

      final maps = await db.query(
        'cached_events',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'start_time ASC',
      );

      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      List<EventModel> events = [];
      for (final map in maps) {
        final mutableMap = Map<String, dynamic>.from(map);
        // SQLite'dan 0/1 dönen is_active'i bool'a çeviriyoruz
        mutableMap['is_active'] = mutableMap['is_active'] == 1;

        final event = EventModel.fromJson(mutableMap);
        // Sadece bugün veya gelecekteki etkinlikleri döndür
        if (event.startTime.isAfter(todayStart) || event.startTime.isAtSameMomentAs(todayStart)) {
          events.add(event);
        }
      }
      return events;
    } catch (e) {
      print('Get cached events error: $e');
      return [];
    }
  }
}
