import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/visit_model.dart';

class VisitsStorageService {
  static final VisitsStorageService instance = VisitsStorageService._();

  VisitsStorageService._();

  Future<void> saveVisits(List<Visit> visits) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final visitsJson = visits.map((v) => v.toJson()).toList();
        await prefs.setString('stored_visits', jsonEncode(visitsJson));
        print('Visitas guardadas en SharedPreferences: ${visits.length}');
      } else {
        final db = await _getDatabase();
        final batch = db.batch();

        batch.execute('DELETE FROM visits');

        for (var visit in visits) {
          batch.insert('visits', {
            'id': visit.id,
            'data': jsonEncode(visit.toJson()),
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        await batch.commit();
        print('Visitas guardadas en SQLite: ${visits.length}');
      }
    } catch (e) {
      print('Error guardando visitas: $e');
    }
  }

  Future<List<Visit>> getVisits() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final storedData = prefs.getString('stored_visits');
        if (storedData != null) {
          final List<dynamic> visitsJson = jsonDecode(storedData);
          return visitsJson.map((json) => Visit.fromJson(json)).toList();
        }
      } else {
        final db = await _getDatabase();
        final results = await db.query('visits');
        return results.map((row) {
          final visitJson = jsonDecode(row['data'] as String);
          return Visit.fromJson(visitJson);
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error obteniendo visitas: $e');
      return [];
    }
  }

  Future<Database> _getDatabase() async {
    if (kIsWeb) throw Exception('SQLite no disponible en web');
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'visits.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE visits(
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<void> deleteAllVisits() async {
    final db = await _getDatabase();
    await db.delete('visits');
    print('Todas las visitas eliminadas de SQLite');
  }

  Future<void> updateVisitStatus(int visitId, String status) async {
    final db = await _getDatabase();
    await db.update(
      'visits',
      {'sync_status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }
}
