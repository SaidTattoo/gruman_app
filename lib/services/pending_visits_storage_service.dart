import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PendingVisitsStorageService {
  static final PendingVisitsStorageService _instance =
      PendingVisitsStorageService._();
  static PendingVisitsStorageService get instance => _instance;

  PendingVisitsStorageService._();

  Future<Database> _getDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pending_visits.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_visits(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            visit_id INTEGER NOT NULL,
            payload TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            attempts INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending',
            error_message TEXT
          )
        ''');
      },
    );
  }

  Future<void> savePendingVisit(
      int visitId, Map<String, dynamic> payload) async {
    final db = await _getDatabase();

    await db.insert(
      'pending_visits',
      {
        'visit_id': visitId,
        'payload': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('\n======= VISITA GUARDADA EN LOCAL =======');
    print('ID Visita: $visitId');
    print('Fecha: ${DateTime.now()}');

    print('\nDETALLES:');
    print(
        '- Firma cliente: ${payload['firma_cliente'] != null ? 'Presente' : 'No presente'}');

    print('\nREPUESTOS POR SUBITEM:');
    (payload['repuestos'] as Map<String, dynamic>).forEach((subItemId, data) {
      print('\n📋 SubItem ID: $subItemId');
      print('  └─ Estado: ${data['estado']}');
      print('  └─ Comentario: ${data['comentario']}');
      print('  └─ Fotos: ${(data['fotos'] as List).length}');

      final repuestos = data['repuestos'] as List;
      if (repuestos.isNotEmpty) {
        print('  └─ Repuestos:');
        for (var repuesto in repuestos) {
          print(
              '     • ${repuesto['repuesto']['nombre']} (${repuesto['cantidad']} unidades)');
        }
      }
    });

    print('\nCHECKLIST CLIMA:');
    final checklistClima = payload['checklistClima'] as List;
    for (var activo in checklistClima) {
      print('\n🔧 Activo ID: ${activo['activoFijoId']}');
      print('  └─ Mediciones registradas: ${activo['mediciones'].length}');
    }

    print('\nACTIVOS FIJOS:');
    final activoFijoRepuestos = payload['activoFijoRepuestos'] as List;
    for (var activo in activoFijoRepuestos) {
      print('\n🔧 Activo ID: ${activo['id']}');
      print('  └─ Estado: ${activo['estadoOperativo']}');
      print('  └─ Repuestos: ${(activo['repuestos'] as List).length}');
    }

    print('\nGuardado en SQLite correctamente');
    print('===============================\n');
  }

  Future<List<Map<String, dynamic>>> getPendingVisits() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> results = await db.query(
      'pending_visits',
      where: 'status = ?',
      whereArgs: ['pending'],
    );

    return results.map((row) {
      return {
        'id': row['id'],
        'visit_id': row['visit_id'],
        'payload': jsonDecode(row['payload'] as String),
        'created_at': DateTime.parse(row['created_at'] as String),
        'attempts': row['attempts'],
      };
    }).toList();
  }

  Future<void> updateVisitStatus(int id, String status,
      {String? errorMessage}) async {
    final db = await _getDatabase();

    await db.rawUpdate(
      'UPDATE pending_visits SET status = ?, error_message = ?, attempts = attempts + 1 WHERE id = ?',
      [status, errorMessage, id],
    );
  }

  Future<void> deletePendingVisit(int id) async {
    final db = await _getDatabase();
    await db.delete(
      'pending_visits',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
