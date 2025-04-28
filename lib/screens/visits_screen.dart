import 'package:flutter/material.dart';
import '../models/visit_model.dart';
import '../models/checklist_model.dart';
import '../services/visits_storage_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/solicitudes_storage_service.dart';

import 'checklist_clima.dart';
import 'checklist_screen.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({Key? key}) : super(key: key);

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  final _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Visit> visits = [];
  List<Visit> filteredVisits = [];
  bool isLoading = true;
  bool isRefreshing = false;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    if (_hasLoadedInitialData && !isRefreshing) {
      return;
    }

    if (!isRefreshing && mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final solicitudes =
          await SolicitudesStorageService.instance.getSolicitudes();

      if (mounted) {
        setState(() {
          visits = solicitudes.map((json) => Visit.fromJson(json)).toList();
          filteredVisits = List.from(visits);
          isLoading = false;
          isRefreshing = false;
          _hasLoadedInitialData = true;
        });
      }
    } catch (e) {
      print('Error cargando visitas: $e');
      if (mounted) {
        setState(() {
          if (!isRefreshing) {
            visits = [];
            filteredVisits = [];
          }
          isLoading = false;
          isRefreshing = false;
          _hasLoadedInitialData = true;
        });
      }

      if (!isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar las visitas: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadVisits,
            ),
          ),
        );
      }
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      isRefreshing = true;
    });
    await _loadVisits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visits.isEmpty
              ? const Center(child: Text('No hay visitas disponibles'))
              : ListView.builder(
                  itemCount: visits.length,
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                visit.local.nombreLocal,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (visit.client['cliente']?['clima'] == true)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3F3FFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF3F3FFF),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.ac_unit,
                                      size: 12,
                                      color: Color(0xFF3F3FFF),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'CLIMA',
                                      style: TextStyle(
                                        color: Color(0xFF3F3FFF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(visit.local.direccion),
                        trailing: Text(visit.status ?? 'Pendiente'),
                        onTap: () async {
                          // Obtener lista de inspección
                          List<InspeccionList> listaInspeccion = [];
                          try {
                            if (visit.client['listaInspeccion'] != null) {
                              listaInspeccion = (visit.client['listaInspeccion']
                                      as List)
                                  .map((item) => InspeccionList.fromJson(item))
                                  .toList();
                            }

                            // Navegar según el valor de clima
                            final bool esVisitaClima =
                                visit.client['cliente']?['clima'] == true;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => esVisitaClima
                                    ? ChecklistClima(
                                        visit: visit,
                                        listasInspeccion: listaInspeccion,
                                      )
                                    : ChecklistScreen(
                                        visit: visit,
                                        listasInspeccion: listaInspeccion,
                                      ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error al cargar la lista de inspección: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
