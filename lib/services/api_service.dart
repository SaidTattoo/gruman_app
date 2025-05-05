import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000'; // Web and other platforms
    } else {
      return 'http://10.0.2.2:3000'; // Android emulator localhost
    }
  }

  static const int timeoutDuration = 10; // segundos

  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Método GET genérico
  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await _headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en la solicitud GET: $e');
    }
  }

  // Método POST genérico
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      print('Iniciando POST request a: $baseUrl/$endpoint');

      final headers = endpoint == 'auth/login_tecnico'
          ? {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            }
          : await _headers;

      print('Headers: $headers');
      print('Body: ${jsonEncode(data)}');

      final response = await http
          .post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      )
          .timeout(
        const Duration(seconds: timeoutDuration),
        onTimeout: () {
          throw TimeoutException('La conexión tardó demasiado');
        },
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        print('Respuesta decodificada: $decodedResponse');
        return decodedResponse;
      } else {
        throw HttpException('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      print('Error: Timeout de conexión');
      throw Exception(
          'No se pudo conectar al servidor. Por favor, verifica tu conexión.');
    } on SocketException catch (e) {
      print('Error de Socket: $e');
      throw Exception(
          'No se pudo conectar al servidor. Verifica que el servidor esté funcionando.');
    } catch (e) {
      print('Error detallado en POST request: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  static Future<http.Response> finalizarVisita(
      int visitId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    return http.post(
      Uri.parse('$baseUrl/solicitar-visita/finalizar-servicio/$visitId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );
  }
}
