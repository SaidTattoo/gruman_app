import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'visit_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/vehicle_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pdf_viewer_screen.dart';
import '../models/visit_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/api_service.dart';
import '../DB/LocalDB.dart';

class HomeScreen extends StatefulWidget {
  final UserModel userData;

  const HomeScreen({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;
  bool _isSyncing = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Verificar si userData es null
    if (widget.userData == null) {
      print('ERROR: userData es null');
    } else {
      print('userData contiene: ${widget.userData}');
    }

    _screens = [
      ProfileScreen(
          userData: widget.userData ??
              UserModel(
                  id: 0,
                  email: '',
                  name: '',
                  rut: '',
                  especialidades: [],
                  profile: '',
                  clients: [])),
      const VisitsScreen(),
      const ExitScreen(),
    ];

    _saveToken();
  }

  Future<void> _saveToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await prefs.getString('jwtToken');
      print('Token en HomeScreen: ${token?.substring(0, 20) ?? "null"}');
    } catch (e) {
      print('Error al recuperar token en HomeScreen: $e');
    }
  }

  void _onItemTapped(int index) async {
    if (index == 2) {
      // Índice del botón de sincronización
      await _syncData();
    } else if (index == 3) {
      // Índice del botón salir
      _showLogoutDialog();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        'Building HomeScreen with userData: ${widget.userData}'); // Debug print
    if (_screens.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ATLANTIS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5, // Espaciado entre letras para mejor legibilidad
          ),
        ),
        backgroundColor: const Color(0xFF3F3FFF),
        centerTitle: true, // Centra el título
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Solicitudes',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.sync),
                if (_isSyncing)
                  const Positioned(
                    right: 0,
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Sincronizar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Salir',
          ),
        ],
      ),
    );
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwtToken');
      if (token == null) throw Exception('No hay token de autenticación');

      final decodedToken = JwtDecoder.decode(token);
      final tecnicoRut = decodedToken['rut'];

      // Eliminar todas las solicitudes existentes
      final db = LocalDatabase();
      await db.deleteAllSolicitudes();
      print('Solicitudes eliminadas de DB local');

      // Esperar un momento para asegurar que la DB está limpia
      await Future.delayed(const Duration(milliseconds: 500));

      // Obtener datos nuevos del API
      final data =
          await _apiService.get('solicitar-visita/tecnico/$tecnicoRut');
      print('Nuevos datos obtenidos del API: ${data.length} solicitudes');

      // Guardar nuevos datos en DB local
      for (var solicitud in data) {
        await db.insertSolicitud(jsonEncode(solicitud));
      }
      print('Nuevas solicitudes guardadas en DB local');

      // Recargar la vista de solicitudes
      if (_selectedIndex == 1) {
        setState(() {
          _screens[1] = const VisitsScreen();
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronización completada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error en sincronización: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al sincronizar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro que deseas salir?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final UserModel userData;

  const ProfileScreen({
    Key? key,
    required this.userData,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  VehicleModel? vehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final data = await _apiService
          .get('users/tecnicos/${widget.userData.id}/vehiculo-actual');

      if (data['vehiculo'] != null) {
        setState(() {
          vehicle = VehicleModel.fromJson(data['vehiculo']);
        });
      }
    } catch (e) {
      print('Error cargando vehículo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header más compacto
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF3F3FFF),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userData.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.engineering,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.userData.especialidades.first.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contenido Principal
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Información Personal
                _buildCard(
                  title: 'Información Personal',
                  icon: Icons.person_outline,
                  content: Column(
                    children: [
                      _buildInfoRow(Icons.badge, 'RUT: ${widget.userData.rut}'),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          Icons.email, 'Email: ${widget.userData.email}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Especialidades
                _buildCard(
                  title: 'Especialidades',
                  icon: Icons.engineering_outlined,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.userData.especialidades
                        .map((esp) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('• ${esp.nombre}'),
                            ))
                        .toList(),
                  ),
                ),
                // Sección de vehículo
                const SizedBox(height: 24),
                const Text(
                  'Vehículo Asignado',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (vehicle == null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange[800]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No tiene vehículo asignado',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    title: 'Vehículo Asignado',
                    icon: Icons.directions_car_outlined,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                            Icons.local_taxi, 'Móvil: ${vehicle!.movil}'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.confirmation_number,
                            'Patente: ${vehicle!.patente}'),
                        // ... resto del código del vehículo ...
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF3F3FFF), size: 26),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF3F3FFF)),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentRow(DocumentoVehiculo doc) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerScreen(
              url: doc.path,
              title: doc.nombre,
            ),
          ),
        );
      },
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: Color(0xFF3F3FFF),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.nombre,
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Fecha: ${_formatDate(doc.fecha)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (doc.fechaVencimiento != null)
                  Text(
                    'Vence: ${_formatDate(doc.fechaVencimiento!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isExpired(doc.fechaVencimiento!)
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.open_in_new,
            color: Colors.grey[400],
            size: 16,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isExpired(DateTime date) {
    return date.isBefore(DateTime.now());
  }
}

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

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterVisits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredVisits =
            List.from(visits); // Crear una nueva lista con todos los elementos
      } else {
        filteredVisits = visits.where((visit) {
          final ticketMatch = visit.id.toString().toLowerCase().contains(query);
          final clientMatch =
              visit.client['nombre'].toString().toLowerCase().contains(query);
          final localMatch =
              visit.local.nombreLocal.toLowerCase().contains(query);
          return ticketMatch || clientMatch || localMatch;
        }).toList();
      }
    });
  }

  Future<void> _loadVisits() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      print('Iniciando carga de visitas...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwtToken');

      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      final decodedToken = JwtDecoder.decode(token);
      final tecnicoRut = decodedToken['rut'];

      List<Visit> localVisits = [];
      try {
        print('Obteniendo solicitudes de DB local...');
        final db = LocalDatabase();
        final solicitudesJson = await db.getSolicitudes();
        print('Solicitudes de DB local: ${solicitudesJson.length}');

        localVisits =
            solicitudesJson.map((json) => Visit.fromJson(json)).toList();
        print('Visitas parseadas de DB local: ${localVisits.length}');
      } catch (dbError) {
        print('Error leyendo DB local: $dbError');
      }

      // Si hay visitas locales, usarlas
      if (localVisits.isNotEmpty) {
        if (mounted) {
          setState(() {
            visits = localVisits;
            filteredVisits = visits;
            isLoading = false;
          });
        }
        return;
      }

      // Si no hay visitas locales, obtener del API
      print('Obteniendo datos del API...');
      final data =
          await _apiService.get('solicitar-visita/tecnico/$tecnicoRut');

      if (mounted) {
        setState(() {
          visits = (data as List).map((json) => Visit.fromJson(json)).toList();
          filteredVisits = visits;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error cargando visitas: $e');
      if (mounted) {
        setState(() {
          visits = [];
          filteredVisits = [];
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _filterVisits(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por ticket, cliente o local...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterVisits();
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredVisits.isEmpty // Usar lista filtrada
                  ? const Center(child: Text('No se encontraron visitas'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _loadVisits();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredVisits.length,
                        itemBuilder: (context, index) {
                          final visit = filteredVisits[index];
                          return Dismissible(
                            key: Key(visit.id.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child:
                                  const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Confirmar eliminación'),
                                    content: const Text(
                                        '¿Estás seguro de eliminar esta solicitud?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            onDismissed: (direction) async {
                              try {
                                await LocalDatabase().deleteSolicitud(visit.id);
                                // Recargar las visitas después de eliminar
                                await _loadVisits();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Solicitud ${visit.id} eliminada'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error al eliminar: $e');
                                // Recargar las visitas incluso si hay error
                                await _loadVisits();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Error al eliminar la solicitud'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          VisitDetailScreen(visit: visit),
                                    ),
                                  ).then((_) {
                                    // Recargar la lista de visitas cuando regresamos
                                    _loadVisits();
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Numero de requerimiento: ${visit.id}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                visit.local.nombreLocal,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${visit.client['nombre']}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          _buildStatusChip(visit.status ?? ''),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              visit.local.direccion,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.directions_car,
                                                  color: Color(0xFF3F3FFF),
                                                  size: 24,
                                                ),
                                                onPressed: () => _openInWaze(
                                                    visit.local.direccion),
                                                tooltip: 'Abrir en Waze',
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.map,
                                                  color: Color(0xFF3F3FFF),
                                                  size: 24,
                                                ),
                                                onPressed: () =>
                                                    _openInGoogleMaps(
                                                        visit.local.direccion),
                                                tooltip: 'Abrir en Google Maps',
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          /*  _buildInfoChip(
                                            Icons.calendar_today,
                                            _formatDate(visit.fechaVisita ??
                                                DateTime.now()),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildInfoChip(
                                            Icons.access_time,
                                            _formatTime(visit.fechaVisita ??
                                                DateTime.now()),
                                          ), */
                                          const SizedBox(width: 8),
                                          _buildInfoChip(
                                            Icons.engineering,
                                            visit.tipoMantenimiento ?? '',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = 'Pendiente';
        icon = Icons.schedule;
        break;
      case 'en_servicio':
        color = Colors.blue;
        text = 'En Servicio';
        icon = Icons.engineering;
        break;
      case 'in_progress':
        color = Colors.blue;
        text = 'En Proceso';
        icon = Icons.engineering;
        break;
      case 'completed':
        color = Colors.green;
        text = 'Completada';
        icon = Icons.check_circle;
        break;
      case 'finalizado':
        color = Colors.green;
        text = 'Finalizado';
        icon = Icons.check_circle;
        break;
      default:
        color = Colors.grey;
        text = status.replaceAll('_', ' ').toUpperCase();
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _openInWaze(String address) async {
    final url = 'waze://?q=$address&navigate=yes';
    final fallbackUrl = 'https://waze.com/ul?q=$address&navigate=yes';

    try {
      final Uri wazeUri = Uri.parse(url);
      if (await canLaunchUrl(wazeUri)) {
        await launchUrl(wazeUri);
      } else {
        final Uri fallbackUri = Uri.parse(fallbackUrl);
        await launchUrl(fallbackUri);
      }
    } catch (e) {
      print('Error al abrir Waze: $e');
    }
  }

  void _openInGoogleMaps(String address) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';

    try {
      final Uri mapsUri = Uri.parse(url);
      await launchUrl(mapsUri);
    } catch (e) {
      print('Error al abrir Google Maps: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class ExitScreen extends StatelessWidget {
  const ExitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Pantalla de Salir'),
    );
  }
}
