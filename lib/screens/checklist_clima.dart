import 'package:flutter/material.dart';
import '../models/checklist_model.dart';
import '../models/visit_model.dart';
import '../models/repuesto_model.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'signature_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:http_parser/http_parser.dart';
import 'visit_detail_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../DB/LocalDB.dart';
import 'package:image/image.dart' as img;

class ChecklistClima extends StatefulWidget {
  final Visit visit;
  final List<InspeccionList> listasInspeccion;

  const ChecklistClima({
    Key? key,
    required this.visit,
    required this.listasInspeccion,
  }) : super(key: key);

  @override
  State<ChecklistClima> createState() => _ChecklistClimaState();
}

// Primero agregamos un enum para los estados
enum CheckState { conforme, noConforme, noAplica }

class RepuestoAsignado {
  final Repuesto repuesto;
  int cantidad;
  String? comentario;

  RepuestoAsignado({
    required this.repuesto,
    this.cantidad = 1,
    this.comentario,
  });
}

// Modificar la clase ItemPhoto para soportar web
class ItemPhoto {
  final dynamic file;
  final DateTime timestamp;
  final bool isWeb;

  ItemPhoto({
    required this.file,
    required this.timestamp,
    this.isWeb = false,
  });
}

class _ChecklistClimaState extends State<ChecklistClima> {
  int? currentActivoFijoId;
  final _apiService = ApiService();
  Map<int, bool> sectionChecks = {};
  Map<int, Map<int, bool>> subItemChecks = {};
  Map<int, Map<int, CheckState>> subItemStates =
      {}; // Nuevo mapa para los estados
  Map<int, List<RepuestoAsignado>> subItemRepuestos = {};
  List<Repuesto>? repuestos; // Para almacenar la lista de repuestos disponibles
  Map<int, Map<int, List<ItemPhoto>>> subItemPhotos =
      {}; // activoFijoId -> subItemId -> photos
  final ImagePicker _picker = ImagePicker();
  Map<int, String> subItemComments = {}; // Nuevo mapa para comentarios
  Uint8List? clientSignature;
  Map<int, List<String>> subItemPhotosUrls = {};
  int? currentSubItemId;
  Map<int, String> activoFijoEstados = {};
  Map<int, Map<String, String>> parametrosValues = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadSavedPhotos();

    print('Tipo de mantenimiento: ${widget.visit.tipoServicioId}');
    print('Activo fijo ID: ${widget.visit.activo_fijo_id}');
    print(
        'Activos fijos cargados: ${widget.visit.local.activoFijoLocales.length}');

    // Inicializar estados
    for (var lista in widget.listasInspeccion) {
      for (var activo in widget.visit.local.activoFijoLocales) {
        // Inicialización normal para todos los activos
        if (subItemStates[activo.id] == null) {
          subItemStates[activo.id] = {};
        }
        if (subItemChecks[activo.id] == null) {
          subItemChecks[activo.id] = {};
        }
        for (var item in lista.items) {
          for (var subItem in item.subItems) {
            subItemChecks[activo.id]![subItem.id] = false;
            subItemStates[activo.id]![subItem.id] = CheckState.conforme;
          }
        }

        // Inicializar estado del activo fijo
        activoFijoEstados[activo.id] = 'funcionando';
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      final db = LocalDatabase();

      print('Iniciando carga de datos...');
      print(
          'Número de activos: ${widget.visit.local.activoFijoLocales.length}');

      // Primero intentamos cargar datos existentes
      for (var activo in widget.visit.local.activoFijoLocales) {
        print('Cargando datos para activo ${activo.id}...');

        final savedData =
            await db.getChecklistClimaData(activo.id, widget.visit.id);
        print('Datos crudos encontrados para activo ${activo.id}: $savedData');

        if (savedData.isNotEmpty) {
          print('Encontrados datos guardados para activo ${activo.id}');
          setState(() {
            parametrosValues[activo.id] = {
              'setPoint': savedData['medicion_SetPoint'] ?? '0',
              'tempInjeccionFrio':
                  savedData['medicion_TempInjeccionFrio'] ?? '0',
              'tempInjeccionCalor':
                  savedData['medicion_TempInjeccionCalor'] ?? '0',
              'tempAmbiente': savedData['medicion_TempAmbiente'] ?? '0',
              'tempRetorno': savedData['medicion_TempRetorno'] ?? '0',
              'tempExterior': savedData['medicion_TempExterior'] ?? '0',
              'setPointObs': savedData['medicion_SetPoint_observacion'] ?? '',
              'tempInjeccionFrioObs':
                  savedData['medicion_TempInjeccionFrio_observacion'] ?? '',
              'tempInjeccionCalorObs':
                  savedData['medicion_TempInjeccionCalor_observacion'] ?? '',
              'tempAmbienteObs':
                  savedData['medicion_TempAmbiente_observacion'] ?? '',
              'tempRetornoObs':
                  savedData['medicion_TempRetorno_observacion'] ?? '',
              'tempExteriorObs':
                  savedData['medicion_TempExterior_observacion'] ?? '',
              'consumoCompresorR': savedData['consumoCompresor_R'] ?? '0',
              'consumoCompresorS': savedData['consumoCompresor_S'] ?? '0',
              'consumoCompresorT': savedData['consumoCompresor_T'] ?? '0',
              'consumoCompresorN': savedData['consumoCompresor_N'] ?? '0',
              'tensionRS': savedData['tension_R_S'] ?? '0',
              'tensionST': savedData['tension_S_T'] ?? '0',
              'tensionTR': savedData['tension_T_R'] ?? '0',
              'tensionTN': savedData['tension_T_N'] ?? '0',
              'consumoTotalR': savedData['consumo_total_R'] ?? '0',
              'consumoTotalS': savedData['consumo_total_S'] ?? '0',
              'consumoTotalT': savedData['consumo_total_T'] ?? '0',
              'consumoTotalN': savedData['consumo_total_N'] ?? '0',
              'presionesAltas': savedData['presiones_altas'] ?? '0',
              'presionesBajas': savedData['presiones_bajas'] ?? '0',
            };
          });
          print(
              'Datos cargados en el estado para activo ${activo.id}: ${parametrosValues[activo.id]}');
        } else {
          print(
              'No se encontraron datos guardados para activo ${activo.id}, inicializando valores por defecto');
          setState(() {
            parametrosValues[activo.id] = {
              'setPoint': '0',
              'tempInjeccionFrio': '0',
              'tempInjeccionCalor': '0',
              'tempAmbiente': '0',
              'tempRetorno': '0',
              'tempExterior': '0',
              'setPointObs': '',
              'tempInjeccionFrioObs': '',
              'tempInjeccionCalorObs': '',
              'tempAmbienteObs': '',
              'tempRetornoObs': '',
              'tempExteriorObs': '',
              'consumoCompresorR': '0',
              'consumoCompresorS': '0',
              'consumoCompresorT': '0',
              'consumoCompresorN': '0',
              'tensionRS': '0',
              'tensionST': '0',
              'tensionTR': '0',
              'tensionTN': '0',
              'consumoTotalR': '0',
              'consumoTotalS': '0',
              'consumoTotalT': '0',
              'consumoTotalN': '0',
              'presionesAltas': '0',
              'presionesBajas': '0',
            };
          });
        }
      }

      // Cargamos los repuestos
      await _loadRepuestos();

      // Cargar fotos guardadas
      await _loadSavedPhotos();

      // Cargar comentarios
      try {
        final savedComments = await db.getEstados(
          'item_estado',
          where: 'solicitarVisitaId = ?',
          whereArgs: [widget.visit.id],
        );
        setState(() {
          for (var comment in savedComments) {
            if (comment['comentario'] != null && comment['comentario'] != '') {
              subItemComments[comment['itemId'] as int] =
                  comment['comentario'] as String;
            }
          }
        });
      } catch (e) {
        print('Error cargando comentarios: $e');
      }

      // Cargar estados guardados
      try {
        final savedEstados = await db.getEstados(
          'item_estado',
          where: 'solicitarVisitaId = ?',
          whereArgs: [widget.visit.id],
        );

        setState(() {
          for (var estado in savedEstados) {
            final itemId = estado['itemId'] as int;
            final estadoValue = estado['estado'] as String;

            CheckState checkState;
            switch (estadoValue) {
              case 'conforme':
                checkState = CheckState.conforme;
                break;
              case 'noConforme':
                checkState = CheckState.noConforme;
                break;
              case 'noAplica':
                checkState = CheckState.noAplica;
                break;
              default:
                checkState = CheckState.conforme;
            }

            for (var activoId in subItemStates.keys) {
              if (subItemStates[activoId]?.containsKey(itemId) ?? false) {
                subItemStates[activoId]![itemId] = checkState;
              }
            }
          }
        });
        print('Estados cargados: $subItemStates');
      } catch (e) {
        print('Error cargando estados: $e');
      }

      print('Inicialización de datos completada');
      print('Estado final de parametrosValues: $parametrosValues');
    } catch (e) {
      print('Error inicializando datos: $e');
    }
  }

  Future<void> _loadRepuestos() async {
    try {
      // Cargar repuestos del API
      final data = await _apiService.get('repuestos');

      // Cargar repuestos guardados de la DB local
      final db = LocalDatabase();
      final savedRepuestos = await db.getRepuestos(widget.visit.id);

      setState(() {
        // Cargar lista de repuestos disponibles
        repuestos =
            (data as List).map((item) => Repuesto.fromJson(item)).toList();

        // Cargar repuestos asignados
        for (var repuesto in savedRepuestos) {
          final itemId = repuesto['itemId'] as int;
          final repuestoId = repuesto['repuestoId'] as int;
          final cantidad = int.parse(repuesto['cantidad'].toString());
          final comentario = repuesto['comentario'] as String;

          // Buscar el repuesto en la lista de repuestos disponibles
          final repuestoData = repuestos!.firstWhere(
            (r) => r.id == repuestoId,
            orElse: () => throw Exception('Repuesto no encontrado'),
          );

          // Agregar al mapa de repuestos asignados
          if (subItemRepuestos[itemId] == null) {
            subItemRepuestos[itemId] = [];
          }

          subItemRepuestos[itemId]!.add(
            RepuestoAsignado(
              repuesto: repuestoData,
              cantidad: cantidad,
              comentario: comentario,
            ),
          );
        }
      });

      print('Repuestos cargados: ${repuestos?.length ?? 0}');
      print('Repuestos asignados: ${subItemRepuestos.length}');
    } catch (e) {
      print('Error cargando repuestos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando repuestos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSavedPhotos() async {
    try {
      final db = LocalDatabase();
      final allFotos = await db.getFotosItem(
        'item_fotos',
        where: 'solicitarVisitaId = ?',
        whereArgs: [widget.visit.id],
      );

      print('Fotos cargadas de DB: $allFotos');

      setState(() {
        for (var foto in allFotos) {
          final itemId = foto['itemId'] as int;
          final activoFijoId = foto['activoFijoId'] as int;

          // Inicializar la estructura si no existe
          if (subItemPhotos[activoFijoId] == null) {
            subItemPhotos[activoFijoId] = {};
          }
          if (subItemPhotos[activoFijoId]![itemId] == null) {
            subItemPhotos[activoFijoId]![itemId] = [];
          }

          // Agregar la foto
          subItemPhotos[activoFijoId]![itemId]!.add(
            ItemPhoto(
              file: base64Decode(foto['fotos'] as String),
              timestamp: DateTime.parse(foto['created_at'] as String),
              isWeb: true,
            ),
          );
        }
      });
    } catch (e) {
      print('Error cargando fotos guardadas: $e');
    }
  }

  // Función para mostrar el selector de estado
  void _showStateSelector(
      BuildContext context, InspeccionList lista, SubItem subItem) {
    CheckState selectedState = subItemStates[lista.id]![subItem.id]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Seleccionar Estado',
          textAlign: TextAlign.center,
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Conforme'),
                leading: Radio<CheckState>(
                  value: CheckState.conforme,
                  groupValue: selectedState,
                  onChanged: (CheckState? value) {
                    setState(() {
                      selectedState = value!;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('No Conforme'),
                subtitle: const Text(
                  'Se requiere adjuntar foto',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                leading: Radio<CheckState>(
                  value: CheckState.noConforme,
                  groupValue: selectedState,
                  onChanged: (CheckState? value) {
                    setState(() {
                      selectedState = value!;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('No Aplica'),
                leading: Radio<CheckState>(
                  value: CheckState.noAplica,
                  groupValue: selectedState,
                  onChanged: (CheckState? value) {
                    setState(() {
                      selectedState = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              this.setState(() {
                subItemChecks[lista.id]![subItem.id] = false;
              });
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              this.setState(() {
                subItemStates[lista.id]![subItem.id] = selectedState;
                if (selectedState == CheckState.noConforme) {
                  // Mostrar recordatorio para agregar foto
                  Future.delayed(const Duration(milliseconds: 500), () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'No olvides agregar una foto para el item no conforme'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  });
                }
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3F3FFF),
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  // Actualizar la función _showPhotoOptions
  Future<void> _showPhotoOptions(int subItemId) async {
    currentSubItemId = subItemId; // Guardar el ID actual
    // Llamar directamente a _takePhoto en lugar de mostrar opciones
    await _takePhoto();
  }

  // Función para tomar foto
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50, // Reducir calidad para optimizar almacenamiento
      );
      if (photo != null) {
        await _processPhoto(photo);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar la foto: $e')),
      );
    }
  }

  // Función para procesar la foto
  Future<void> _processPhoto(XFile photo) async {
    if (currentSubItemId == null || currentActivoFijoId == null) return;

    try {
      _showLoadingDialog('Procesando imagen...');

      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        final base64Image = base64Encode(bytes);

        final db = LocalDatabase();
        await db.insertFoto(
          currentSubItemId!,
          widget.visit.id,
          base64Image,
          activoFijoId: currentActivoFijoId,
        );

        setState(() {
          // Inicializar la estructura si no existe
          if (subItemPhotos[currentActivoFijoId!] == null) {
            subItemPhotos[currentActivoFijoId!] = {};
          }
          if (subItemPhotos[currentActivoFijoId!]![currentSubItemId!] == null) {
            subItemPhotos[currentActivoFijoId!]![currentSubItemId!] = [];
          }

          subItemPhotos[currentActivoFijoId!]![currentSubItemId!]!.add(
            ItemPhoto(
              file: bytes,
              timestamp: DateTime.now(),
              isWeb: true,
            ),
          );
        });
      } else {
        final File photoFile = File(photo.path);
        final bytes = await photoFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        final db = LocalDatabase();
        await db.insertFoto(
          currentSubItemId!,
          widget.visit.id,
          base64Image,
          activoFijoId: currentActivoFijoId,
        );

        setState(() {
          if (subItemPhotos[currentActivoFijoId!] == null) {
            subItemPhotos[currentActivoFijoId!] = {};
          }
          if (subItemPhotos[currentActivoFijoId!]![currentSubItemId!] == null) {
            subItemPhotos[currentActivoFijoId!]![currentSubItemId!] = [];
          }

          subItemPhotos[currentActivoFijoId!]![currentSubItemId!]!.add(
            ItemPhoto(
              file: photoFile,
              timestamp: DateTime.now(),
              isWeb: false,
            ),
          );
        });
      }

      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto guardada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error procesando foto: $e');
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar la foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Modificar el CheckboxListTile
  Widget _buildChecklistItem(InspeccionList lista, SubItem subItem,
      {required int activoId}) {
    final hasPhotos =
        (subItemPhotos[activoId]?[subItem.id]?.isNotEmpty ?? false) ||
            (subItemPhotosUrls[subItem.id]?.isNotEmpty ?? false);
    final hasRepuestos = subItemRepuestos[subItem.id]?.isNotEmpty ?? false;
    final hasComments = subItemComments[subItem.id]?.isNotEmpty ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del ítem
          Text(
            subItem.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Estados en forma de segmentos redondeados
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStateButton(
                    'Conforme',
                    Icons.check_circle,
                    CheckState.conforme,
                    subItemStates[activoId]?[subItem.id] ?? CheckState.conforme,
                    activoId,
                    subItem.id,
                  ),
                ),
                Expanded(
                  child: _buildStateButton(
                    'No Conforme',
                    Icons.cancel,
                    CheckState.noConforme,
                    subItemStates[activoId]?[subItem.id] ?? CheckState.conforme,
                    activoId,
                    subItem.id,
                  ),
                ),
                Expanded(
                  child: _buildStateButton(
                    'No Aplica',
                    Icons.remove_circle,
                    CheckState.noAplica,
                    subItemStates[activoId]?[subItem.id] ?? CheckState.conforme,
                    activoId,
                    subItem.id,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botones de acción con estilo suave
          Column(
            children: [
              _buildActionButton(
                'Agregar Foto',
                Icons.photo_camera,
                hasPhotos,
                () {
                  currentSubItemId = subItem.id;
                  _showPhotoOptions(subItem.id);
                },
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Agregar Comentario',
                Icons.comment,
                hasComments,
                () => _showCommentDialog(subItem.id),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                'Agregar Repuesto',
                Icons.build,
                hasRepuestos,
                () => _showRepuestosDialog(subItem.id),
              ),
            ],
          ),

          // Mostrar contenido existente
          if (hasPhotos) _buildPhotosList(subItem.id, activoId),
          if (hasComments) _buildCommentView(subItem.id),
          if (hasRepuestos) _buildRepuestosList(subItem.id),
        ],
      ),
    );
  }

  Widget _buildStateButton(String text, IconData icon, CheckState state,
      CheckState currentState, int activoId, int subItemId) {
    final isSelected = currentState == state;
    return InkWell(
      onTap: () async {
        await _updateItemState(activoId, subItemId, state);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text, IconData icon, bool isActive, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isActive ? Colors.blue : Colors.grey,
          size: 20,
        ),
        label: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  // Método auxiliar para mostrar la lista de fotos
  Widget _buildPhotosList(int subItemId, int activoId) {
    final photos = subItemPhotos[activoId]?[subItemId] ?? [];
    final urls = subItemPhotosUrls[subItemId] ?? [];

    print('Mostrando fotos para activo $activoId, subItem $subItemId');
    print('Número de fotos: ${photos.length}');

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + urls.length,
        itemBuilder: (context, index) {
          if (index < photos.length) {
            return _buildPhotoThumbnail(photos[index], activoId, subItemId);
          } else {
            return _buildPhotoUrlThumbnail(urls[index - photos.length]);
          }
        },
      ),
    );
  }

  // Método auxiliar para mostrar comentarios
  Widget _buildCommentView(int subItemId) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(subItemComments[subItemId] ?? ''),
    );
  }

  // Método auxiliar para mostrar la lista de repuestos
  Widget _buildRepuestosList(int subItemId) {
    final repuestosAsignados = subItemRepuestos[subItemId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: repuestosAsignados
          .map((repuesto) => Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${repuesto.repuesto.articulo} (${repuesto.cantidad})'),
                    ),
                    if (repuesto.comentario?.isNotEmpty ?? false)
                      Expanded(
                        child: Text(
                          repuesto.comentario!,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // Actualizar el widget que muestra la imagen
  Widget _buildPhotoThumbnail(ItemPhoto photo, int activoId, int subItemId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: photo.isWeb
                  ? Image.memory(
                      photo.file as Uint8List,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Center(child: Icon(Icons.error));
                      },
                    )
                  : Image.file(
                      photo.file as File,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Center(child: Icon(Icons.error));
                      },
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () async {
                  try {
                    final db = LocalDatabase();
                    // Eliminar la foto de la base de datos
                    // await db.deleteFoto(subItemId, widget.visit.id, activoFijoId: activoId);

                    // Eliminar la foto del estado
                    setState(() {
                      subItemPhotos[activoId]?[subItemId]?.remove(photo);
                    });
                  } catch (e) {
                    print('Error eliminando foto: $e');
                  }
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUrlThumbnail(String url) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              final currentSubItem = currentSubItemId; // Usar el ID guardado
              if (currentSubItem != null) {
                setState(() {
                  subItemPhotosUrls[currentSubItem]?.remove(url);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lista de Inspección',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF3F3FFF),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.visit.local.activoFijoLocales.length,
              itemBuilder: (context, index) {
                final activo = widget.visit.local.activoFijoLocales[index];
                // Verificar si este activo es el referenciado en la solicitud
                final bool isMatchingActivo = true;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  // Reemplazar el color de fondo con un borde verde
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Colors.green.shade700,
                      width: 1.5,
                    ),
                  ),
                  child: ExpansionTile(
                    enabled: isMatchingActivo,
                    title: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${activo.tipoEquipo} - ${activo.marca}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[
                                      900], // Mantener el texto en verde oscuro
                                ),
                              ),
                              Text(
                                'Código: ${activo.codigoActivo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isMatchingActivo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'No corresponde a esta solicitud',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Solo mostrar el contenido si coincide
                    children: isMatchingActivo
                        ? [
                            _buildMedicionesForm(activo.id),
                            ...widget.listasInspeccion.map((lista) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3F3FFF)
                                          .withOpacity(0.1),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          lista.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ChoiceChip(
                                              label: const Text('Aplica'),
                                              selected: !_isListaNoAplica(
                                                  lista.id, activo.id),
                                              onSelected: (bool selected) {
                                                _setListaState(
                                                    lista.id,
                                                    activo.id,
                                                    CheckState.conforme);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            ChoiceChip(
                                              label: const Text('No Aplica'),
                                              selected: _isListaNoAplica(
                                                  lista.id, activo.id),
                                              onSelected: (bool selected) {
                                                _setListaState(
                                                    lista.id,
                                                    activo.id,
                                                    CheckState.noAplica);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Mostrar los items cuando NO es "No Aplica"
                                  if (!_isListaNoAplica(lista.id, activo.id))
                                    ...lista.items
                                        .map((item) => Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(16),
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                ...item.subItems
                                                    .map((subItem) =>
                                                        _buildChecklistItem(
                                                            lista, subItem,
                                                            activoId:
                                                                activo.id))
                                                    .toList(),
                                              ],
                                            ))
                                        .toList(),
                                ],
                              );
                            }).toList(),
                          ]
                        : [], // Lista vacía si no coincide
                  ),
                );
              },
            ),
          ),
          // Card inferior con el resumen y botón de finalizar
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildMedicionesForm(int activoId) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mediciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Mediciones de temperatura
          _buildMedicionSection(
            'Temperaturas',
            [
              _buildMedicionField(
                activoId,
                'tempAmbiente',
                'Temperatura Ambiente',
                'tempAmbienteObs',
              ),
              _buildMedicionField(
                activoId,
                'tempInjeccionFrio',
                'Temperatura Inyección Frío',
                'tempInjeccionFrioObs',
              ),
              _buildMedicionField(
                activoId,
                'tempRetorno',
                'Temperatura Retorno',
                'tempRetornoObs',
              ),
              _buildMedicionField(
                activoId,
                'tempInjeccionCalor',
                'Temperatura Inyección Calor',
                'tempInjeccionCalorObs',
              ),
              _buildMedicionField(
                activoId,
                'setPoint',
                'Set Point',
                'setPointObs',
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Consumo compresor
          _buildMedicionSection(
            'Consumo Compresor',
            [
              _buildMedicionField(activoId, 'consumoCompresorR', 'R'),
              _buildMedicionField(activoId, 'consumoCompresorS', 'S'),
              _buildMedicionField(activoId, 'consumoCompresorT', 'T'),
              _buildMedicionField(activoId, 'consumoCompresorN', 'N'),
            ],
          ),
          const SizedBox(height: 24),
          // Tensiones
          _buildMedicionSection(
            'Tensiones',
            [
              _buildMedicionField(activoId, 'tensionRS', 'R-S'),
              _buildMedicionField(activoId, 'tensionST', 'S-T'),
              _buildMedicionField(activoId, 'tensionTR', 'T-R'),
              _buildMedicionField(activoId, 'tensionTN', 'T-N'),
            ],
          ),
          const SizedBox(height: 24),
          // Presiones
          _buildMedicionSection(
            'Presiones',
            [
              _buildMedicionField(activoId, 'presionesAltas', 'Alta'),
              _buildMedicionField(activoId, 'presionesBajas', 'Baja'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicionSection(String title, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...fields,
      ],
    );
  }

  Widget _buildMedicionField(
    int activoId,
    String key,
    String label, [
    String? observacionKey,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label),
          ),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: parametrosValues[activoId]?[key] ?? '0',
              keyboardType: TextInputType.number,
              onChanged: (value) async {
                setState(() {
                  if (parametrosValues[activoId] == null) {
                    parametrosValues[activoId] = {};
                  }
                  parametrosValues[activoId]![key] = value;
                });

                // Guardar en DB local cada vez que cambia un valor
                await _saveParametros(activoId);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          if (observacionKey != null) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextFormField(
                initialValue: parametrosValues[activoId]?[observacionKey] ?? '',
                decoration: const InputDecoration(
                  hintText: 'Observación',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (value) async {
                  setState(() {
                    if (parametrosValues[activoId] == null) {
                      parametrosValues[activoId] = {};
                    }
                    parametrosValues[activoId]![observacionKey] = value;
                  });

                  // Guardar en DB local cada vez que cambia una observación
                  await _saveParametros(activoId);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    return Card(
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
                onPressed: _validateForm()
                    ? () async {
                        final signature = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignatureScreen(),
                          ),
                        );

                        if (signature != null) {
                          await _finalizarVisita(signature);
                        }
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_getMissingRequirementsMessage()),
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
    );
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
          if (subItemChecks[item.id]?[subItem.id] == true) {
            completed++;
          }
        }
      }
    }
    return completed;
  }

  bool _validateForm() {
    // Si hay un activo_fijo_id, validar ese activo específico
    if (widget.visit.activo_fijo_id != null) {
      final activoId = widget.visit.activo_fijo_id!;

      // Validar mediciones
      if (parametrosValues[activoId] == null ||
          parametrosValues[activoId]!.isEmpty ||
          parametrosValues[activoId]!.values.any((value) => value.isEmpty)) {
        return false;
      }

      // Validar checklist
      for (var lista in widget.listasInspeccion) {
        for (var item in lista.items) {
          for (var subItem in item.subItems) {
            // Verificar si el checkbox está marcado
            if (!(subItemChecks[activoId]?[subItem.id] ?? false)) {
              return false;
            }
            // Verificar si tiene un estado seleccionado
            if (subItemStates[activoId]?[subItem.id] == null) {
              return false;
            }
          }
        }
      }
    }

    return true;
  }

  String _getMissingRequirementsMessage() {
    List<String> missing = [];

    if (widget.visit.activo_fijo_id != null) {
      final activoId = widget.visit.activo_fijo_id!;

      // Verificar mediciones
      if (parametrosValues[activoId] == null ||
          parametrosValues[activoId]!.isEmpty ||
          parametrosValues[activoId]!.values.any((value) => value.isEmpty)) {
        missing.add('Complete todas las mediciones');
      }

      // Verificar checklist
      bool hasUncheckedItems = false;
      bool hasUnselectedStates = false;

      for (var lista in widget.listasInspeccion) {
        for (var item in lista.items) {
          for (var subItem in item.subItems) {
            if (!(subItemChecks[activoId]?[subItem.id] ?? false)) {
              hasUncheckedItems = true;
            }
            if (subItemStates[activoId]?[subItem.id] == null) {
              hasUnselectedStates = true;
            }
          }
        }
      }

      if (hasUncheckedItems) {
        missing.add('Marque todos los items del checklist');
      }
      if (hasUnselectedStates) {
        missing.add('Seleccione el estado de todos los items');
      }
    }

    return missing.isEmpty
        ? ''
        : 'Por favor:\n${missing.map((m) => '- $m').join('\n')}';
  }

  Future<String> _uploadPhoto(
      String path, int visitId, int subItemId, String fileName) async {
    try {
      var uri = Uri.parse('${ApiService.baseUrl}/visitas/$visitId/fotos');
      var request = http.MultipartRequest('POST', uri)
        ..fields['subitem_id'] = subItemId.toString()
        ..files.add(await http.MultipartFile.fromPath(
          'foto',
          path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ));

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        return jsonResponse['url'];
      } else {
        throw Exception('Error al subir la foto: ${response.statusCode}');
      }
    } catch (e) {
      print('Error subiendo foto: $e');
      throw e;
    }
  }

  Future<void> _finalizarVisita(String signature) async {
    try {
      final db = LocalDatabase();
      Map<String, dynamic> payload = {
        'firma_cliente': signature,
        'repuestos': <String, dynamic>{},
        'activoFijoRepuestos': await Future.wait(
          widget.visit.local.activoFijoLocales.map((activo) async {
            // Obtener datos del checklist clima para este activo
            final checklistData =
                await db.getChecklistClimaData(activo.id, widget.visit.id);
            final repuestosActivo = subItemRepuestos[activo.id] ?? [];

            return {
              'id': activo.id,
              'estadoOperativo': activoFijoEstados[activo.id] ?? 'funcionando',
              'observacionesEstado': '',
              'fechaRevision': DateTime.now().toIso8601String(),
              'activoFijoId': activo.id,
              'activoFijo': {
                'id': activo.id,
                'tipo_equipo': activo.tipoEquipo,
                'marca': activo.marca,
              },
              'repuestos': repuestosActivo
                  .map((repuesto) => {
                        'id': 1,
                        'cantidad': repuesto.cantidad,
                        'comentario': repuesto.comentario ?? '',
                        'estado': 'pendiente',
                        'precio_unitario': repuesto.repuesto.precio_venta ?? 0,
                        'repuesto': {
                          'id': repuesto.repuesto.id,
                          'nombre': repuesto.repuesto.articulo,
                        }
                      })
                  .toList(),
              // Agregar datos del checklist clima
              'checklistClima': checklistData.isNotEmpty
                  ? {
                      'mediciones': {
                        'setPoint': checklistData['medicion_SetPoint'],
                        'tempInjeccionFrio':
                            checklistData['medicion_TempInjeccionFrio'],
                        'tempInjeccionCalor':
                            checklistData['medicion_TempInjeccionCalor'],
                        'tempAmbiente': checklistData['medicion_TempAmbiente'],
                        'tempRetorno': checklistData['medicion_TempRetorno'],
                        'tempExterior': checklistData['medicion_TempExterior'],
                      },
                      'observaciones': {
                        'setPoint':
                            checklistData['medicion_SetPoint_observacion'],
                        'tempInjeccionFrio': checklistData[
                            'medicion_TempInjeccionFrio_observacion'],
                        'tempInjeccionCalor': checklistData[
                            'medicion_TempInjeccionCalor_observacion'],
                        'tempAmbiente':
                            checklistData['medicion_TempAmbiente_observacion'],
                        'tempRetorno':
                            checklistData['medicion_TempRetorno_observacion'],
                        'tempExterior':
                            checklistData['medicion_TempExterior_observacion'],
                      },
                      'consumos': {
                        'compresor': {
                          'R': checklistData['consumoCompresor_R'],
                          'S': checklistData['consumoCompresor_S'],
                          'T': checklistData['consumoCompresor_T'],
                          'N': checklistData['consumoCompresor_N'],
                        },
                        'total': {
                          'R': checklistData['consumo_total_R'],
                          'S': checklistData['consumo_total_S'],
                          'T': checklistData['consumo_total_T'],
                          'N': checklistData['consumo_total_N'],
                        }
                      },
                      'tensiones': {
                        'R_S': checklistData['tension_R_S'],
                        'S_T': checklistData['tension_S_T'],
                        'T_R': checklistData['tension_T_R'],
                        'T_N': checklistData['tension_T_N'],
                      },
                      'presiones': {
                        'altas': checklistData['presiones_altas'],
                        'bajas': checklistData['presiones_bajas'],
                      }
                    }
                  : null
            };
          }),
        )
      };

      // Agregar los items de inspección y sus repuestos
      for (var lista in widget.listasInspeccion) {
        for (var item in lista.items) {
          // Crear un mapa para almacenar todos los repuestos del item
          Map<String, dynamic> itemData = {
            'id': item.id,
            'estado': 'conforme',
            'comentario': '',
            'fotos': [],
            'repuestos': <Map<String, dynamic>>[]
          };

          // Agregar los repuestos de todos los subItems al item padre
          for (var subItem in item.subItems) {
            String estado = _getEstadoString(
                subItemStates[item.id]?[subItem.id] ?? CheckState.conforme);

            // Agregar fotos del subItem
            if (subItemPhotos[item.id]?[subItem.id]?.isNotEmpty ?? false) {
              itemData['fotos'].addAll(subItemPhotos[item.id]![subItem.id]!);
            }

            // Agregar comentario si existe
            if (subItemComments[subItem.id]?.isNotEmpty ?? false) {
              itemData['comentario'] = subItemComments[subItem.id];
            }

            // Si el estado no es conforme, actualizar el estado del item
            if (estado != 'conforme') {
              itemData['estado'] = estado;
            }

            // Agregar repuestos del subItem
            if (subItemRepuestos[subItem.id]?.isNotEmpty ?? false) {
              for (var repuesto in subItemRepuestos[subItem.id]!) {
                itemData['repuestos'].add({
                  'id': 1,
                  'cantidad': repuesto.cantidad,
                  'comentario': repuesto.comentario ?? '',
                  'estado': 'pendiente',
                  'precio_unitario': repuesto.repuesto.precio_venta ?? 0,
                  'repuesto': {
                    'id': repuesto.repuesto.id,
                    'nombre': repuesto.repuesto.articulo,
                  }
                });
              }
            }
          }

          // Siempre agregar el item al payload
          payload['repuestos'][item.id.toString()] = itemData;
        }
      }

      print('Payload final:');
      print(jsonEncode(payload));

      final response =
          await ApiService.finalizarVisita(widget.visit.id, payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Eliminar la solicitud de la base de datos local
        await db.deleteSolicitudVisita(widget.visit.id);

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita finalizada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        // Navegar de vuelta
        Navigator.of(context).pop();
      } else {
        print('Error response: ${response.body}');
        throw Exception('Error al finalizar la visita: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception details: $e');

      String errorMessage = '';
      try {
        if (e.toString().contains('Exception:')) {
          errorMessage = e.toString().replaceAll('Exception:', '').trim();
          if (errorMessage.contains('{')) {
            final errorJson = jsonDecode(errorMessage);
            if (errorJson['message'] is List) {
              errorMessage = (errorJson['message'] as List).join('\n');
            } else {
              errorMessage = errorJson['message'].toString();
            }
          }
        } else {
          errorMessage = e.toString();
        }
      } catch (_) {
        errorMessage = e.toString();
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error al finalizar la visita'),
              content: SingleChildScrollView(
                child: Text(errorMessage),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  String _getEstadoString(CheckState state) {
    switch (state) {
      case CheckState.conforme:
        return 'conforme';
      case CheckState.noConforme:
        return 'no_conforme';
      case CheckState.noAplica:
        return 'no_aplica';
    }
  }

  bool _isListaNoAplica(int listaId, int activoId) {
    if (subItemStates[activoId] == null) return false;

    bool allNoAplica = true;
    for (var item
        in widget.listasInspeccion.firstWhere((l) => l.id == listaId).items) {
      for (var subItem in item.subItems) {
        if (subItemStates[activoId]?[subItem.id] != CheckState.noAplica) {
          allNoAplica = false;
          break;
        }
      }
    }
    return allNoAplica;
  }

  void _setListaState(int listaId, int activoId, CheckState state) {
    setState(() {
      if (subItemStates[activoId] == null) {
        subItemStates[activoId] = {};
      }
      if (subItemChecks[activoId] == null) {
        subItemChecks[activoId] = {};
      }

      // Aplicar el estado a todos los subitems de la lista
      for (var item
          in widget.listasInspeccion.firstWhere((l) => l.id == listaId).items) {
        for (var subItem in item.subItems) {
          // Siempre actualizar el estado y marcar el checkbox
          subItemStates[activoId]![subItem.id] = state;
          subItemChecks[activoId]![subItem.id] = true;
        }
      }
    });

    // Mostrar mensaje de confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state == CheckState.noAplica
            ? 'Todos los items marcados como No Aplica'
            : 'Todos los items marcados como Conforme'),
        backgroundColor:
            state == CheckState.noAplica ? Colors.orange : Colors.green,
      ),
    );
  }

  Future<void> _saveParametros(int activoFijoId) async {
    try {
      final db = LocalDatabase();
      final parametros = parametrosValues[activoFijoId];

      if (parametros == null) return;

      final data = {
        'activoFijoId': activoFijoId,
        'solicitarVisitaId': widget.visit.id,
        'medicion_SetPoint': parametros['setPoint'],
        'medicion_TempInjeccionFrio': parametros['tempInjeccionFrio'],
        'medicion_TempInjeccionCalor': parametros['tempInjeccionCalor'],
        'medicion_TempAmbiente': parametros['tempAmbiente'],
        'medicion_TempRetorno': parametros['tempRetorno'],
        'medicion_TempExterior': parametros['tempExterior'],
        'medicion_SetPoint_observacion': parametros['setPointObs'],
        'medicion_TempInjeccionFrio_observacion':
            parametros['tempInjeccionFrioObs'],
        'medicion_TempInjeccionCalor_observacion':
            parametros['tempInjeccionCalorObs'],
        'medicion_TempAmbiente_observacion': parametros['tempAmbienteObs'],
        'medicion_TempRetorno_observacion': parametros['tempRetornoObs'],
        'medicion_TempExterior_observacion': parametros['tempExteriorObs'],
        'consumoCompresor_R': parametros['consumoCompresorR'],
        'consumoCompresor_S': parametros['consumoCompresorS'],
        'consumoCompresor_T': parametros['consumoCompresorT'],
        'consumoCompresor_N': parametros['consumoCompresorN'],
        'tension_R_S': parametros['tensionRS'],
        'tension_S_T': parametros['tensionST'],
        'tension_T_R': parametros['tensionTR'],
        'tension_T_N': parametros['tensionTN'],
        'consumo_total_R': parametros['consumoTotalR'],
        'consumo_total_S': parametros['consumoTotalS'],
        'consumo_total_T': parametros['consumoTotalT'],
        'consumo_total_N': parametros['consumoTotalN'],
        'presiones_altas': parametros['presionesAltas'],
        'presiones_bajas': parametros['presionesBajas'],
      };

      await db.saveChecklistClima(data);
      print('Datos guardados para activo $activoFijoId');
    } catch (e) {
      print('Error guardando parámetros: $e');
    }
  }

  // Llamar a esta función cuando cambien los valores
  void _onParametroChanged(int activoFijoId, String key, String value) {
    setState(() {
      if (parametrosValues[activoFijoId] == null) {
        parametrosValues[activoFijoId] = {};
      }
      parametrosValues[activoFijoId]![key] = value;
    });
    _saveParametros(activoFijoId);
  }

  Future<void> _showCommentDialog(int subItemId) async {
    final TextEditingController commentController = TextEditingController(
      text: subItemComments[subItemId] ?? '',
    );
    final db = LocalDatabase();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Comentario'),
        content: TextField(
          controller: commentController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Escriba su comentario aquí...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final comment = commentController.text.trim();

              // Actualizar el estado local
              setState(() {
                if (comment.isEmpty) {
                  subItemComments.remove(subItemId);
                } else {
                  subItemComments[subItemId] = comment;
                }
              });

              // Actualizar la base de datos local usando la función existente
              try {
                await db.updateComentario(subItemId, comment);
                print(
                    'Comentario actualizado en DB local para subItemId: $subItemId');
              } catch (e) {
                print('Error actualizando comentario en DB local: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error guardando comentario: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }

              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3F3FFF),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRepuestosDialog(int subItemId) async {
    if (repuestos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No hay repuestos disponibles')),
      );
      return;
    }

    final db = LocalDatabase(); // Instancia de la base de datos

    // Cargar repuestos existentes de la DB
    try {
      final savedRepuestos = await db.getRepuestos(widget.visit.id);
      setState(() {
        for (var repuesto in savedRepuestos) {
          final itemId = repuesto['itemId'] as int;
          if (itemId == subItemId) {
            if (subItemRepuestos[subItemId] == null) {
              subItemRepuestos[subItemId] = [];
            }
            // Buscar el repuesto en la lista de repuestos disponibles
            final repuestoData = repuestos!.firstWhere(
              (r) => r.id == repuesto['repuestoId'].toString(),
            );
            subItemRepuestos[subItemId]!.add(
              RepuestoAsignado(
                repuesto: repuestoData,
                cantidad: int.parse(repuesto['cantidad'].toString()),
                comentario: repuesto['comentario'] as String,
              ),
            );
          }
        }
      });
    } catch (e) {
      print('Error cargando repuestos guardados: $e');
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Repuesto'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...?repuestos?.map((repuesto) {
                    final isSelected = subItemRepuestos[subItemId]
                            ?.any((r) => r.repuesto.id == repuesto.id) ??
                        false;
                    final selectedRepuesto = isSelected
                        ? subItemRepuestos[subItemId]!
                            .firstWhere((r) => r.repuesto.id == repuesto.id)
                        : null;

                    return Column(
                      children: [
                        ListTile(
                          title: Text(repuesto.articulo),
                          subtitle: Text('Precio: \$${repuesto.precio_venta}'),
                          trailing: isSelected
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: () async {
                                        setState(() {
                                          final currentRepuesto =
                                              subItemRepuestos[subItemId]!
                                                  .firstWhere((r) =>
                                                      r.repuesto.id ==
                                                      repuesto.id);
                                          if (currentRepuesto.cantidad > 1) {
                                            currentRepuesto.cantidad--;
                                            // Actualizar en DB
                                            _updateRepuestoInDB(
                                              subItemId,
                                              currentRepuesto,
                                              db,
                                            );
                                          } else {
                                            subItemRepuestos[subItemId]!
                                                .removeWhere((r) =>
                                                    r.repuesto.id ==
                                                    repuesto.id);
                                            if (subItemRepuestos[subItemId]!
                                                .isEmpty) {
                                              subItemRepuestos
                                                  .remove(subItemId);
                                            }
                                            // Eliminar de DB
                                            /*   _deleteRepuestoFromDB(
                                              subItemId,
                                              repuesto.id,
                                              db,
                                            ); */
                                          }
                                        });
                                        this.setState(() {});
                                      },
                                    ),
                                    Text('${selectedRepuesto?.cantidad ?? 0}'),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () async {
                                        setState(() {
                                          final currentRepuesto =
                                              subItemRepuestos[subItemId]!
                                                  .firstWhere((r) =>
                                                      r.repuesto.id ==
                                                      repuesto.id);
                                          currentRepuesto.cantidad++;
                                        });
                                        this.setState(() {});
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () async {
                                        setState(() {
                                          subItemRepuestos[subItemId]!
                                              .removeWhere((r) =>
                                                  r.repuesto.id == repuesto.id);
                                          if (subItemRepuestos[subItemId]!
                                              .isEmpty) {
                                            subItemRepuestos.remove(subItemId);
                                          }
                                        });
                                        // Eliminar de DB
                                        /*    await _deleteRepuestoFromDB(
                                          subItemId,
                                          repuesto.id,
                                          db,
                                        ); */
                                        this.setState(() {});
                                      },
                                    ),
                                  ],
                                )
                              : IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () async {
                                    final newRepuesto =
                                        RepuestoAsignado(repuesto: repuesto);
                                    setState(() {
                                      if (subItemRepuestos[subItemId] == null) {
                                        subItemRepuestos[subItemId] = [];
                                      }
                                      subItemRepuestos[subItemId]!
                                          .add(newRepuesto);
                                    });
                                    // Guardar en DB
                                    await _saveRepuestoToDB(
                                      subItemId,
                                      newRepuesto,
                                      db,
                                    );
                                    this.setState(() {});
                                  },
                                ),
                        ),
                        if (isSelected)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Comentario',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) async {
                                setState(() {
                                  selectedRepuesto!.comentario = value;
                                });
                                // Actualizar comentario en DB
                                await _updateRepuestoInDB(
                                  subItemId,
                                  selectedRepuesto!,
                                  db,
                                );
                              },
                              controller: TextEditingController(
                                  text: selectedRepuesto?.comentario ?? ''),
                            ),
                          ),
                        const Divider(),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Funciones auxiliares para manejar la persistencia
  Future<void> _saveRepuestoToDB(
    int itemId,
    RepuestoAsignado repuesto,
    LocalDatabase db,
  ) async {
    try {
      await db.insertRepuesto(
        itemId,
        repuesto.repuesto,
        repuesto.cantidad,
        widget.visit.id,
        activoFijoId: currentActivoFijoId,
      );
    } catch (e) {
      print('Error guardando repuesto en DB: $e');
    }
  }

  Future<void> _updateRepuestoInDB(
    int itemId,
    RepuestoAsignado repuesto,
    LocalDatabase db,
  ) async {
    try {
      await db.actualizarCantidadRepuesto(
        itemId,
        repuesto.repuesto.id,
        widget.visit.id,
        repuesto.cantidad,
      );
    } catch (e) {
      print('Error actualizando repuesto en DB: $e');
    }
  }

  /* Future<void> _deleteRepuestoFromDB(
    int itemId,
    int repuestoId,
    LocalDatabase db,
  ) async {
    try {
      await db.deleteRepuesto(
        itemId,
        repuestoId,
        widget.visit.id,
      );
    } catch (e) {
      print('Error eliminando repuesto de DB: $e');
    }
  } */

  Future<void> _updateItemState(
      int activoId, int itemId, CheckState newState) async {
    try {
      final db = LocalDatabase();
      String estadoStr;
      switch (newState) {
        case CheckState.conforme:
          estadoStr = 'conforme';
          break;
        case CheckState.noConforme:
          estadoStr = 'noConforme';
          break;
        case CheckState.noAplica:
          estadoStr = 'noAplica';
          break;
      }

      await db.changeEstado(
        itemId,
        estadoStr,
        widget.visit.id,
        activoFijoId: currentActivoFijoId,
      );

      setState(() {
        if (subItemStates[activoId] == null) {
          subItemStates[activoId] = {};
        }
        subItemStates[activoId]![itemId] = newState;
      });
    } catch (e) {
      print('Error actualizando estado: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error guardando estado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onActivoFijoSelected(int activoFijoId) {
    setState(() {
      currentActivoFijoId = activoFijoId;
    });
    _loadChecklistData(activoFijoId);
  }

  Future<void> _loadChecklistData(int activoFijoId) async {
    try {
      final db = LocalDatabase();
      final data =
          await db.getChecklistClimaData(activoFijoId, widget.visit.id);

      setState(() {
        parametrosValues[activoFijoId] = {
          'setPoint': data['medicion_SetPoint'] ?? '0',
          'tempInjeccionFrio': data['medicion_TempInjeccionFrio'] ?? '0',
          'tempInjeccionCalor': data['medicion_TempInjeccionCalor'] ?? '0',
          'tempAmbiente': data['medicion_TempAmbiente'] ?? '0',
          'tempRetorno': data['medicion_TempRetorno'] ?? '0',
          'tempExterior': data['medicion_TempExterior'] ?? '0',
          'setPointObs': data['medicion_SetPoint_observacion'] ?? '',
          'tempInjeccionFrioObs':
              data['medicion_TempInjeccionFrio_observacion'] ?? '',
          'tempInjeccionCalorObs':
              data['medicion_TempInjeccionCalor_observacion'] ?? '',
          'tempAmbienteObs': data['medicion_TempAmbiente_observacion'] ?? '',
          'tempRetornoObs': data['medicion_TempRetorno_observacion'] ?? '',
          'tempExteriorObs': data['medicion_TempExterior_observacion'] ?? '',
          'consumoCompresorR': data['consumoCompresor_R'] ?? '0',
          'consumoCompresorS': data['consumoCompresor_S'] ?? '0',
          'consumoCompresorT': data['consumoCompresor_T'] ?? '0',
          'consumoCompresorN': data['consumoCompresor_N'] ?? '0',
          'tensionRS': data['tension_R_S'] ?? '0',
          'tensionST': data['tension_S_T'] ?? '0',
          'tensionTR': data['tension_T_R'] ?? '0',
          'tensionTN': data['tension_T_N'] ?? '0',
          'consumoTotalR': data['consumo_total_R'] ?? '0',
          'consumoTotalS': data['consumo_total_S'] ?? '0',
          'consumoTotalT': data['consumo_total_T'] ?? '0',
          'consumoTotalN': data['consumo_total_N'] ?? '0',
          'presionesAltas': data['presiones_altas'] ?? '0',
          'presionesBajas': data['presiones_bajas'] ?? '0',
        };
      });
    } catch (e) {
      print('Error cargando datos del checklist: $e');
    }
  }
}
