import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  // Método para guardar datos según la plataforma
  Future<void> saveSolicitudesVisita(List<dynamic> solicitudes) async {
    try {
      if (kIsWeb) {
        // Para web, usar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('solicitudes_cache', jsonEncode(solicitudes));
        print(
            'Solicitudes guardadas en SharedPreferences: ${solicitudes.length}');
      } else {
        // Para móvil, usar SQLite
        final db = await getDatabase();
        final batch = db.batch();

        // Limpiar datos antiguos
        batch.delete('solicitudes_visita');

        // Insertar nuevos datos
        for (var solicitud in solicitudes) {
          batch.insert('solicitudes_visita', {
            'id': solicitud['id'],
            'data': jsonEncode(solicitud),
            'last_updated': DateTime.now().toIso8601String(),
          });
        }

        await batch.commit();
        print('Solicitudes guardadas en SQLite: ${solicitudes.length}');
      }
    } catch (e) {
      print('Error guardando solicitudes: $e');
      rethrow;
    }
  }

  // Método para obtener datos según la plataforma
  Future<List<dynamic>> getSolicitudesVisita() async {
    try {
      if (kIsWeb) {
        // Para web, usar SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString('solicitudes_cache');
        if (storedData != null) {
          return jsonDecode(storedData);
        }
      } else {
        // Para móvil, usar SQLite
        final db = await getDatabase();
        final results = await db.query('solicitudes_visita');
        return results.map((row) => jsonDecode(row['data'] as String)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo solicitudes: $e');
      return [];
    }
  }

  // Solo para móvil: inicializar base de datos SQLite
  Future<Database> getDatabase() async {
    if (kIsWeb) throw Exception('SQLite no disponible en web');

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'atlantis_cache.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabla existente para solicitudes
        await db.execute('''
          CREATE TABLE solicitudes_visita(
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Nueva tabla para visitas iniciadas offline
        await db.execute('''
          CREATE TABLE visitas_pendientes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            solicitud_id INTEGER,
            fecha_inicio TEXT,
            estado TEXT,
            data TEXT NOT NULL,
            sync_status TEXT DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // Tabla para repuestos
        await db.execute('''
          CREATE TABLE repuestos(
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            tipo TEXT NOT NULL,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  // Marcar solicitud como pendiente de sincronización
  Future<void> markSolicitudPendiente(int solicitudId) async {
    final db = await getDatabase();
    await db.update(
      'solicitudes_visita',
      {'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [solicitudId],
    );
  }

  // Obtener solicitudes pendientes de sincronización
  Future<List<dynamic>> getPendingSolicitudes() async {
    final db = await getDatabase();
    final results = await db.query(
      'solicitudes_visita',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
    );
    return results.map((row) => jsonDecode(row['data'] as String)).toList();
  }

  // Método genérico para guardar datos
  Future<void> saveData(String key, dynamic data) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, jsonEncode(data));
        print('Datos guardados en SharedPreferences: $key');
      } else {
        final db = await getDatabase();
        await db.insert(
          'solicitudes_visita',
          {
            'data': jsonEncode(data),
            'last_updated': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      print('Error guardando datos: $e');
      rethrow;
    }
  }

  // Método genérico para obtener datos
  Future<List<dynamic>> getData(String key) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString(key);
        if (storedData != null) {
          return [jsonDecode(storedData)];
        }
      } else {
        final db = await getDatabase();
        final results = await db.query('solicitudes_visita');
        return results.map((row) => jsonDecode(row['data'] as String)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo datos: $e');
      return [];
    }
  }

  // Método para eliminar datos
  Future<void> removeData(String table, int id) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(table);
      } else {
        final db = await getDatabase();
        await db.delete(
          'solicitudes_visita',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      print('Error eliminando datos: $e');
      rethrow;
    }
  }

  // Método para guardar inicio de visita offline
  Future<void> saveVisitaIniciada(
      int solicitudId, Map<String, dynamic> data) async {
    try {
      final db = await getDatabase();
      await db.insert('visitas_pendientes', {
        'solicitud_id': solicitudId,
        'fecha_inicio': DateTime.now().toIso8601String(),
        'estado': 'iniciada',
        'data': jsonEncode(data),
        'sync_status': 'pending'
      });
      print('Visita iniciada guardada localmente');
    } catch (e) {
      print('Error guardando visita iniciada: $e');
      rethrow;
    }
  }

  // Método para obtener visitas pendientes de sincronización
  Future<List<Map<String, dynamic>>> getVisitasPendientes() async {
    try {
      final db = await getDatabase();
      final results = await db.query('visitas_pendientes',
          where: 'sync_status = ?', whereArgs: ['pending']);
      return results.map((Map<String, dynamic> row) {
        final data = jsonDecode(row['data'] as String);
        return {
          ...data as Map<String, dynamic>,
          'fecha_inicio_offline': row['fecha_inicio'],
          'id': row['solicitud_id']
        };
      }).toList();
    } catch (e) {
      print('Error obteniendo visitas pendientes: $e');
      return [];
    }
  }

  // Método para marcar visita como sincronizada
  Future<void> markVisitaSincronizada(int solicitudId) async {
    try {
      final db = await getDatabase();
      await db.update('visitas_pendientes', {'sync_status': 'synced'},
          where: 'solicitud_id = ?', whereArgs: [solicitudId]);
    } catch (e) {
      print('Error marcando visita como sincronizada: $e');
      rethrow;
    }
  }

  // Método para guardar repuestos
  Future<void> saveRepuestos(List<dynamic> repuestos, String tipo) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('repuestos_${tipo}', jsonEncode(repuestos));
        print('Repuestos tipo $tipo guardados en SharedPreferences');
      } else {
        final db = await getDatabase();
        final batch = db.batch();

        // Eliminar repuestos anteriores del mismo tipo
        batch.delete('repuestos', where: 'tipo = ?', whereArgs: [tipo]);

        // Insertar nuevos repuestos
        for (var repuesto in repuestos) {
          batch.insert('repuestos', {
            'data': jsonEncode(repuesto),
            'tipo': tipo,
            'last_updated': DateTime.now().toIso8601String(),
          });
        }

        await batch.commit();
        print('Repuestos tipo $tipo guardados en SQLite');
      }
    } catch (e) {
      print('Error guardando repuestos: $e');
      rethrow;
    }
  }

  // Método para obtener repuestos
  Future<List<dynamic>> getRepuestos(String tipo) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString('repuestos_${tipo}');
        if (storedData != null) {
          return jsonDecode(storedData);
        }
      } else {
        final db = await getDatabase();
        final results = await db.query(
          'repuestos',
          where: 'tipo = ?',
          whereArgs: [tipo],
        );
        return results.map((row) => jsonDecode(row['data'] as String)).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo repuestos: $e');
      return [];
    }
  }
}
