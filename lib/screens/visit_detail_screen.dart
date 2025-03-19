import 'package:flutter/material.dart';
import '../models/visit_model.dart';
import 'package:geolocator/geolocator.dart';
import 'checklist_screen.dart';
import '../services/api_service.dart';
import '../models/checklist_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class VisitDetailScreen extends StatefulWidget {
  final Visit visit;

  const VisitDetailScreen({
    Key? key,
    required this.visit,
  }) : super(key: key);

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  final _apiService = ApiService();
  late Visit currentVisit;
  Timer? _timer;
  String _tiempoTranscurrido = '';

  @override
  void initState() {
    super.initState();
    currentVisit = widget.visit;
    _iniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarTimer() {
    if (currentVisit.fechaHoraInicioServicio != null) {
      // Actualizar inmediatamente
      _actualizarTiempoTranscurrido();

      // Configurar el timer para actualizar cada segundo
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _actualizarTiempoTranscurrido();
      });
    }
  }

  void _actualizarTiempoTranscurrido() {
    if (currentVisit.fechaHoraInicioServicio != null) {
      final diferencia =
          DateTime.now().difference(currentVisit.fechaHoraInicioServicio!);

      final horas = diferencia.inHours;
      final minutos = diferencia.inMinutes.remainder(60);
      final segundos = diferencia.inSeconds.remainder(60);

      setState(() {
        _tiempoTranscurrido = '${horas.toString().padLeft(2, '0')}:'
            '${minutos.toString().padLeft(2, '0')}:'
            '${segundos.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _iniciarServicio() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _apiService.post(
        'solicitar-visita/iniciar-servicio/${currentVisit.id}',
        {
          'latitud_movil': position.latitude.toString(),
          'longitud_movil': position.longitude.toString(),
        },
      );

      final visitData =
          await _apiService.get('solicitar-visita/${currentVisit.id}');

      if (mounted) {
        setState(() {
          currentVisit = Visit.fromJson(visitData);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio iniciado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        final listaInspeccion = (currentVisit.client['listaInspeccion'] as List)
            .map((item) => InspeccionList.fromJson(item))
            .toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChecklistScreen(
              visit: currentVisit,
              listasInspeccion: listaInspeccion,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _mostrarDialogConfirmacion() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Inicio'),
          content: const Text('¿Está seguro que desea iniciar la visita?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el diálogo
                _iniciarServicio(); // Iniciar el servicio
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalle de Visita',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3F3FFF),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del Cliente y Local
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Información del Cliente
                      Row(
                        children: [
                          // Logo del cliente
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              currentVisit.client['logo'] ?? 'URL_POR_DEFECTO',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.business,
                                    color: Colors.grey,
                                    size: 30,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Nombre del cliente
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cliente',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentVisit.client['nombre'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Información del Local
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Local',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentVisit.local.nombreLocal,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: Color(0xFF3F3FFF),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  currentVisit.local.direccion,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Card de Información de la Visita
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información de la Visita',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Fecha: ${_formatDate(currentVisit.fechaVisita)}',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.access_time,
                        'Hora: ${_formatTime(currentVisit.fechaVisita)}',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.engineering,
                        'Tipo: ${currentVisit.tipoMantenimiento}',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.note,
                        'Estado: ${_getStatusText(currentVisit.status)}',
                      ),
                      if (currentVisit.observaciones != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.comment,
                          'Observaciones: ${currentVisit.observaciones}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (currentVisit.fechaHoraInicioServicio != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Tiempo Transcurrido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            _tiempoTranscurrido,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3F3FFF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: currentVisit.fechaHoraInicioServicio == null
                          ? _mostrarDialogConfirmacion
                          : () {
                              final listaInspeccion = (currentVisit
                                      .client['listaInspeccion'] as List)
                                  .map((item) => InspeccionList.fromJson(item))
                                  .toList();

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChecklistScreen(
                                    visit: currentVisit,
                                    listasInspeccion: listaInspeccion,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                      ),
                      label: Text(
                        currentVisit.fechaHoraInicioServicio == null
                            ? 'INICIAR VISITA'
                            : 'IR A VISITA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            currentVisit.fechaHoraInicioServicio == null
                                ? Colors.green
                                : const Color(0xFF3F3FFF),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (currentVisit.fechaHoraInicioServicio == null) ...[
                const SizedBox(height: 8),
                Text(
                  'Al iniciar la actividad se registrará su ubicación',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF3F3FFF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'en_servicio':
        return 'En Servicio';
      case 'completed':
        return 'Completada';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    String minutes = date.minute.toString().padLeft(2, '0');
    return '${date.hour}:$minutes';
  }
}
