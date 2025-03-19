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

class ChecklistScreen extends StatefulWidget {
  final Visit visit;
  final List<InspeccionList> listasInspeccion;

  const ChecklistScreen({
    Key? key,
    required this.visit,
    required this.listasInspeccion,
  }) : super(key: key);

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

// Primero agregamos un enum para los estados
enum CheckState {
  conforme,
  noConforme,
  noAplica,
}

// Agregar una clase para manejar el repuesto con su cantidad
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
  final dynamic file; // Puede ser File or Uint8List
  final DateTime timestamp;
  final bool isWeb;

  ItemPhoto({
    required this.file,
    required this.timestamp,
    this.isWeb = false,
  });
}

// Primero agregar el modelo para ActivoFijo
class ActivoFijo {
  final int id;
  final String tipoEquipo;
  final String marca;
  final String potenciaEquipo;
  final String refrigerante;
  final String onOffInverter;
  final String suministra;
  final String codigoActivo;

  ActivoFijo({
    required this.id,
    required this.tipoEquipo,
    required this.marca,
    required this.potenciaEquipo,
    required this.refrigerante,
    required this.onOffInverter,
    required this.suministra,
    required this.codigoActivo,
  });

  factory ActivoFijo.fromJson(Map<String, dynamic> json) {
    return ActivoFijo(
      id: json['id'],
      tipoEquipo: json['tipo_equipo'],
      marca: json['marca'],
      potenciaEquipo: json['potencia_equipo'],
      refrigerante: json['refrigerante'],
      onOffInverter: json['on_off_inverter'],
      suministra: json['suministra'],
      codigoActivo: json['codigo_activo'],
    );
  }
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _apiService = ApiService();
  Map<int, bool> sectionChecks = {};
  Map<int, Map<int, bool>> subItemChecks = {};
  Map<int, Map<int, CheckState>> subItemStates =
      {}; // Nuevo mapa para los estados
  Map<int, List<RepuestoAsignado>> subItemRepuestos = {};
  List<Repuesto>? repuestos; // Para almacenar la lista de repuestos disponibles
  Map<int, List<ItemPhoto>> subItemPhotos = {};
  final ImagePicker _picker = ImagePicker();
  Map<int, String> subItemComments = {}; // Nuevo mapa para comentarios
  Uint8List? clientSignature;
  Map<int, List<String>> subItemPhotosUrls = {};
  int? currentSubItemId;
  Map<int, String> activoFijoEstados = {};
  Map<int, List<RepuestoAsignado>> activoFijoRepuestos = {};
  final observacionesController = TextEditingController();
  final nombreFirmanteController = TextEditingController();
  final cargoFirmanteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRepuestos();
    // Inicializar para cada lista y sus items
    for (var lista in widget.listasInspeccion) {
      sectionChecks[lista.id] = false;
      subItemChecks[lista.id] = {};
      subItemStates[lista.id] = {};
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          subItemChecks[lista.id]![subItem.id] = false;
          subItemStates[lista.id]![subItem.id] = CheckState.conforme;
        }
      }
    }
  }

  Future<void> _loadRepuestos() async {
    try {
      final data = await _apiService.get('repuestos');
      setState(() {
        repuestos =
            (data as List).map((item) => Repuesto.fromJson(item)).toList();
      });
    } catch (e) {
      print('Error cargando repuestos: $e');
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

  // Modificar el método para manejar fotos
  void _showPhotoOptions(int subItemId) {
    // Llamar directamente a _takePicture en lugar de mostrar opciones
    _takePicture(subItemId);

    // O si prefieres mantener el modal pero solo con la opción de cámara:
    /*
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _takePicture(subItemId);
              },
            ),
          ],
        ),
      ),
    );
    */
  }

  Future<bool> _requestPermission(Permission permission) async {
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      return result.isGranted;
    }
  }

  // Modificar el método para tomar/seleccionar foto
  Future<void> _pickImage(int subItemId, ImageSource source) async {
    try {
      // Solicitar permisos
      if (source == ImageSource.gallery) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          throw Exception('Se requiere permiso para acceder a la galería');
        }
      } else {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          throw Exception('Se requiere permiso para acceder a la cámara');
        }
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Reducir calidad para optimizar
        maxWidth: 1024, // Limitar tamaño máximo
      );

      if (image != null) {
        setState(() {
          subItemPhotos[subItemId] = [
            ...(subItemPhotos[subItemId] ?? []),
            ItemPhoto(
              file: image.path,
              timestamp: DateTime.now(),
              isWeb: false,
            ),
          ];
        });
      }
    } catch (e) {
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

  Future<void> _takePicture(int subItemId) async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _showLoadingDialog('Subiendo foto...');

        try {
          if (kIsWeb) {
            final bytes = await photo.readAsBytes();
            String photoUrl = await _uploadPhoto(
                bytes, widget.visit.id, subItemId, photo.name);

            setState(() {
              if (subItemPhotos[subItemId] == null) {
                subItemPhotos[subItemId] = [];
              }
              subItemPhotos[subItemId]!.add(
                ItemPhoto(
                  file: bytes,
                  timestamp: DateTime.now(),
                  isWeb: true,
                ),
              );
            });
          } else {
            // Para móvil, guardamos una copia del archivo
            final File photoFile = File(photo.path);
            String photoUrl = await _uploadPhoto(
                photoFile.path, widget.visit.id, subItemId, photo.name);

            setState(() {
              if (subItemPhotos[subItemId] == null) {
                subItemPhotos[subItemId] = [];
              }
              subItemPhotos[subItemId]!.add(
                ItemPhoto(
                  file: photoFile, // Guardamos el File completo
                  timestamp: DateTime.now(),
                  isWeb: false,
                ),
              );
            });
          }

          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto subida exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al subir la foto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar la foto: $e')),
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
  Widget _buildChecklistItem(InspeccionList lista, SubItem subItem) {
    final isChecked = subItemChecks[lista.id]?[subItem.id] ?? false;
    final state = subItemStates[lista.id]?[subItem.id] ?? CheckState.conforme;
    final repuestosAsignados = subItemRepuestos[subItem.id] ?? [];
    final photos = subItemPhotos[subItem.id] ?? [];
    final comment = subItemComments[subItem.id] ?? '';

    return Column(
      children: [
        CheckboxListTile(
          title: Text(
            subItem.name,
            style: const TextStyle(fontSize: 14),
          ),
          value: isChecked,
          onChanged: (bool? value) {
            setState(() {
              if (subItemChecks[lista.id] == null) {
                subItemChecks[lista.id] = {};
              }
              if (subItemStates[lista.id] == null) {
                subItemStates[lista.id] = {};
              }
              subItemChecks[lista.id]![subItem.id] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
        if (isChecked) ...[
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          _showStateSelector(context, lista, subItem),
                      icon: Icon(
                        Icons.check_circle,
                        color: _getStateColor(state),
                      ),
                      label: Text(
                        _getStateText(state),
                        style: TextStyle(
                          color: _getStateColor(state),
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showPhotoOptions(subItem.id),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Agregar Foto'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3F3FFF),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showCommentDialog(subItem.id),
                      icon: const Icon(Icons.comment),
                      label: const Text('Comentario'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3F3FFF),
                      ),
                    ),
                    if ((state == CheckState.noConforme ||
                        state == CheckState.conforme))
                      TextButton.icon(
                        onPressed: () => _showRepuestosDialog(subItem.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Repuesto'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3F3FFF),
                        ),
                      ),
                  ],
                ),
                // Mostrar comentario si existe
                if (comment.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.comment, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            comment,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          onPressed: () => _showCommentDialog(subItem.id),
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                // Mostrar fotos en grid
                if (photos.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: photos.map((photo) {
                        return _buildPhotoThumbnail(photo,
                            subItemId: subItem.id);
                      }).toList(),
                    ),
                  ),
                // Lista de repuestos
                if (repuestosAsignados.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: repuestosAsignados
                          .map((repuestoAsignado) =>
                              _buildRepuestoItem(repuestoAsignado, subItem.id))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoThumbnail(ItemPhoto photo, {required int subItemId}) {
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
            child: photo.isWeb
                ? Image.memory(
                    photo.file as Uint8List,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    photo.file as File,
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
              setState(() {
                subItemPhotos[subItemId]?.remove(photo);
              });
            },
          ),
        ),
      ],
    );
  }

  String _getStateText(CheckState state) {
    switch (state) {
      case CheckState.conforme:
        return 'Conforme';
      case CheckState.noConforme:
        return 'No Conforme';
      case CheckState.noAplica:
        return 'No Aplica';
    }
  }

  Color _getStateColor(CheckState state) {
    switch (state) {
      case CheckState.conforme:
        return Colors.green;
      case CheckState.noConforme:
        return Colors.red;
      case CheckState.noAplica:
        return Colors.grey;
    }
  }

  void _showRepuestosDialog(int subItemId) {
    String searchQuery = ''; // Para el filtro de búsqueda
    List<Repuesto> filteredRepuestos = repuestos ?? []; // Lista filtrada

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Repuestos'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StatefulBuilder(
            builder: (context, setState) {
              // Filtrar repuestos basado en la búsqueda
              filteredRepuestos = (repuestos ?? []).where((repuesto) {
                return repuesto.articulo
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    repuesto.familia
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()) ||
                    repuesto.marca
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase());
              }).toList();

              return Column(
                children: [
                  // Campo de búsqueda
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar repuesto...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  // Lista de repuestos filtrada
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredRepuestos.length,
                      itemBuilder: (context, index) {
                        final repuesto = filteredRepuestos[index];
                        return ListTile(
                          title: Text(repuesto.articulo),
                          subtitle:
                              Text('${repuesto.familia} - ${repuesto.marca}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              this.setState(() {
                                if (subItemRepuestos[subItemId] == null) {
                                  subItemRepuestos[subItemId] = [];
                                }

                                subItemRepuestos[subItemId]!.add(
                                  RepuestoAsignado(
                                    repuesto: repuesto,
                                    comentario: '',
                                  ),
                                );

                                print('Repuesto agregado:');
                                print('SubItem ID: $subItemId');
                                print('Repuesto: ${repuesto.articulo}');
                                print('Cantidad: 1');
                                print(
                                    'Total repuestos en este item: ${subItemRepuestos[subItemId]!.length}');
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Repuesto ${repuesto.articulo} agregado'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
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

  // Mantener el widget _buildRepuestoItem como estaba antes
  Widget _buildRepuestoItem(RepuestoAsignado repuestoAsignado, int subItemId) {
    return ListTile(
      dense: true,
      title: Text(
        repuestoAsignado.repuesto.articulo,
        style: const TextStyle(fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${repuestoAsignado.repuesto.familia} - ${repuestoAsignado.repuesto.marca}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            onPressed: () {
              setState(() {
                if (repuestoAsignado.cantidad > 1) {
                  repuestoAsignado.cantidad--;
                } else {
                  subItemRepuestos[subItemId]?.remove(repuestoAsignado);
                }
              });
            },
          ),
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
              '${repuestoAsignado.cantidad}',
              style: const TextStyle(
                fontSize: 16,
                height: 1,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              size: 28,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            onPressed: () {
              setState(() {
                repuestoAsignado.cantidad++;
              });
            },
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 28,
              color: Colors.red,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            onPressed: () {
              setState(() {
                subItemRepuestos[subItemId]?.remove(repuestoAsignado);
              });
            },
          ),
        ],
      ),
    );
  }

  // Agregar método para mostrar el diálogo de comentario
  void _showCommentDialog(int subItemId) {
    final TextEditingController commentController = TextEditingController(
      text: subItemComments[subItemId] ?? '',
    );

    showDialog(
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
            onPressed: () {
              setState(() {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  subItemComments.remove(subItemId);
                } else {
                  subItemComments[subItemId] = comment;
                }
              });
              Navigator.pop(context);
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Primero los checklists
                ...widget.listasInspeccion.map((lista) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F3FFF).withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Text(
                          lista.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ...lista.items
                          .map((item) => Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: item.subItems.length,
                                      itemBuilder: (context, subIndex) {
                                        final subItem = item.subItems[subIndex];
                                        return _buildChecklistItem(
                                            lista, subItem);
                                      },
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                      const SizedBox(height: 24), // Espacio entre listas
                    ],
                  );
                }).toList(),

                // Luego los activos fijos
                _buildActivosFijos(),

                // Espacio adicional al final para mejor visualización
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Card inferior con el resumen y botón de finalizar
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
                                  content:
                                      Text(_getMissingRequirementsMessage()),
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
          if (subItemChecks[lista.id]?[subItem.id] == true) {
            completed++;
          }
        }
      }
    }
    return completed;
  }

  bool _canFinish() {
    bool allItemsComplete = _getTotalSubItems() == _getCompletedSubItems();
    bool allNoConformeHavePhotos = true;

    // Verificar que todos los items no conformes tengan al menos una foto
    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
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

    return allItemsComplete && allNoConformeHavePhotos;
  }

  String _getMissingRequirementsMessage() {
    List<String> missing = [];

    if (_getTotalSubItems() != _getCompletedSubItems()) {
      missing.add('Hay items sin completar');
    }

    // Solo verificar fotos para items no conformes
    bool hasNoConformeWithoutPhoto = false;
    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          final state = subItemStates[lista.id]?[subItem.id];
          if (state == CheckState.noConforme) {
            final hasPhotos = (subItemPhotos[subItem.id]?.isNotEmpty ?? false);
            if (!hasPhotos) {
              hasNoConformeWithoutPhoto = true;
              break;
            }
          }
        }
      }
    }

    if (hasNoConformeWithoutPhoto) {
      missing.add('Faltan fotos en items no conformes');
    }

    return missing.join(', ');
  }

  Future<String> _uploadPhoto(
      dynamic file, int visitId, int subItemId, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      var uri = Uri.parse(
          '${ApiService.baseUrl}/upload/solicitudes/$visitId/$subItemId');
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (kIsWeb) {
        var multipartFile = http.MultipartFile.fromBytes(
          'file',
          file as Uint8List,
          filename: name,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      } else {
        var multipartFile = await http.MultipartFile.fromPath(
          'file',
          file as String,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(multipartFile);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        var jsonResponse = json.decode(response.body);
        String photoUrl = jsonResponse['url'] ?? '';

        if (photoUrl.isNotEmpty) {
          // Convertir URL relativa a absoluta si es necesario
          if (photoUrl.startsWith('/')) {
            photoUrl = '${ApiService.baseUrl}$photoUrl';
          } else if (photoUrl.startsWith('http://localhost')) {
            // Reemplazar localhost con la URL base
            photoUrl = photoUrl.replaceFirst(
                'http://localhost:3000', ApiService.baseUrl);
          }

          if (!subItemPhotosUrls.containsKey(subItemId)) {
            subItemPhotosUrls[subItemId] = [];
          }
          subItemPhotosUrls[subItemId]!.add(photoUrl);
          print('URL guardada para subItem $subItemId: $photoUrl');
          return photoUrl;
        } else {
          throw Exception('URL de foto no encontrada en la respuesta');
        }
      } else {
        throw Exception('Error al subir la foto: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al subir la foto: $e');
      throw e;
    }
  }

  Future<void> _finalizarVisita(String signature) async {
    try {
      // Preparar los datos de activos fijos
      final activosFijosData = activoFijoRepuestos.entries.map((entry) {
        final activoId = entry.key;
        final repuestos = entry.value;

        return {
          "activoFijoId": activoId,
          "estadoOperativo": activoFijoEstados[activoId] ?? 'funcionando',
          "observacionesEstado": "",
          "repuestos": repuestos
              .map((repuesto) => {
                    "repuestoId": repuesto.repuesto.id,
                    "cantidad": repuesto.cantidad,
                    "comentario": repuesto.comentario ?? "",
                    "estado": "pendiente",
                    "precio_unitario": repuesto.repuesto.precio,
                  })
              .toList(),
        };
      }).toList();

      // Enviar los datos de activos fijos
      await _apiService.post(
        'activo-fijo-repuestos/solicitud/${widget.visit.id}/repuestos',
        {
          "activoFijoRepuestos": activosFijosData,
        },
      );

      // Enviar los datos de la visita
      final response = await _apiService.post(
        'visita/solicitud/${widget.visit.id}/finalizar',
        {
          "observaciones": observacionesController.text,
          "firma": signature,
          "nombreFirmante": nombreFirmanteController.text,
          "cargoFirmante": cargoFirmanteController.text,
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visita finalizada con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Error al finalizar la visita');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar la visita: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Agregar este método helper
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

  // Modificar el widget _buildActivosFijos para incluir la sección de repuestos
  Widget _buildActivosFijos() {
    // Acceder a los datos raw de la visita
    final visitData = widget.visit.toJson();
    final localData = visitData['local'] as Map<String, dynamic>;
    final activoFijoLocales =
        localData['activoFijoLocales'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3F3FFF).withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: const Text(
            'Activos Fijos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...activoFijoLocales.map((activo) {
                  final activoId = activo['id'] as int;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text('Equipo: ${activo['tipo_equipo']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Marca: ${activo['marca']}'),
                            Text('Código: ${activo['codigo_activo']}'),
                            Text('Potencia: ${activo['potencia_equipo']}'),
                            Text('Refrigerante: ${activo['refrigerante']}'),
                            Text('Tipo: ${activo['on_off_inverter']}'),
                            Text('Suministra: ${activo['suministra']}'),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value:
                                  activoFijoEstados[activoId] ?? 'funcionando',
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'funcionando',
                                    child: Text('Funcionando')),
                                DropdownMenuItem(
                                    value: 'detenido', child: Text('Detenido')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  activoFijoEstados[activoId] = value!;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Repuestos:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () =>
                                      _showActivoFijoRepuestosDialog(activoId),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar'),
                                ),
                              ],
                            ),
                            if (activoFijoRepuestos[activoId]?.isNotEmpty ??
                                false)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: activoFijoRepuestos[activoId]!
                                      .map((repuesto) {
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        repuesto.repuesto.articulo,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${repuesto.repuesto.familia} - ${repuesto.repuesto.marca}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 28),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (repuesto.cantidad > 1) {
                                                  repuesto.cantidad--;
                                                } else {
                                                  activoFijoRepuestos[activoId]!
                                                      .remove(repuesto);
                                                }
                                              });
                                            },
                                          ),
                                          Container(
                                            width: 30,
                                            alignment: Alignment.center,
                                            child: Text(
                                              '${repuesto.cantidad}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                height: 1,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 28),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                repuesto.cantidad++;
                                              });
                                            },
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 28,
                                                color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                activoFijoRepuestos[activoId]!
                                                    .remove(repuesto);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Modificar el método para mostrar el diálogo de repuestos de activos fijos
  void _showActivoFijoRepuestosDialog(int activoId) {
    String searchQuery = '';
    List<Repuesto> filteredRepuestos = repuestos ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Text('Seleccionar Repuesto'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar repuesto...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      searchQuery = value.toLowerCase();
                      filteredRepuestos = (repuestos ?? []).where((repuesto) {
                        return repuesto.articulo
                                .toLowerCase()
                                .contains(searchQuery) ||
                            repuesto.familia
                                .toLowerCase()
                                .contains(searchQuery) ||
                            repuesto.marca.toLowerCase().contains(searchQuery);
                      }).toList();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: filteredRepuestos.length,
                      itemBuilder: (context, index) {
                        final repuesto = filteredRepuestos[index];
                        return ListTile(
                          title: Text(repuesto.articulo),
                          subtitle:
                              Text('${repuesto.familia} - ${repuesto.marca}'),
                          onTap: () {
                            setState(() {
                              if (activoFijoRepuestos[activoId] == null) {
                                activoFijoRepuestos[activoId] = [];
                              }
                              // Verificar si el repuesto ya existe
                              final existingRepuesto =
                                  activoFijoRepuestos[activoId]!.firstWhere(
                                (r) => r.repuesto.id == repuesto.id,
                                orElse: () => RepuestoAsignado(
                                  repuesto: repuesto,
                                  cantidad: 0,
                                  comentario: '',
                                ),
                              );

                              if (existingRepuesto.cantidad == 0) {
                                // Si no existe, agregarlo
                                activoFijoRepuestos[activoId]!.add(
                                  RepuestoAsignado(
                                    repuesto: repuesto,
                                    cantidad: 1,
                                    comentario: '',
                                  ),
                                );
                              } else {
                                // Si existe, incrementar la cantidad
                                existingRepuesto.cantidad++;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finalizarInspeccion() async {
    try {
      // Preparar los datos de los activos fijos
      final activosFijosData = widget.visit.activoFijoRepuestos.map((activo) {
        final activoId = activo['id'] as int;
        final repuestosAsignados = activoFijoRepuestos[activoId] ?? [];

        return {
          "activoFijoId": activoId,
          "estadoOperativo":
              activoFijoEstados[activoId] ?? activo['estadoOperativo'],
          "observacionesEstado": activo['observacionesEstado'] ?? "",
          "repuestos": repuestosAsignados
              .map((repuesto) => {
                    "repuestoId": repuesto.repuesto.id,
                    "cantidad": repuesto.cantidad,
                    "comentario": repuesto.comentario ?? "",
                    "estado": "pendiente",
                    "precio_unitario": repuesto.repuesto.precio,
                  })
              .toList(),
        };
      }).toList();

      // Enviar los datos de activos fijos al backend
      await _apiService.post(
        '/activo-fijo-repuestos/solicitud/${widget.visit.id}/repuestos',
        {
          "activoFijoRepuestos": activosFijosData,
        },
      );

      // Continuar con el envío de los datos del checklist
      final checklistData = widget.listasInspeccion.map((lista) {
        // ... código existente para preparar datos del checklist ...
      }).toList();

      await _apiService.post(
        '/inspeccion/solicitud/${widget.visit.id}/checklists',
        {
          "checklists": checklistData,
        },
      );

      // Mostrar mensaje de éxito y navegar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspección finalizada con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar la inspección: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
