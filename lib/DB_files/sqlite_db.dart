import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class RecipeDatabase {
  static final RecipeDatabase _instance = RecipeDatabase._();
  static Database? _database;

  factory RecipeDatabase() {
    return _instance;
  }

  RecipeDatabase._();

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initializeDatabase();
    return _database!;
  }

  static Future<Database> initializeDatabase() async {
    final path = join(await getDatabasesPath(), 'myDatabase.db');
    return openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE recipes(id TEXT PRIMARY KEY, title TEXT, imageUrl TEXT, sourceUrl TEXT)',
        );
      },
      version: 1,
    );
  }

  static Future<void> saveRecipes(List<dynamic> recipes) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final recipe in recipes) {
        batch.insert(
          'recipes',
          {
            'id': recipe['id'].toString(),
            'title': recipe['title'].toString(),
            'imageUrl': recipe['image'].toString(),
            'sourceUrl': recipe['sourceUrl'].toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> getRecipes() async {
    final db = await database;
    return db.query('recipes');
  }
}
