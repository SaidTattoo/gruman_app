import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/repuesto_model.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

class LocalDatabase {
  static Database? _database;
  static final LocalDatabase _instance = LocalDatabase._();

  LocalDatabase._();
  factory LocalDatabase() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (!kIsWeb) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      await Directory(documentsDirectory.path).create(recursive: true);
      final path = join(documentsDirectory.path, 'atlantis8.db');
      print('DB Path: $path');

      return await openDatabase(
        path,
        version: 3,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) {
          print('Base de datos abierta correctamente');
        },
      );
    } catch (e) {
      print('Error inicializando base de datos: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY,
        email TEXT NOT NULL,
        name TEXT NOT NULL,
        rut TEXT NOT NULL,
        profile TEXT NOT NULL,
        isOffline INTEGER DEFAULT 0,
        especialidades TEXT,
        clients TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS solicitudes (
        id INTEGER PRIMARY KEY,
        data TEXT NOT NULL,
        hora_inicio_servicio TEXT,
        latitud_movil TEXT,
        longitud_movil TEXT,
        hora_fin_servicio TEXT,
        ACTIVO_FIJO INTEGER NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_fotos (
        id INTEGER PRIMARY KEY,
        itemId INTEGER NOT NULL,
        solicitarVisitaId INTEGER NOT NULL,
        fotos TEXT NOT NULL,
        created_at TEXT NOT NULL,
        activoFijoId INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repuestos (
        id INTEGER PRIMARY KEY,
        articulo TEXT NOT NULL,
        familia TEXT NOT NULL,
        marca TEXT NOT NULL,
        codigoBarra TEXT NOT NULL,
        precio_compra REAL NOT NULL,
        precio_venta REAL NOT NULL,
        valor_uf REAL NOT NULL,
        clima INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS repuestos_clima (
        id INTEGER PRIMARY KEY,
        articulo TEXT NOT NULL,
        familia TEXT NOT NULL,
        marca TEXT NOT NULL,
        codigoBarra TEXT NOT NULL,
        precio_compra REAL NOT NULL,
        precio_venta REAL NOT NULL,
        valor_uf REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_repuestos (
        id INTEGER PRIMARY KEY,
        itemId INTEGER NOT NULL,
        repuestoId INTEGER NOT NULL,
        cantidad TEXT NOT NULL,
        comentario TEXT NOT NULL,
        solicitarVisitaId INTEGER NOT NULL,
        estado TEXT NOT NULL,
        precio_venta TEXT NOT NULL,
        precio_compra TEXT NOT NULL,
        activoFijoId INTEGER
        )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS item_estado (
        id INTEGER PRIMARY KEY,
        itemId INTEGER NOT NULL,
        solicitarVisitaId INTEGER NOT NULL,
        comentario TEXT,
        estado TEXT NOT NULL,
        activoFijoId INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS checklist_clima (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activoFijoId INTEGER NOT NULL,
        solicitarVisitaId INTEGER NOT NULL,
        medicion_SetPoint TEXT NOT NULL,
        medicion_TempInjeccionFrio TEXT NOT NULL,
        medicion_TempInjeccionCalor TEXT NOT NULL,
        medicion_TempAmbiente TEXT NOT NULL,
        medicion_TempRetorno TEXT NOT NULL,
        medicion_TempExterior TEXT NOT NULL,
        medicion_SetPoint_observacion TEXT NOT NULL,
        medicion_TempInjeccionFrio_observacion TEXT NOT NULL,
        medicion_TempInjeccionCalor_observacion TEXT NOT NULL,
        medicion_TempAmbiente_observacion TEXT NOT NULL,
        medicion_TempRetorno_observacion TEXT NOT NULL,
        medicion_TempExterior_observacion TEXT NOT NULL,
        consumoCompresor_R TEXT NOT NULL,
        consumoCompresor_S TEXT NOT NULL,
        consumoCompresor_T TEXT NOT NULL,
        consumoCompresor_N TEXT NOT NULL,
        tension_R_S TEXT NOT NULL,
        tension_S_T TEXT NOT NULL,
        tension_T_R TEXT NOT NULL,
        tension_T_N TEXT NOT NULL,
        consumo_total_R TEXT NOT NULL,
        consumo_total_S TEXT NOT NULL,
        consumo_total_T TEXT NOT NULL,
        consumo_total_N TEXT NOT NULL,
        presiones_altas TEXT NOT NULL,
        presiones_bajas TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Actualizando DB de versión $oldVersion a $newVersion');

    if (oldVersion < 3) {
      // Crear las nuevas tablas si no existen
      await db.execute('''
        CREATE TABLE IF NOT EXISTS item_estado (
          id INTEGER PRIMARY KEY,
          itemId INTEGER NOT NULL,
          solicitarVisitaId INTEGER NOT NULL,
          comentario TEXT,
          estado TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS item_fotos (
          id INTEGER PRIMARY KEY,
          itemId INTEGER NOT NULL,
          solicitarVisitaId INTEGER NOT NULL,
          fotos TEXT NOT NULL,
          created_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS item_repuestos (
          id INTEGER PRIMARY KEY,
          itemId INTEGER NOT NULL,
          repuestoId INTEGER NOT NULL,
          cantidad TEXT NOT NULL,
          comentario TEXT NOT NULL,
          solicitarVisitaId INTEGER NOT NULL,
          estado TEXT NOT NULL,
          precio_venta TEXT NOT NULL,
          precio_compra TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> iniciarServicio(int id, String latitud, String longitud) async {
    try {
      final db = await database;
      final horaInicio = DateTime.now().toIso8601String();
      final existe =
          await db.query('solicitudes', where: 'id = ?', whereArgs: [id]);

      if (existe.isEmpty) {
        print('Error: No existe la solicitud $id en la DB local');
        throw Exception('La solicitud no existe en la base de datos local');
      }

      final result = await db.update(
        'solicitudes',
        {
          'hora_inicio_servicio': horaInicio,
          'latitud_movil': latitud,
          'longitud_movil': longitud
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      print(
          'Servicio iniciado en DB: ID: $id, Hora: $horaInicio, Lat: $latitud, Long: $longitud');
      await _printSolicitudesTable();
    } catch (e) {
      print('Error en iniciarServicio: $e');
      rethrow;
    }
  }

  Future finalizarServicio(int id) async {
    final db = await database;
    await db.update(
      'solicitudes',
      {'hora_fin_servicio': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _printSolicitudesTable();
  }

  Future insertUser(UserModel user) async {
    try {
      final db = await database;
      int count = await db.update(
        'users',
        user.toJson(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      if (count == 0) {
        await db.insert('users', user.toJson());
        print('Usuario nuevo insertado en DB local');
      } else {
        print('Usuario existente actualizado en DB local');
      }

      await _printUsersTable();
    } catch (e) {
      print('Error en insertUser: $e');
      rethrow;
    }
  }

  Future<void> subirListadoRepuestos(List<Repuesto> repuestos) async {
    try {
      final db = await database;

      // Primero limpiamos la tabla
      await db.delete('repuestos');

      final batch = db.batch();
      for (var repuesto in repuestos) {
        var data = repuesto.toJson();

        // Convertir valores booleanos a enteros
        data['clima'] = data['clima'] == true ? 1 : 0;
        data['valor_uf'] = data['valor_uf'] is bool ? 0 : data['valor_uf'];

        batch.insert('repuestos', data);
      }
      await batch.commit(noResult: true);
      print('Repuestos guardados exitosamente: ${repuestos.length}');

      // Mostrar la tabla de repuestos
      await _printListadoRepuestos(repuestos);
    } catch (e) {
      print('Error en subirListadoRepuestos: $e');
      rethrow;
    }
  }

  Future<void> subirListadoRepuestosClima(List<Repuesto> repuestos) async {
    try {
      final db = await database;
      await db.delete('repuestos_clima');

      final batch = db.batch();
      for (var repuesto in repuestos) {
        var data = repuesto.toJson();
        // Remover el campo clima que no existe en la tabla repuestos_clima
        data.remove('clima');

        // Convertir valor_uf si es booleano
        data['valor_uf'] = data['valor_uf'] is bool ? 0 : data['valor_uf'];

        batch.insert('repuestos_clima', data);
      }
      await batch.commit(noResult: true);
      print('Repuestos clima guardados exitosamente: ${repuestos.length}');
      await _printListadoRepuestosClima(repuestos);
    } catch (e) {
      print('Error en subirListadoRepuestosClima: $e');
      rethrow;
    }
  }

  Future<List<Repuesto>> listadoRepuestosClima() async {
    try {
      final db = await database;
      final result = await db.query('repuestos_clima');
      return result.map((json) => Repuesto.fromJson(json)).toList();
    } catch (e) {
      print('Error en listadoRepuestosClima: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listadoRepuestos() async {
    try {
      final db = await database;
      return await db.query('repuestos');
    } catch (e) {
      print('Error en listadoRepuestos: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getUser() async {
    final db = await database;
    final result = await db.query('users');
    return result.map((json) => UserModel.fromJson(json)).toList();
  }

  Future insertSolicitud(String jsonData) async {
    try {
      final db = await database;
      final Map<String, dynamic> data = jsonDecode(jsonData);
      final solicitudId = data['id'];

      final List<Map<String, dynamic>> result = await db.query(
        'solicitudes',
        where: 'id = ?',
        whereArgs: [solicitudId],
      );

      if (result.isEmpty) {
        await db.insert('solicitudes', {
          'id': solicitudId,
          'data': jsonData,
          'hora_inicio_servicio': null,
          'latitud_movil': null,
          'longitud_movil': null,
          'hora_fin_servicio': null
        });
        print('Nueva solicitud guardada en DB local: $solicitudId');
      } else {
        await db.update(
          'solicitudes',
          {'data': jsonData},
          where: 'id = ?',
          whereArgs: [solicitudId],
        );
        print('Solicitud actualizada en DB local: $solicitudId');
      }

      await _printSolicitudesTable();
    } catch (e) {
      print('Error en insertSolicitud: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSolicitudes() async {
    try {
      final db = await database;
      final result = await db.query('solicitudes');
      return result.map((row) {
        return jsonDecode(row['data'] as String) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      print('Error obteniendo solicitudes de DB local: $e');
      return [];
    }
  }

  Future<void> deleteSolicitud(int visitId) async {
    final db = await database;
    await db.delete(
      'solicitudes',
      where: 'id = ?',
      whereArgs: [visitId],
    );
  }

  Future<void> deleteAllSolicitudes() async {
    try {
      final db = await database;
      await db.delete('solicitudes');
      print('Todas las solicitudes eliminadas de la DB local');
      await _printSolicitudesTable();
    } catch (e) {
      print('Error eliminando solicitudes: $e');
      rethrow;
    }
  }

  Future<String?> getHoraInicioServicio(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'solicitudes',
        columns: ['hora_inicio_servicio'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isNotEmpty && result[0]['hora_inicio_servicio'] != null) {
        print('Hora inicio encontrada: ${result[0]['hora_inicio_servicio']}');
        return result[0]['hora_inicio_servicio'] as String;
      }
      return null;
    } catch (e) {
      print('Error en getHoraInicioServicio: $e');
      return null;
    }
  }

  Future<void> insertFoto(int itemId, int solicitudId, String foto,
      {String? createdAt, int? activoFijoId}) async {
    final db = await database;
    final data = {
      'itemId': itemId,
      'solicitarVisitaId': solicitudId,
      'fotos': foto,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    };

    if (activoFijoId != null) {
      data['activoFijoId'] = activoFijoId;
    }

    await db.insert('item_fotos', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertRepuesto(
      int itemId, Repuesto repuesto, int cantidad, int visitId,
      {int? activoFijoId}) async {
    try {
      final db = await database;
      final whereArgs = [itemId, repuesto.id, visitId];
      final existingRepuesto = await db.query(
        'item_repuestos',
        where: 'itemId = ? AND repuestoId = ? AND solicitarVisitaId = ?',
        whereArgs: whereArgs,
      );

      if (existingRepuesto.isEmpty) {
        final data = {
          'itemId': itemId,
          'repuestoId': repuesto.id,
          'cantidad': cantidad,
          'comentario': '',
          'solicitarVisitaId': visitId,
          'estado': 'pendiente',
          'precio_venta': repuesto.precio_venta,
          'precio_compra': repuesto.precio_compra,
        };

        if (activoFijoId != null) data['activoFijoId'] = activoFijoId;

        await db.insert('item_repuestos', data);
      } else {
        final updateData = {
          'cantidad': cantidad,
          'precio_venta': repuesto.precio_venta,
          'precio_compra': repuesto.precio_compra,
        };

        await db.update(
          'item_repuestos',
          updateData,
          where: 'itemId = ? AND repuestoId = ? AND solicitarVisitaId = ?',
          whereArgs: whereArgs,
        );
      }

      print('Repuesto guardado en DB local');
      await _printItemRepuestosTable();
    } catch (e) {
      print('Error en insertRepuesto: $e');
      rethrow;
    }
  }

  Future itemEstado(
      int itemId, String estado, int solicitarVisitaId, String comentario,
      {int? activoFijoId}) async {
    try {
      final db = await database;

      // Construir where y whereArgs dinámicamente basado en si activoFijoId es null
      String whereClause = 'itemId = ? AND solicitarVisitaId = ?';
      List<dynamic> whereArgs = [itemId, solicitarVisitaId];

      if (activoFijoId != null) {
        whereClause += ' AND activoFijoId = ?';
        whereArgs.add(activoFijoId);
      }

      final existe = await db.query(
        'item_estado',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (existe.isEmpty) {
        final data = {
          'itemId': itemId,
          'estado': estado,
          'solicitarVisitaId': solicitarVisitaId,
          'comentario': comentario,
        };

        if (activoFijoId != null) {
          data['activoFijoId'] = activoFijoId;
        }

        await db.insert('item_estado', data);
      } else {
        final updateData = {
          'estado': estado,
          'comentario': comentario,
        };

        await db.update(
          'item_estado',
          updateData,
          where: whereClause,
          whereArgs: whereArgs,
        );
      }

      print('Estado guardado en DB local');
      await _printItemEstadoTable();
    } catch (e) {
      print('Error en itemEstado: $e');
      rethrow;
    }
  }

  Future<void> changeEstado(int itemId, String estado, int solicitarVisitaId,
      {int? activoFijoId}) async {
    try {
      final db = await database;

      // Construir where y whereArgs dinámicamente
      String whereClause = 'itemId = ? AND solicitarVisitaId = ?';
      List<dynamic> whereArgs = [itemId, solicitarVisitaId];

      if (activoFijoId != null) {
        whereClause += ' AND activoFijoId = ?';
        whereArgs.add(activoFijoId);
      }

      // Verificar si existe el registro
      final existe = await db.query(
        'item_estado',
        where: whereClause,
        whereArgs: whereArgs,
      );

      if (existe.isEmpty) {
        // Si no existe, insertar nuevo registro
        final data = {
          'itemId': itemId,
          'estado': estado,
          'solicitarVisitaId': solicitarVisitaId,
          'comentario': '',
        };

        if (activoFijoId != null) {
          data['activoFijoId'] = activoFijoId;
        }

        await db.insert('item_estado', data);
      } else {
        // Si existe, actualizar
        final updateData = {'estado': estado};
        if (activoFijoId != null) {
          updateData['activoFijoId'] = activoFijoId.toString();
        }

        await db.update(
          'item_estado',
          updateData,
          where: whereClause,
          whereArgs: whereArgs,
        );
      }

      print('Estado actualizado: ItemID: $itemId, Estado: $estado');
      await _printItemEstadoTable();
    } catch (e) {
      print('Error en changeEstado: $e');
      rethrow;
    }
  }

  Future updateComentario(itemId, comentario) async {
    final db = await database;
    await db.update('item_estado', {'comentario': comentario},
        where: 'itemId = ?', whereArgs: [itemId]);
    await _printItemEstadoTable();
  }

  Future<List<Map<String, dynamic>>> getEstados(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future subirFoto(int itemId, String base64Image, int visitId,
      {int? activoFijoId}) async {
    try {
      final db = await database;
      final data = {
        'itemId': itemId,
        'solicitarVisitaId': visitId,
        'fotos': base64Image,
        'created_at': DateTime.now().toIso8601String(),
        'activoFijoId': activoFijoId,
      };

      if (activoFijoId != null) data['activoFijoId'] = activoFijoId;

      await db.insert('item_fotos', data);
      print('Foto guardada en DB local');
      await _printItemFotosTable();
    } catch (e) {
      print('Error en subirFoto: $e');
      rethrow;
    }
  }

  Future<void> eliminarFoto(itemId, solicitarVisitaId) async {
    final db = await database;
    await db.delete('item_fotos',
        where: 'itemId = ? AND solicitarVisitaId = ?',
        whereArgs: [itemId, solicitarVisitaId]);
    await _printItemFotosTable();
  }

  Future<List<Map<String, dynamic>>> getFotosItem(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<List<Map<String, dynamic>>> getRepuestos(
    int solicitarVisitaId, {
    int? activoFijoId,
  }) async {
    final db = await database;

    // Construir where y whereArgs dinámicamente
    String whereClause = 'solicitarVisitaId = ?';
    List<dynamic> whereArgs = [solicitarVisitaId];

    if (activoFijoId != null) {
      whereClause += ' AND activoFijoId = ?';
      whereArgs.add(activoFijoId);
    }

    final result = await db.query(
      'item_repuestos',
      where: whereClause,
      whereArgs: whereArgs,
    );

    return result.map((row) => row).toList();
  }

  Future getAllFotos() async {
    final db = await database;
    final result = await db.query('item_fotos');
    return result.map((row) {
      return row as Map<String, dynamic>;
    }).toList();
  }

  Future<Map<String, String?>> getCoordenadas(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'solicitudes',
        columns: ['latitud_movil', 'longitud_movil'],
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isNotEmpty) {
        return {
          'latitud': result[0]['latitud_movil'] as String?,
          'longitud': result[0]['longitud_movil'] as String?,
        };
      }
      return {'latitud': null, 'longitud': null};
    } catch (e) {
      print('Error en getCoordenadas: $e');
      return {'latitud': null, 'longitud': null};
    }
  }

  Future<void> _printItemFotosTable() async {
    final db = await database;
    final rows = await db.query('item_fotos');

    if (rows.isEmpty) {
      print('+----+----------+--------------------+----------+');
      print('| ID | ITEM_ID  | SOLICITAR_VISITA_ID | FOTOS   |');
      print('+----+----------+--------------------+----------+');
      print('| Tabla vacía: sin registros en "item_fotos"            |');
      print('+-------------------------------------------------------+');
      return;
    }

    print('+----+----------+--------------------+----------+');
    print('| ID | ITEM_ID  | SOLICITAR_VISITA_ID | FOTOS   |');
    print('+----+----------+--------------------+----------+');

    for (var row in rows) {
      final fotosStr = row['fotos'] as String;
      final fotosPreview =
          fotosStr.length > 8 ? fotosStr.substring(0, 8) : fotosStr;

      print('| ${row['id'].toString().padRight(2)} '
          '| ${_safeStr(row['itemId']).padRight(8)} '
          '| ${_safeStr(row['solicitarVisitaId']).padRight(18)} '
          '| ${fotosPreview.padRight(8)} |');
    }

    print('+----+----------+--------------------+----------+');
  }

  Future<void> _printListadoRepuestos(List<Repuesto> repuestos) async {
    final db = await database;
    final rows = await db.query('repuestos');
    if (rows.isEmpty) {
      print(
          '+----+----------+----------+----------+----------+----------+----------+');
      print(
          '| ID | ARTICULO | FAMILIA  | MARCA    | PRECIO VTA | PRECIO COMPRA |');
      print(
          '+----+----------+----------+----------+----------+----------+----------+');
      print('| Tabla vacía: sin registros en "repuestos"            |');
      print('+-------------------------------------------------------+');
      return;
    }
    print(
        '+----+----------+----------+----------+----------+----------+----------+');
    print(
        '| ID | ARTICULO | FAMILIA  | MARCA    | PRECIO VTA | PRECIO COMPRA |');
    print(
        '+----+----------+----------+----------+----------+----------+----------+');
    for (var row in rows) {
      print('| ${row['id'].toString().padRight(2)} '
          '| ${_safeStr(row['articulo']).padRight(10)} '
          '| ${_safeStr(row['familia']).padRight(10)} '
          '| ${_safeStr(row['marca']).padRight(10)} '
          '| ${_safeStr(row['precio_venta']).padRight(10)} '
          '| ${_safeStr(row['precio_compra']).padRight(10)} |');
    }
    print(
        '+----+----------+----------+----------+----------+----------+----------+');
  }

  Future<void> _printListadoRepuestosClima(List<Repuesto> repuestos) async {
    final db = await database;
    final rows = await db.query('repuestos_clima');
    if (rows.isEmpty) {
      print(
          '+----+----------+----------+----------+----------+----------+----------+');
      print(
          '| ID | ARTICULO | FAMILIA  | MARCA    | PRECIO VTA | PRECIO COMPRA |');
      print(
          '+----+----------+----------+----------+----------+----------+----------+');
      print('| Tabla vacía: sin registros en "repuestos_clima"            |');
      print('+-------------------------------------------------------+');
      return;
    }

    print(
        '+----+----------+----------+----------+----------+----------+----------+');
    print(
        '| ID | ARTICULO | FAMILIA  | MARCA    | PRECIO VTA | PRECIO COMPRA |');
    print(
        '+----+----------+----------+----------+----------+----------+----------+');
    for (var row in rows) {
      print('| ${row['id'].toString().padRight(2)} '
          '| ${_safeStr(row['articulo']).padRight(10)} '
          '| ${_safeStr(row['familia']).padRight(10)} '
          '| ${_safeStr(row['marca']).padRight(10)} '
          '| ${_safeStr(row['precio_venta']).padRight(10)} '
          '| ${_safeStr(row['precio_compra']).padRight(10)} |');
    }
    print(
        '+----+----------+----------+----------+----------+----------+----------+');
  }

  Future<void> _printItemEstadoTable() async {
    final db = await database;
    final rows = await db.query('item_estado');

    if (rows.isEmpty) {
      print(
          '+----+----------+--------------------+----------+--------------------+');
      print(
          '| ID | ITEM_ID  | SOLICITAR_VISITA_ID | COMENTARIO | ESTADO             |');
      print(
          '+----+----------+--------------------+----------+--------------------+');
      print('| Tabla vacía: sin registros en "item_estado"            |');
      print('+-------------------------------------------------------+');
      return;
    }

    print(
        '+----+----------+--------------------+----------+--------------------+');
    print(
        '| ID | ITEM_ID  | SOLICITAR_VISITA_ID | COMENTARIO | ESTADO             |');
    print(
        '+----+----------+--------------------+----------+--------------------+');

    for (var row in rows) {
      print('| ${row['id'].toString().padRight(2)} '
          '| ${_safeStr(row['itemId']).padRight(8)} '
          '| ${_safeStr(row['solicitarVisitaId']).padRight(18)} '
          '| ${_safeStr(row['comentario']).padRight(11)} '
          '| ${_safeStr(row['estado']).padRight(11)} |');
    }

    print('+----+----------+--------------------+----------+');
  }

  Future<void> _printItemRepuestosTable() async {
    final db = await database;
    final rows = await db.query('item_repuestos');

    if (rows.isEmpty) {
      print('\n=== TABLA ITEM_REPUESTOS (vacía) ===');
      return;
    }

    print('\n=== TABLA ITEM_REPUESTOS ===');
    print('+---------+-----------+----------+----------+-----------------+');
    print('| ITEM_ID | REPUESTO | CANTIDAD | VISITA_ID| PRECIO_VENTA   |');
    print('+---------+-----------+----------+----------+-----------------+');

    for (var row in rows) {
      print('| ${row['itemId'].toString().padRight(7)} '
          '| ${row['repuestoId'].toString().padRight(9)} '
          '| ${row['cantidad'].toString().padRight(8)} '
          '| ${row['solicitarVisitaId'].toString().padRight(8)} '
          '| ${row['precio_venta'].toString().padRight(13)} |');
    }
    print('+---------+-----------+----------+----------+-----------------+\n');
  }

  Future<void> _printSolicitudesTable() async {
    final db = await database;
    final rows = await db.query('solicitudes');

    if (rows.isEmpty) {
      print(
          '+----+----------------+-------------------------+---------------+----------------+-------------------------+');
      print(
          '| ID |      DATA      | HORA_INICIO_SERVICIO   | LATITUD_MOVIL | LONGITUD_MOVIL | HORA_FIN_SERVICIO       |');
      print(
          '+----+----------------+-------------------------+---------------+----------------+-------------------------+');
      print(
          '| Tabla vacía: sin registros en "solicitudes"                                                        |');
      print(
          '+-----------------------------------------------------------------------------------------------+');
      return;
    }

    print(
        '+----+----------------+-------------------------+---------------+----------------+-------------------------+');
    print(
        '| ID |      DATA      | HORA_INICIO_SERVICIO   | LATITUD_MOVIL | LONGITUD_MOVIL | HORA_FIN_SERVICIO       |');
    print(
        '+----+----------------+-------------------------+---------------+----------------+-------------------------+');

    for (var row in rows) {
      print('| ${row['id'].toString().padRight(2)} '
          '| ${(row['data'] as String).substring(0, 14).padRight(14)} '
          '| ${_safeStr(row['hora_inicio_servicio']).padRight(23)} '
          '| ${_safeStr(row['latitud_movil']).padRight(13)} '
          '| ${_safeStr(row['longitud_movil']).padRight(14)} '
          '| ${_safeStr(row['hora_fin_servicio']).padRight(23)} |');
    }
    print(
        '+----+----------------+-------------------------+---------------+----------------+-------------------------+');
  }

  Future<void> _printChecklistClimaTable() async {
    final db = await database;
    final rows = await db.query('checklist_clima');

    if (rows.isEmpty) {
      print('La tabla checklist_clima está vacía');
      return;
    }

    print('+----+------------------+----------+-----------+---------+');
    print(
        '| ID | nRegistro            | Activo Fijo ID     | Solicitar Visita ID       | Set Point |');
    print('+----+------------------+----------+-----------+---------+');
    print('\n=== REGISTROS EN CHECKLIST_CLIMA ===');
    for (var row in rows) {
      print(
          '\nRegistro ID: ${row['id']} | Activo Fijo ID: ${row['activoFijoId']} | Solicitar Visita ID: ${row['solicitarVisitaId']} | Set Point: ${row['medicion_SetPoint']}');
      /*    print('Activo Fijo ID: ${row['activoFijoId']}');
      print('Solicitar Visita ID: ${row['solicitarVisitaId']}');

      print('\nMEDICIONES:');
      print('- Set Point: ${row['medicion_SetPoint']}');
      print('  Observación: ${row['medicion_SetPoint_observacion']}');
      print('- Temp. Inyección Frío: ${row['medicion_TempInjeccionFrio']}');
      print('  Observación: ${row['medicion_TempInjeccionFrio_observacion']}');
      print('- Temp. Inyección Calor: ${row['medicion_TempInjeccionCalor']}');
      print('  Observación: ${row['medicion_TempInjeccionCalor_observacion']}');
      print('- Temp. Ambiente: ${row['medicion_TempAmbiente']}');
      print('  Observación: ${row['medicion_TempAmbiente_observacion']}');
      print('- Temp. Retorno: ${row['medicion_TempRetorno']}');
      print('  Observación: ${row['medicion_TempRetorno_observacion']}');
      print('- Temp. Exterior: ${row['medicion_TempExterior']}');
      print('  Observación: ${row['medicion_TempExterior_observacion']}');

      print('\nCONSUMO COMPRESOR:');
      print('R: ${row['consumoCompresor_R']}');
      print('S: ${row['consumoCompresor_S']}');
      print('T: ${row['consumoCompresor_T']}');
      print('N: ${row['consumoCompresor_N']}');

      print('\nTENSIÓN:');
      print('R-S: ${row['tension_R_S']}');
      print('S-T: ${row['tension_S_T']}');
      print('T-R: ${row['tension_T_R']}');
      print('T-N: ${row['tension_T_N']}');

      print('\nCONSUMO TOTAL:');
      print('R: ${row['consumo_total_R']}');
      print('S: ${row['consumo_total_S']}');
      print('T: ${row['consumo_total_T']}');
      print('N: ${row['consumo_total_N']}');

      print('\nPRESIONES:');
      print('Altas: ${row['presiones_altas']}');
      print('Bajas: ${row['presiones_bajas']}');

      print('\nCreado en: ${row['created_at']}');
      print('----------------------------------------'); */
    }
  }

  Future<void> _printUsersTable() async {
    final db = await database;
    final rows = await db.query('users');

    if (rows.isEmpty) {
      print('+----+------------------+----------+-----------+---------+');
      print('| ID | EMAIL            | NAME     | RUT       | PROFILE |');
      print('+----+------------------+----------+-----------+---------+');
      print('| Tabla vacía: sin registros en "users"                  |');
      print('+--------------------------------------------------------+');
      return;
    }

    print('+----+------------------+----------+-----------+---------+');
    print('| ID | EMAIL            | NAME     | RUT       | PROFILE |');
    print('+----+------------------+----------+-----------+---------+');

    for (var row in rows) {
      print('| ${row['id'].toString().padRight(2)} '
          '| ${_safeStr(row['email']).padRight(16)} '
          '| ${_safeStr(row['name']).padRight(8)} '
          '| ${_safeStr(row['rut']).padRight(9)} '
          '| ${_safeStr(row['profile']).padRight(7)} |');
    }
    print('+----+------------------+----------+-----------+---------+');
  }

  String _safeStr(dynamic value) => value?.toString() ?? 'NULL';

  Future<void> deleteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'atlantis2.db');
    await File(path).delete();
    _database = null;
  }

  Future<void> actualizarCantidadRepuesto(
    int itemId,
    int repuestoId,
    int visitId,
    int nuevaCantidad,
  ) async {
    try {
      final db = await database;
      await db.update(
        'item_repuestos',
        {'cantidad': nuevaCantidad.toString()},
        where: 'itemId = ? AND repuestoId = ? AND solicitarVisitaId = ?',
        whereArgs: [itemId, repuestoId, visitId],
      );

      print('Cantidad actualizada en DB local:');
      print(
          'ItemID: $itemId, RepuestoID: $repuestoId, Nueva cantidad: $nuevaCantidad');
      await _printItemRepuestosTable();
    } catch (e) {
      print('Error actualizando cantidad de repuesto: $e');
      rethrow;
    }
  }

  Future<void> marcarComoPendienteDeSubir(int visitId) async {
    try {
      final db = await database;

      // Obtener la solicitud actual
      final List<Map<String, dynamic>> result = await db.query(
        'solicitudes',
        where: 'id = ?',
        whereArgs: [visitId],
      );

      if (result.isNotEmpty) {
        // Decodificar el JSON actual
        final Map<String, dynamic> data = json.decode(result.first['data']);

        // Actualizar el estado
        data['status'] = 'pendiente_de_subir';

        // Actualizar la solicitud con el nuevo JSON
        await db.update(
          'solicitudes',
          {'data': json.encode(data)},
          where: 'id = ?',
          whereArgs: [visitId],
        );

        print('Estado de solicitud $visitId actualizado a pendiente_de_subir');
      }
    } catch (e) {
      print('Error actualizando estado de solicitud: $e');
      throw Exception('Error actualizando estado de solicitud: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActivosFijos(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<void> saveChecklistClima(Map<String, dynamic> data) async {
    final db = await database;

    try {
      // Verificar que tenemos el ID del activo fijo
      if (data['activoFijoId'] == null) {
        throw Exception('activoFijoId es requerido');
      }

      // Verificar si ya existe un registro para este activo y visita
      final List<Map<String, dynamic>> existing = await db.query(
        'checklist_clima',
        where: 'activoFijoId = ? AND solicitarVisitaId = ?',
        whereArgs: [data['activoFijoId'], data['solicitarVisitaId']],
      );

      if (existing.isNotEmpty) {
        // Actualizar registro existente
        await db.update(
          'checklist_clima',
          data,
          where: 'activoFijoId = ? AND solicitarVisitaId = ?',
          whereArgs: [data['activoFijoId'], data['solicitarVisitaId']],
        );
        print('Registro actualizado para activo ${data['activoFijoId']}');
      } else {
        // Insertar nuevo registro
        await db.insert(
          'checklist_clima',
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('Nuevo registro creado para activo ${data['activoFijoId']}');
      }
    } catch (e) {
      print('Error insertando/actualizando en checklist_clima: $e');
      throw e;
    }
    _printChecklistClimaTable();
  }

  Future<Map<String, dynamic>> getChecklistClimaData(
      int activoFijoId, int solicitarVisitaId) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> result = await db.query(
        'checklist_clima',
        where: 'activoFijoId = ? AND solicitarVisitaId = ?',
        whereArgs: [activoFijoId, solicitarVisitaId],
      );

      print(
          'Buscando datos para activoFijo: $activoFijoId, visita: $solicitarVisitaId');
      print('Resultados encontrados: ${result.length}');

      if (result.isNotEmpty) {
        return result.first;
      }
      return {};
    } catch (e) {
      print('Error obteniendo datos del checklist: $e');
      return {};
    }
  }

  Future<void> clearChecklistClimaTable() async {
    try {
      final db = await database;
      await db.delete('checklist_clima');
      print('Tabla checklist_clima limpiada exitosamente');
    } catch (e) {
      print('Error limpiando tabla checklist_clima: $e');
      throw e;
    }
  }

  Future<void> deleteSolicitudVisita(int solicitudId) async {
    try {
      final db = await database;

      // Primero eliminamos los registros relacionados en checklist_clima
      await db.delete(
        'checklist_clima',
        where: 'solicitarVisitaId = ?',
        whereArgs: [solicitudId],
      );

      // Luego eliminamos la solicitud
      await db.delete(
        'solicitudes',
        where: 'id = ?',
        whereArgs: [solicitudId],
      );

      print(
          'Solicitud $solicitudId y sus datos relacionados eliminados correctamente');
    } catch (e) {
      print('Error eliminando solicitud: $e');
      throw e;
    }
  }
}
