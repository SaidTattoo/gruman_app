import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart'
    if (dart.library.html) 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class ChecklistJsonStorageService {
  static final ChecklistJsonStorageService _instance =
      ChecklistJsonStorageService._();
  static ChecklistJsonStorageService get instance => _instance;

  ChecklistJsonStorageService._();

  Future<void> saveChecklistData(Map<String, dynamic> data) async {
    if (kIsWeb) {
      // En web, usar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('checklist_data', jsonEncode(data));
    } else {
      // En móvil, usar SQLite
      final db = await _getDatabase();
      await db.delete('checklist_data');
      await db.insert(
        'checklist_data',
        {
          'data': jsonEncode(data),
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    }

    // Log para debug
    print('\n======= GUARDANDO CHECKLIST =======');
    print('Timestamp: ${DateTime.now()}');

    print('\nESTADO ACTUAL DEL CHECKLIST:');
    print(
        '- Firma cliente: ${data['firma_cliente'] != null ? 'Presente' : 'No presente'}');

    print('\nDETALLES POR SUBITEM:');
    (data['repuestos'] as Map<String, dynamic>)
        .forEach((subItemId, subItemData) {
      print('\n📋 SubItem ID: $subItemId');
      print('  └─ Estado: ${subItemData['estado']}');
      print('  └─ Comentario: ${subItemData['comentario']}');
      print('  └─ Fotos: ${(subItemData['fotos'] as List).length}');

      final repuestos = subItemData['repuestos'] as List;
      if (repuestos.isNotEmpty) {
        print('  └─ Repuestos:');
        for (var repuesto in repuestos) {
          print(
              '     • ${repuesto['repuesto']['nombre']} (${repuesto['cantidad']} unidades)');
        }
      }
    });
    print('===============================\n');
  }

  Future<Map<String, dynamic>?> loadChecklistData() async {
    if (kIsWeb) {
      // En web, usar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('checklist_data');
      if (jsonString != null) {
        return jsonDecode(jsonString);
      }
    } else {
      // En móvil, usar SQLite
      final db = await _getDatabase();
      final List<Map<String, dynamic>> results =
          await db.query('checklist_data');
      if (results.isNotEmpty) {
        return jsonDecode(results.first['data'] as String);
      }
    }
    return null;
  }

  Future<void> deleteChecklistData() async {
    print('\n=== ELIMINANDO CHECKLIST ===');
    final db = await _getDatabase();
    await db.delete('checklist_data');
    print('Datos eliminados');
  }

  Future<void> updateFirmaCliente(String base64Signature) async {
    print('\n=== ACTUALIZANDO FIRMA CLIENTE ===');
    final data = await loadChecklistData() ?? {};
    data['firma_cliente'] = base64Signature;
    await saveChecklistData(data);
  }

  Future<void> updateEstadoSubItem(int subItemId, String estado) async {
    print('\n=== ACTUALIZANDO ESTADO SUBITEM $subItemId ===');
    final data = await loadChecklistData() ?? {'repuestos': {}};
    if (!data.containsKey('repuestos')) {
      data['repuestos'] = {};
    }

    if (!data['repuestos'].containsKey(subItemId.toString())) {
      data['repuestos'][subItemId.toString()] = {
        'id': subItemId,
        'estado': estado,
        'comentario': '',
        'fotos': [],
        'repuestos': []
      };
    } else {
      data['repuestos'][subItemId.toString()]['estado'] = estado;
    }
    await saveChecklistData(data);
  }

  Future<void> updateComentarioSubItem(int subItemId, String comentario) async {
    print('\n=== ACTUALIZANDO COMENTARIO SUBITEM $subItemId ===');
    final data = await loadChecklistData() ?? {'repuestos': {}};
    if (!data.containsKey('repuestos')) {
      data['repuestos'] = {};
    }

    if (!data['repuestos'].containsKey(subItemId.toString())) {
      data['repuestos'][subItemId.toString()] = {
        'id': subItemId,
        'estado': 'conforme',
        'comentario': comentario,
        'fotos': [],
        'repuestos': []
      };
    } else {
      data['repuestos'][subItemId.toString()]['comentario'] = comentario;
    }
    await saveChecklistData(data);
  }

  Future<void> addFotoSubItem(int subItemId, String fotoUrlOrBase64) async {
    print('\n=== AGREGANDO FOTO A SUBITEM $subItemId ===');
    final data = await loadChecklistData() ?? {'repuestos': {}};
    if (!data.containsKey('repuestos')) {
      data['repuestos'] = {};
    }

    if (!data['repuestos'].containsKey(subItemId.toString())) {
      data['repuestos'][subItemId.toString()] = {
        'id': subItemId,
        'estado': 'conforme',
        'comentario': '',
        'fotos': [fotoUrlOrBase64],
        'repuestos': []
      };
    } else {
      data['repuestos'][subItemId.toString()]['fotos'] ??= [];
      data['repuestos'][subItemId.toString()]['fotos'].add(fotoUrlOrBase64);
    }
    await saveChecklistData(data);
  }

  Future<void> addRepuestoSubItem(
      int subItemId, Map<String, dynamic> repuesto) async {
    print('\n=== AGREGANDO REPUESTO A SUBITEM $subItemId ===');
    final data = await loadChecklistData() ?? {'repuestos': {}};
    if (!data.containsKey('repuestos')) {
      data['repuestos'] = {};
    }

    if (!data['repuestos'].containsKey(subItemId.toString())) {
      data['repuestos'][subItemId.toString()] = {
        'id': subItemId,
        'estado': 'conforme',
        'comentario': '',
        'fotos': [],
        'repuestos': [repuesto]
      };
    } else {
      data['repuestos'][subItemId.toString()]['repuestos'] ??= [];
      data['repuestos'][subItemId.toString()]['repuestos'].add(repuesto);
    }
    await saveChecklistData(data);
  }

  Future<Database> _getDatabase() async {
    try {
      if (kIsWeb) {
        databaseFactory = databaseFactoryFfi;
      }

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'checklist_data.db');

      return openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE checklist_data(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data TEXT NOT NULL,
              created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        },
      );
    } catch (e) {
      print('Error inicializando base de datos: $e');
      throw Exception('Error inicializando base de datos: $e');
    }
  }
}
