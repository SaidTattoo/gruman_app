import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class SolicitudesStorageService {
  static final SolicitudesStorageService instance =
      SolicitudesStorageService._();

  SolicitudesStorageService._();

  Future<Database> getDatabase() async {
    if (kIsWeb) throw Exception('SQLite no disponible en web');

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'solicitudes.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE solicitudes(
            id INTEGER PRIMARY KEY,
            local_id INTEGER,
            fecha_visita TEXT,
            status TEXT,
            tipo_mantenimiento TEXT,
            data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        print('Tabla solicitudes creada correctamente');
      },
    );
  }

  Future<void> saveSolicitudes(List<dynamic> solicitudes) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('stored_solicitudes', jsonEncode(solicitudes));
        print(
            'Solicitudes guardadas en SharedPreferences: ${solicitudes.length}');
      } else {
        final db = await getDatabase();
        final batch = db.batch();

        // Limpiar tabla
        batch.execute('DELETE FROM solicitudes');

        // Insertar nuevas solicitudes
        for (var solicitud in solicitudes) {
          batch.insert('solicitudes', {
            'id': solicitud['id'],
            'local_id': solicitud['local']['id'],
            'fecha_visita': solicitud['fechaVisita'],
            'status': solicitud['status'],
            'tipo_mantenimiento': solicitud['tipo_mantenimiento'],
            'data': jsonEncode(solicitud),
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        await batch.commit();
        print('Solicitudes guardadas en SQLite: ${solicitudes.length}');
      }
    } catch (e) {
      print('Error guardando solicitudes: $e');
      throw Exception('Error guardando solicitudes: $e');
    }
  }

  Future<List<dynamic>> getSolicitudes() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString('stored_solicitudes');
        if (storedData != null) {
          return jsonDecode(storedData);
        }
      } else {
        final db = await getDatabase();
        final List<Map<String, dynamic>> results =
            await db.query('solicitudes');
        return results.map((row) => jsonDecode(row['data'] as String)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo solicitudes: $e');
      return [];
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  Future<void> checkAndCreateTable() async {
    try {
      if (kIsWeb) return;

      final db = await getDatabase();
      final exists = await _tableExists(db, 'solicitudes');

      print('Tabla solicitudes existe: $exists');

      // Imprimir todas las tablas y su contenido
      await printTablesAndContent(db);

      if (!exists) {
        await db.execute('''
          CREATE TABLE solicitudes(
            id INTEGER PRIMARY KEY,
            local_id INTEGER,
            fecha_visita TEXT,
            status TEXT,
            tipo_mantenimiento TEXT,
            data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        print('Tabla solicitudes creada');
      }
    } catch (e) {
      print('Error verificando/creando tabla: $e');
    }
  }

  Future<void> printTablesAndContent(Database db) async {
    try {
      // Obtener todas las tablas existentes
      final List<Map<String, dynamic>> tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table';");

      print('\n=== TABLAS EN SQLITE ===');
      for (var table in tables) {
        String tableName = table['name'];
        print('\nTabla: $tableName');
        print('-------------------');

        final List<Map<String, dynamic>> tableContent =
            await db.rawQuery('SELECT * FROM $tableName');

        if (tableContent.isEmpty) {
          print('(Tabla vacía)');
        } else {
          for (var row in tableContent) {
            print(row);
          }
        }
      }
      print('\n=====================');
    } catch (e) {
      print('Error al imprimir tablas: $e');
    }
  }
}
