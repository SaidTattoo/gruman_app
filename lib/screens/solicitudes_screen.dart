import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/visit_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/cache_service.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({Key? key}) : super(key: key);

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  List<dynamic> _solicitudes = [];
  bool _isLoading = true;

  Future<UserModel?> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken');
    if (token != null) {
      final decodedToken = JwtDecoder.decode(token);
      return UserModel.fromDecodedToken(decodedToken);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadSolicitudes();
  }

  Future<void> _loadSolicitudes() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final storedSolicitudes = prefs.getString('stored_solicitudes');

      print('Solicitudes almacenadas: $storedSolicitudes');

      if (storedSolicitudes != null) {
        final solicitudes = jsonDecode(storedSolicitudes);
        print('Solicitudes decodificadas: $solicitudes');

        setState(() {
          _solicitudes = solicitudes;
          _isLoading = false;
        });
      }

      // Intentar actualizar desde el servidor
      try {
        final apiService = ApiService();
        final userData = await _getUserData();
        print('UserData obtenido: ${userData?.rut}');

        if (userData != null) {
          final response = await apiService.get(
            'solicitar-visita/tecnico/${userData.rut}',
          );

          print('Respuesta del servidor: $response');

          // Guardar nueva respuesta
          await prefs.setString('stored_solicitudes', jsonEncode(response));

          if (mounted) {
            setState(() {
              _solicitudes = response;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        print('Error actualizando solicitudes desde el servidor: $e');
      }
    } catch (e) {
      print('Error general cargando solicitudes: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes'),
        backgroundColor: const Color(0xFF3F3FFF),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: CacheService.instance.getSolicitudesVisita(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final solicitudes = snapshot.data ?? [];

          return ListView.builder(
            itemCount: solicitudes.length,
            itemBuilder: (context, index) {
              final solicitud = solicitudes[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    'Local: ${solicitud['local']['nombre'] ?? 'No especificado'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              '${solicitud['tipo_mantenimiento'] ?? 'No especificado'} (${Visit.getTipoServicioNombre(solicitud['tipoServicioId']?.toString())})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: _getColorPorTipo(
                                solicitud['tipo_mantenimiento']),
                          ),
                          if (solicitud['observacion'] != null)
                            Chip(
                              label: Text(
                                solicitud['observacion'],
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor: Colors.grey[200],
                            ),
                        ],
                      ),
                      Text(
                        'Fecha: ${_formatDate(solicitud['fechaVisita'])}',
                      ),
                      Text(
                        'Estado: ${solicitud['status'] ?? 'Pendiente'}',
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navegación a detalles...
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getColorPorTipo(String? tipo) {
    switch (tipo?.toLowerCase()) {
      case 'correctivo':
        return Colors.red[700]!;
      case 'preventivo':
        return Colors.green[700]!;
      case 'instalacion':
        return Colors.blue[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Fecha no especificada';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
