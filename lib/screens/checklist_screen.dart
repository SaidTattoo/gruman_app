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
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/checklist_model.dart';

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

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _apiService = ApiService();
  Map<int, bool> sectionChecks = {};
  Map<int, Map<int, bool>> subItemChecks = {};
  Map<int, Map<int, CheckState>> subItemStates =
      {}; // Nuevo mapa para los estados
  Map<int, List<RepuestoAsignado>> subItemRepuestos = {};
  List<Repuesto>? repuestos; // Para almacenar la lista de repuestos disponibles
  Map<int, List<String>> subItemPhotos = {}; // Solo almacena paths o base64
  final ImagePicker _picker = ImagePicker();
  Map<int, String> subItemComments = {}; // Nuevo mapa para comentarios
  Uint8List? clientSignature;
  Map<int, List<String>> subItemPhotosUrls = {};
  int? currentSubItemId;
  Map<int, String> activoFijoEstados = {};

  @override
  void initState() {
    super.initState();
    _loadRepuestos();
    _loadLocalData();
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
    // Inicializar estados de activos fijos como "funcionando"
    for (var activo in widget.visit.local.activoFijoLocales) {
      activoFijoEstados[activo.id] = 'funcionando';
    }
  }

  Future<void> _loadRepuestos() async {
    try {
      final response = await LocalDatabase().listadoRepuestos();
      print('Respuesta de repuestos raw: $response');

      if (response.isEmpty) {
        print('No hay repuestos en la base de datos local');
        return;
      }

      setState(() {
        repuestos = response.map((item) {
          try {
            return Repuesto(
                id: item['id'] as int,
                articulo: item['articulo'] as String,
                familia: item['familia'] as String,
                marca: item['marca'] as String,
                codigoBarra: item['codigoBarra'] as String,
                precio_compra: (item['precio_compra'] as num).toDouble(),
                precio_venta: (item['precio_venta'] as num).toDouble(),
                valor_uf: (item['valor_uf'] as num).toDouble(),
                clima: item['clima'] == 1);
          } catch (e) {
            print('Error convirtiendo repuesto: $e');
            print('Datos del repuesto: $item');
            rethrow;
          }
        }).toList();

        print('Repuestos cargados exitosamente: ${repuestos?.length}');
      });
    } catch (e) {
      print('Error cargando repuestos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error cargando repuestos. Por favor, intente de nuevo.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: () => _loadRepuestos(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final db = LocalDatabase();

      // Primero, obtener todos los estados guardados para esta visita
      final allEstados = await db.getEstados(
        'item_estado',
        where: 'solicitarVisitaId = ?',
        whereArgs: [widget.visit.id],
      );

      print('Estados encontrados en DB local: ${allEstados.length}');

      // Cargar estados
      for (var lista in widget.listasInspeccion) {
        if (!subItemStates.containsKey(lista.id)) {
          subItemStates[lista.id] = {};
        }
        if (!subItemChecks.containsKey(lista.id)) {
          subItemChecks[lista.id] = {};
        }

        for (var item in lista.items) {
          for (var subItem in item.subItems) {
            // Buscar el estado para este subItem
            final estadoItem = allEstados.firstWhere(
              (estado) => estado['itemId'].toString() == subItem.id.toString(),
              orElse: () => {},
            );

            if (estadoItem.isNotEmpty) {
              print(
                  'Encontrado estado para subItem ${subItem.id}: ${estadoItem['estado']}');

              setState(() {
                // Marcar el checkbox como checked
                subItemChecks[lista.id]![subItem.id] = true;

                // Establecer el estado
                subItemStates[lista.id]![subItem.id] =
                    _getCheckStateFromString(estadoItem['estado'] as String);

                // Guardar comentario si existe
                if (estadoItem['comentario'] != null &&
                    estadoItem['comentario'].toString().isNotEmpty) {
                  subItemComments[subItem.id] =
                      estadoItem['comentario'] as String;
                }
              });
            } else {
              print('No se encontró estado para subItem ${subItem.id}');
            }
          }
        }
      }

      // Cargar fotos
      final allFotos = await db.getFotosItem(
        'item_fotos',
        where: 'solicitarVisitaId = ?',
        whereArgs: [widget.visit.id],
      );

      for (var foto in allFotos) {
        final subItemId = int.parse(foto['itemId'].toString());
        final fotoBase64 = foto['fotos'] as String;

        setState(() {
          if (subItemPhotos[subItemId] == null) {
            subItemPhotos[subItemId] = [];
          }
          subItemPhotos[subItemId]!.add(fotoBase64);
        });
      }

      // Cargar repuestos
      final allRepuestos = await db.getRepuestos(widget.visit.id);

      for (var repuesto in allRepuestos) {
        final subItemId = int.parse(repuesto['itemId'].toString());
        final repuestoId = int.parse(repuesto['repuestoId'].toString());

        final repuestoEncontrado = this.repuestos?.firstWhere(
              (r) => r.id == repuestoId,
              orElse: () => Repuesto(
                id: -1,
                articulo: '',
                familia: '',
                marca: '',
                codigoBarra: '',
                precio_compra: 0,
                precio_venta: 0,
                valor_uf: 0,
                clima: false,
              ),
            );

        if (repuestoEncontrado != null) {
          setState(() {
            if (!subItemRepuestos.containsKey(subItemId)) {
              subItemRepuestos[subItemId] = [];
            }

            subItemRepuestos[subItemId]!.add(
              RepuestoAsignado(
                repuesto: repuestoEncontrado,
                cantidad: int.parse(repuesto['cantidad'].toString()),
                comentario: repuesto['comentario'] as String?,
              ),
            );
          });
        }
      }

      print('Datos locales cargados exitosamente');
      // Imprimir estado final para debugging
      subItemStates.forEach((listaId, estados) {
        estados.forEach((subItemId, estado) {
          print(
              'Lista: $listaId, SubItem: $subItemId, Estado: $estado, Checked: ${subItemChecks[listaId]![subItemId]}');
        });
      });
    } catch (e, stackTrace) {
      print('Error cargando datos locales: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Método auxiliar mejorado para convertir string a CheckState
  CheckState _getCheckStateFromString(String estado) {
    switch (estado.toLowerCase()) {
      case 'conforme':
        return CheckState.conforme;
      case 'no_conforme':
        return CheckState.noConforme;
      case 'no_aplica':
        return CheckState.noAplica;
      default:
        print('Estado no reconocido: $estado, usando conforme por defecto');
        return CheckState.conforme;
    }
  }

  // Función para mostrar el selector de estado
  void _showStateSelector(
      BuildContext context, InspeccionList lista, SubItem subItem) {
    CheckState selectedState = subItemStates[lista.id]![subItem.id]!;
    final db = LocalDatabase();

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
            onPressed: () async {
              this.setState(() {
                subItemStates[lista.id]![subItem.id] = selectedState;
              });

              // Actualizar el estado en la base de datos local
              await db.changeEstado(
                subItem.id,
                _getEstadoString(selectedState),
                widget.visit.id,
              );

              if (selectedState == CheckState.noConforme) {
                // Mostrar recordatorio para agregar foto
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'No olvides agregar una foto para el item no conforme'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                });
              }
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
            image.path,
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
        _showLoadingDialog('Procesando foto...');

        try {
          final bytes = await photo.readAsBytes();
          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 1024,
            minWidth: 1024,
            quality: 70,
          );
          final base64Image = base64Encode(compressedBytes);

          // Guardar en DB local
          final db = LocalDatabase();
          await db.subirFoto(subItemId, base64Image, widget.visit.id);

          setState(() {
            if (subItemPhotos[subItemId] == null) {
              subItemPhotos[subItemId] = [];
            }
            subItemPhotos[subItemId]!.add(base64Image);
          });

          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto guardada correctamente')),
          );
        } catch (e) {
          Navigator.of(context, rootNavigator: true).pop();
          throw e;
        }
      }
    } catch (e) {
      print('Error procesando foto: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar la foto: $e')),
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
    final db = LocalDatabase();
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
          onChanged: (bool? value) async {
            final db = LocalDatabase();
            setState(() {
              if (subItemChecks[lista.id] == null) {
                subItemChecks[lista.id] = {};
              }
              if (subItemStates[lista.id] == null) {
                subItemStates[lista.id] = {};
              }
              subItemChecks[lista.id]![subItem.id] = value ?? false;
            });

            // Guardar en DB local
            try {
              await db.itemEstado(
                subItem.itemId,
                _getStateText(state),
                widget.visit.id,
                '', // comentario vacío inicial
              );
              print(
                  'Estado guardado: ItemID: ${subItem.itemId}, Estado: ${_getStateText(state)}');
            } catch (e) {
              print('Error guardando estado: $e');
            }
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
                // Estado
                TextButton.icon(
                  onPressed: () => _showStateSelector(context, lista, subItem),
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

                // Botones en columna
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _showPhotoOptions(subItem.id),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Agregar Foto'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3F3FFF),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _showCommentDialog(subItem.id),
                        icon: const Icon(Icons.comment),
                        label: const Text('Comentario'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3F3FFF),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    if (state == CheckState.noConforme ||
                        state == CheckState.conforme)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => _showRepuestosDialog(subItem.id),
                          icon: const Icon(Icons.add),
                          label: const Text('Repuesto'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF3F3FFF),
                            alignment: Alignment.centerLeft,
                          ),
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
                          .map((repuesto) =>
                              _buildRepuestoItem(repuesto, subItem.id))
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

  Widget _buildPhotoThumbnail(String base64Image, {required int subItemId}) {
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
            child: Image.memory(
              base64Decode(base64Image),
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
                subItemPhotos[subItemId]?.remove(base64Image);
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
        return 'conforme';
      case CheckState.noConforme:
        return 'no_conforme';
      case CheckState.noAplica:
        return 'no_aplica';
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
    if (repuestos == null) {
      _loadRepuestos();
    }

    String searchQuery = '';
    List<Repuesto> filteredRepuestos = repuestos ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Repuestos'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
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
                        setDialogState(() {
                          searchQuery = value;
                          filteredRepuestos =
                              (repuestos ?? []).where((repuesto) {
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
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredRepuestos.length,
                      itemBuilder: (context, index) {
                        final repuesto = filteredRepuestos[index];
                        return ListTile(
                          title: Text(repuesto.articulo),
                          subtitle:
                              Text('${repuesto.familia} - ${repuesto.marca}'),
                          onTap: () {
                            Navigator.pop(context);
                            _addRepuesto(subItemId, repuesto);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
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
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () async {
              if (repuestoAsignado.cantidad > 1) {
                try {
                  final nuevaCantidad = repuestoAsignado.cantidad - 1;
                  await LocalDatabase().actualizarCantidadRepuesto(
                    subItemId,
                    repuestoAsignado.repuesto.id,
                    widget.visit.id,
                    nuevaCantidad,
                  );
                  setState(() {
                    repuestoAsignado.cantidad = nuevaCantidad;
                  });
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar cantidad: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          Text('${repuestoAsignado.cantidad}'),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () async {
              try {
                final nuevaCantidad = repuestoAsignado.cantidad + 1;
                await LocalDatabase().actualizarCantidadRepuesto(
                  subItemId,
                  repuestoAsignado.repuesto.id,
                  widget.visit.id,
                  nuevaCantidad,
                );
                setState(() {
                  repuestoAsignado.cantidad++;
                });
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al actualizar cantidad: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
    final db = LocalDatabase();

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

              // Actualizar la base de datos local
              try {
                await db.updateComentario(subItemId, comment);
                print(
                    'Comentario actualizado en DB local para subItemId: $subItemId');
              } catch (e) {
                print('Error actualizando comentario en DB local: $e');
                // Opcional: Mostrar mensaje de error al usuario
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
              itemCount: widget.listasInspeccion.length +
                  1, // +1 para la sección de activos fijos
              itemBuilder: (context, index) {
                if (index < widget.listasInspeccion.length) {
                  final lista = widget.listasInspeccion[index];
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
                                    ListTile(
                                      title: Text(item.name),
                                      trailing: _buildChangeStateButton(
                                          item, lista.id),
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
                } else {
                  // Sección de Activos Fijos
                  return Column(
                    children: [
                      const SizedBox(height: 24),
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
                          'Activos Fijos del Local',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.visit.local.activoFijoLocales.length,
                        itemBuilder: (context, index) {
                          final activo =
                              widget.visit.local.activoFijoLocales[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${activo.tipoEquipo} - ${activo.marca}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Código: ${activo.codigoActivo}'),
                                  Text('Potencia: ${activo.potenciaEquipo}'),
                                  Text('Refrigerante: ${activo.refrigerante}'),
                                  Text('Tipo: ${activo.onOffInverter}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Text('Estado: '),
                                      DropdownButton<String>(
                                        value: activoFijoEstados[activo.id],
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'funcionando',
                                            child: Text('Funcionando'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'detenido',
                                            child: Text('Detenido'),
                                          ),
                                        ],
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              activoFijoEstados[activo.id] =
                                                  newValue;
                                            });
                                          }
                                        },
                                      ),
                                      const Spacer(),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _showRepuestosDialog(activo.id),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Repuesto'),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF3F3FFF),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (subItemRepuestos[activo.id]?.isNotEmpty ??
                                      false)
                                    ...subItemRepuestos[activo.id]!
                                        .map((repuesto) => _buildRepuestoItem(
                                            repuesto, activo.id))
                                        .toList(),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                }
              },
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
                        'Total de items: ${_getTotalItemsCount(widget.listasInspeccion[0].id)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Completados: ${_getCompletedItemsCount(widget.listasInspeccion[0].id)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        print('Botón presionado');
                        try {
                          final signature = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignatureScreen(),
                            ),
                          );

                          if (signature != null) {
                            // Remover el prefijo de data URL
                            final base64String = signature.split(',')[1];
                            setState(() {
                              clientSignature = base64Decode(base64String);
                            });
                            await _finalizarVisita();
                          }
                        } catch (e) {
                          print('Error en botón de finalizar: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F3FFF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Finalizar Visita',
                        style: TextStyle(color: Colors.white),
                      ),
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

  int _getTotalItemsCount(int listaId) {
    return widget.listasInspeccion
        .firstWhere((l) => l.id == listaId)
        .items
        .fold(0, (sum, item) => sum + item.subItems.length);
  }

  int _getCompletedItemsCount(int listaId) {
    int completed = 0;
    for (var item
        in widget.listasInspeccion.firstWhere((l) => l.id == listaId).items) {
      for (var subItem in item.subItems) {
        if (subItemChecks[listaId]?[subItem.id] == true) {
          completed++;
        }
      }
    }
    return completed;
  }

  bool _areAllItemsChecked() {
    for (var lista in widget.listasInspeccion) {
      for (var item in lista.items) {
        for (var subItem in item.subItems) {
          if (subItemChecks[lista.id]?[subItem.id] != true) {
            return false;
          }
        }
      }
    }
    return true;
  }

  String _getMissingRequirementsMessage() {
    List<String> missing = [];

    if (_getTotalItemsCount(widget.listasInspeccion[0].id) !=
        _getCompletedItemsCount(widget.listasInspeccion[0].id)) {
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
      final db = LocalDatabase();

      // Comprimir y convertir a base64
      String base64Image = '';
      if (kIsWeb) {
        // Para web, el archivo ya viene como Uint8List
        final bytes = file as Uint8List;
        try {
          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 1024,
            minWidth: 1024,
            quality: 70,
          );
          base64Image = base64Encode(compressedBytes);
        } catch (e) {
          print('Error comprimiendo imagen web: $e');
          // Si falla la compresión, usar la imagen original
          base64Image = base64Encode(bytes);
        }
      } else {
        // Para móvil, tenemos la ruta del archivo
        try {
          final bytes = await File(file as String).readAsBytes();
          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minHeight: 1024,
            minWidth: 1024,
            quality: 70,
          );
          base64Image = base64Encode(compressedBytes);
        } catch (e) {
          print('Error comprimiendo imagen móvil: $e');
          // Si falla la compresión, usar la imagen original
          final bytes = await File(file as String).readAsBytes();
          base64Image = base64Encode(bytes);
        }
      }

      // Guardar en la base de datos local
      await db.subirFoto(subItemId, base64Image, visitId);

      // Generar una URL temporal local para la UI
      String localPhotoId = DateTime.now().millisecondsSinceEpoch.toString();
      String tempUrl = 'local://$localPhotoId';

      // Actualizar el estado de la UI
      if (!subItemPhotosUrls.containsKey(subItemId)) {
        subItemPhotosUrls[subItemId] = [];
      }
      subItemPhotosUrls[subItemId]!.add(tempUrl);

      print('Foto guardada localmente para subItem $subItemId');
      return tempUrl;
    } catch (e) {
      print('Error al guardar la foto localmente: $e');
      throw e;
    }
  }

  Future<void> _finalizarVisita() async {
    try {
      final db = LocalDatabase();

      if (clientSignature == null) {
        throw Exception('Se requiere la firma del cliente');
      }

      // Convertir firma a base64
      final firmaCliente = base64Encode(clientSignature!);

      // Obtener datos de la base de datos local
      final estados = await db.getEstados(
        'item_estado',
        where: 'solicitarVisitaId = ?',
        whereArgs: [widget.visit.id],
      );

      final fotos = await db.getFotosItem(
        'item_fotos',
        where: 'solicitarVisitaId = ?',
        whereArgs: [widget.visit.id],
      );

      final repuestos = await db.getRepuestos(widget.visit.id);

      // Armar el payload
      final Map<int, Map<String, dynamic>> itemsData = {};

      // Procesar estados
      for (final estado in estados) {
        final itemId = int.parse(estado['itemId'].toString());
        itemsData.putIfAbsent(
            itemId,
            () => {
                  'id': itemId,
                  'estado': estado['estado'],
                  'comentario': estado['comentario'] ?? '',
                  'fotos': [],
                  'repuestos': [],
                });
      }

      // Agregar fotos
      for (final foto in fotos) {
        final itemId = int.parse(foto['itemId'].toString());
        if (itemsData.containsKey(itemId)) {
          itemsData[itemId]!['fotos'].add(foto['fotos']);
        }
      }

      // Agregar repuestos
      for (final repuesto in repuestos) {
        final itemId = int.parse(repuesto['itemId'].toString());
        final repuestoMap = {
          'id': 1,
          'cantidad': int.parse(repuesto['cantidad'].toString()),
          'comentario': repuesto['comentario'] ?? '',
          'estado': 'pendiente',
          'precio_unitario':
              double.tryParse(repuesto['precio_venta'].toString()) ?? 0,
          'repuesto': {
            'id': int.parse(repuesto['repuestoId'].toString()),
            'nombre': repuesto['nombre'] ?? 'Repuesto',
          }
        };

        if (itemsData.containsKey(itemId)) {
          itemsData[itemId]!['repuestos'].add(repuestoMap);
        }
      }

      final payload = {
        'firma_cliente': firmaCliente,
        'repuestos':
            itemsData.map((key, value) => MapEntry(key.toString(), value)),
      };

      // Antes de enviar, imprimir el payload para debug
      print('Payload a enviar:');
      print(jsonEncode(payload));

      // Enviar al servidor
      final response =
          await ApiService.finalizarVisita(widget.visit.id, payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Si es exitoso, eliminar la solicitud
        await db.deleteSolicitud(widget.visit.id);

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        // Si falla, marcar como pendiente de subir
        await db.marcarComoPendienteDeSubir(widget.visit.id);
        throw Exception('Error al finalizar la visita: ${response.statusCode}');
      }
    } catch (e) {
      // Si hay cualquier error, marcar como pendiente de subir
      await LocalDatabase().marcarComoPendienteDeSubir(widget.visit.id);

      print('Error: $e');
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

  void _addRepuesto(int subItemId, Repuesto repuesto) async {
    try {
      // Primero guardar en la base de datos local
      await LocalDatabase().insertRepuesto(
        subItemId,
        repuesto,
        1, // cantidad inicial
        widget.visit.id, // ID de la visita
      );

      // Luego actualizar la UI
      setState(() {
        if (!subItemRepuestos.containsKey(subItemId)) {
          subItemRepuestos[subItemId] = [];
        }
        subItemRepuestos[subItemId]!.add(
          RepuestoAsignado(
            repuesto: repuesto,
            cantidad: 1,
          ),
        );
      });

      print('Repuesto agregado a DB local y UI:');
      print('SubItem ID: $subItemId');
      print('Repuesto: ${repuesto.articulo}');
      print('Visita ID: ${widget.visit.id}');
    } catch (e) {
      print('Error al guardar repuesto en DB local: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar repuesto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Agregar este widget antes de la lista de subItems
  Widget _buildMarkAllConformeButton(int listaId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            // Obtener todos los subItems de esta lista
            for (var item in widget.listasInspeccion
                .firstWhere((l) => l.id == listaId)
                .items) {
              for (var subItem in item.subItems) {
                // Marcar como checked y conforme
                subItemChecks[listaId]![subItem.id] = true;
                subItemStates[listaId]![subItem.id] = CheckState.conforme;
              }
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Todos los items marcados como conforme'),
              backgroundColor: Colors.green,
            ),
          );
        },
        icon: const Icon(Icons.done_all),
        label: const Text('Marcar todo conforme'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  // Modificar el ExpansionPanel para incluir el nuevo botón
  Widget _buildExpansionPanel(InspeccionList lista) {
    return ExpansionPanelList(
      children: [
        ExpansionPanel(
          headerBuilder: (context, isExpanded) => ListTile(
            title: Text(lista.name),
            subtitle: Text(
                '${_getCompletedItemsCount(lista.id)}/${_getTotalItemsCount(lista.id)} items completados'),
          ),
          body: Column(
            children: [
              _buildMarkAllConformeButton(lista.id),
              // ... resto del contenido del panel
            ],
          ),
          isExpanded: sectionChecks[lista.id] ?? false,
        ),
      ],
    );
  }

  // Agregar este método para cambiar el estado de todos los subItems de un item
  Widget _buildChangeStateButton(ChecklistItem item, int listaId) {
    CheckState currentState =
        subItemStates[listaId]?[item.subItems.first.id] ?? CheckState.conforme;
    String buttonText;
    Color buttonColor;

    switch (currentState) {
      case CheckState.conforme:
        buttonText = 'Cambiar a No Conforme';
        buttonColor = Colors.red;
        break;
      case CheckState.noConforme:
        buttonText = 'Cambiar a No Aplica';
        buttonColor = Colors.grey;
        break;
      case CheckState.noAplica:
        buttonText = 'Cambiar a Conforme';
        buttonColor = Colors.green;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton.icon(
        onPressed: () async {
          final db = LocalDatabase();
          setState(() {
            for (var subItem in item.subItems) {
              CheckState nextState;
              switch (currentState) {
                case CheckState.conforme:
                  nextState = CheckState.noConforme;
                  break;
                case CheckState.noConforme:
                  nextState = CheckState.noAplica;
                  break;
                case CheckState.noAplica:
                  nextState = CheckState.conforme;
                  break;
              }
              subItemStates[listaId]![subItem.id] = nextState;
              subItemChecks[listaId]![subItem.id] = true;

              // Guardar en DB
              db.changeEstado(
                subItem.id,
                _getEstadoString(nextState),
                widget.visit.id,
              );
            }
          });
        },
        icon: const Icon(Icons.change_circle_outlined),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  bool _canFinish() {
    return true; // Siempre permite finalizar
  }
}
