import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Usa la IP de tu computadora (la puedes obtener con ipconfig en Windows o ifconfig en Mac/Linux)
  //static const String baseUrl =
  //   'http://138.255.103.35:3000'; // URL de producción
  static const String baseUrl = 'http://localhost:3000'; // URL de desarrollo

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
      print('Calling: $baseUrl/$endpoint');
      print('Data: $data');

      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await _headers,
        body: jsonEncode(data),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error details: $e');
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
