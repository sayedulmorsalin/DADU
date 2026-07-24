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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            body TEXT,
            image TEXT,
            link TEXT,
            createdAt TEXT,
            isRead INTEGER DEFAULT 0
          )
        ''');
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
    final result = await db.rawQuery('SELECT COUNT(*) FROM notifications WHERE isRead = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
