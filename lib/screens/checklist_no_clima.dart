import 'package:flutter/material.dart';
import '../models/visit_model.dart';
import '../models/checklist_model.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'signature_screen.dart';
import '../services/api_service.dart';
import '../services/pending_visits_storage_service.dart';
import 'dart:io';

enum CheckState { conforme, noConforme }

class ChecklistNoClima extends StatefulWidget {
  final Visit visit;
  final List<InspeccionList> listasInspeccion;

  const ChecklistNoClima({
    Key? key,
    required this.visit,
    required this.listasInspeccion,
  }) : super(key: key);

  @override
  State<ChecklistNoClima> createState() => _ChecklistNoClimaState();
}

class _ChecklistNoClimaState extends State<ChecklistNoClima> {
  final Map<int, Map<int, bool>> subItemChecks = {};
  final Map<int, Map<int, CheckState>> subItemStates = {};
  final Map<int, List<XFile>> subItemPhotos = {};
  final Map<int, List<String>> subItemPhotosUrls = {};
  final Map<int, String> subItemComments = {};
  final Map<int, List<Map<String, dynamic>>> subItemRepuestos = {};
  String? clientSignature;

  @override
  void initState() {
    super.initState();
    _loadSavedChecklistData();
  }

  Future<void> _loadSavedChecklistData() async {
    // Implementar carga de datos guardados si es necesario
  }

  bool _canFinish() {
    final bool isPreventivo =
        widget.visit.tipoMantenimiento?.toLowerCase() == 'preventivo';
    bool allNoConformeHavePhotos = true;
    bool allItemsComplete = true;

    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          final isChecked = subItemChecks[lista.id]?[subItem.id] ?? false;

          if (isPreventivo && !isChecked) {
            allItemsComplete = false;
          }

          final state = subItemStates[lista.id]?[subItem.id];
          if (state == CheckState.noConforme) {
            final hasPhotos = (subItemPhotos[subItem.id]?.isNotEmpty ?? false);
            if (!hasPhotos) {
              allNoConformeHavePhotos = false;
              break;
            }
          }
        }
      }
    }

    return (!isPreventivo || allItemsComplete) && allNoConformeHavePhotos;
  }

  String _getMissingRequirementsMessage() {
    List<String> missing = [];
    final bool isPreventivo =
        widget.visit.tipoMantenimiento?.toLowerCase() == 'preventivo';

    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          final isChecked = subItemChecks[lista.id]?[subItem.id] ?? false;
          if (isPreventivo && !isChecked) {
            missing.add('• Item sin completar: ${subItem.name}');
          }

          final state = subItemStates[lista.id]?[subItem.id];
          if (state == CheckState.noConforme) {
            final hasPhotos = (subItemPhotos[subItem.id]?.isNotEmpty ?? false);
            if (!hasPhotos) {
              missing.add('• Falta foto en item no conforme: ${subItem.name}');
            }
          }
        }
      }
    }

    return missing.isEmpty
        ? 'Todo está completo'
        : 'Faltan los siguientes requisitos:\n${missing.join('\n')}';
  }

  Future<void> _finalizarVisita(String signature) async {
    // Implementar la lógica de finalización
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist No Clima'),
        backgroundColor: const Color(0xFF3F3FFF),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Local: ${widget.visit.local.nombreLocal}'),
              const SizedBox(height: 8),
              Text('Dirección: ${widget.visit.local.direccion}'),
              const SizedBox(height: 16),

              // Checklist items
              _buildChecklist(),

              // Botón de finalizar
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checklist de Inspección',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total de items: ${_getTotalSubItems()}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Completados: ${_getCompletedSubItems()}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _canFinish()
                              ? () async {
                                  final signature =
                                      await Navigator.push<String>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SignatureScreen(),
                                    ),
                                  );
                                  if (signature != null) {
                                    await _finalizarVisita(signature);
                                  }
                                }
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          _getMissingRequirementsMessage()),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Finalizar Inspección'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist() {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.listasInspeccion.isEmpty)
            const Center(
              child: Text('No hay items para mostrar'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.listasInspeccion.length,
              itemBuilder: (context, index) {
                final lista = widget.listasInspeccion[index];
                return _buildListaInspeccion(lista);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildListaInspeccion(InspeccionList lista) {
    // Implementar la construcción de la sección del checklist
    return Container(); // Placeholder
  }

  int _getTotalSubItems() {
    int total = 0;
    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        total += item.subItems.length;
      }
    }
    return total;
  }

  int _getCompletedSubItems() {
    int completed = 0;
    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          if (subItemChecks[lista.id]?[subItem.id] ?? false) {
            completed++;
          }
        }
      }
    }
    return completed;
  }
}
