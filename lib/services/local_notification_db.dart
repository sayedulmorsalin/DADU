import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalNotificationDb {
  static final LocalNotificationDb _instance = LocalNotificationDb._internal();
  factory LocalNotificationDb() => _instance;
  LocalNotificationDb._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'notifications.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            image TEXT,
            link TEXT,
            createdAt TEXT,
            isRead INTEGER DEFAULT 0,
            type TEXT DEFAULT 'general'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE notifications ADD COLUMN type TEXT DEFAULT 'general'");
        }
        
        // Final broad migration for Admin messages
        if (oldVersion < 4) {
          await db.execute('''
            UPDATE notifications 
            SET type = 'chat' 
            WHERE isRead = 0 AND (
              LOWER(title) LIKE '%message%' OR 
              LOWER(title) LIKE '%chat%' OR 
              LOWER(title) LIKE '%admin%' OR
              LOWER(body) LIKE '%message%' OR
              LOWER(body) LIKE '%chat%' OR
              LOWER(link) LIKE '%/message%'
            )
          ''');
        }
      },
    );
  }

  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', {
      'title': notification['title'],
      'body': notification['body'],
      'image': notification['image'],
      'link': notification['link'],
      'createdAt': notification['createdAt'] ?? DateTime.now().toIso8601String(),
      'isRead': 0,
      'type': notification['type'] ?? 'general',
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final db = await database;
    return await db.query('notifications', orderBy: 'createdAt DESC');
  }

  Future<int> markAsRead(int id) async {
    final db = await database;
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAllAsRead() async {
    final db = await database;
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: 'isRead = 0',
    );
  }

  Future<int> markMessagesAsRead() async {
    final db = await database;
    return await db.update(
      'notifications',
      {'isRead': 1},
      where: 'isRead = 0 AND type = ?',
      whereArgs: ['chat'],
    );
  }

  Future<int> deleteNotification(int id) async {
    final db = await database;
    return await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllNotifications() async {
    final db = await database;
    return await db.delete('notifications');
  }

  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM notifications WHERE isRead = 0 AND type != ?', ['chat']);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUnreadMessageCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM notifications WHERE isRead = 0 AND type = ?', ['chat']);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
