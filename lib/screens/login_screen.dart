import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para el formateo del RUT
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart'; // Add this import
import 'package:jwt_decoder/jwt_decoder.dart';
import '../models/user_model.dart';
import '../models/visit_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../DB/LocalDB.dart';
import 'package:flutter/foundation.dart';
import '../models/repuesto_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rutController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isPasswordVisible = false;
  bool _hasConnection = true; // Add this to track connectivity status

  @override
  void initState() {
    super.initState();
    // Precargar credenciales
    _rutController.text = '';
    _passwordController.text = '';

    // Suscribirse a los cambios de conectividad
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (mounted) {
        setState(() {
          _hasConnection = result != ConnectivityResult.none;
        });
      }
    });

    // Verificar el estado inicial de conectividad
    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() {
          _hasConnection = result != ConnectivityResult.none;
        });
      }
    });
  }

  // Función para formatear el RUT mientras se escribe
  String _formatRut(String rut) {
    // Eliminar cualquier carácter que no sea número o 'k'
    rut = rut.replaceAll(RegExp(r'[^0-9kK]'), '');

    // Limitar la longitud total a 9 caracteres (8 números + 1 dígito verificador)
    if (rut.length > 9) {
      rut = rut.substring(0, 9);
    }

    if (rut.length > 1) {
      String dv = rut.substring(rut.length - 1);
      String numbers = rut.substring(0, rut.length - 1);
      String formatted = '';
      int count = 0;
      for (int i = numbers.length - 1; i >= 0; i--) {
        if (count == 3) {
          formatted = '.' + formatted;
          count = 0;
        }
        formatted = numbers[i] + formatted;
        count++;
      }
      return '$formatted-$dv';
    }
    return rut;
  }

  // Función para validar el RUT
  String? _validateRut(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su RUT';
    }

    // Eliminar puntos y guión para contar los dígitos
    String cleanRut = value.replaceAll(RegExp(r'[^0-9kK]'), '');

    if (cleanRut.length < 8 || cleanRut.length > 9) {
      return 'RUT inválido';
    }

    return null;
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Eliminar la base de datos existente para forzar recreación
        final db = LocalDatabase();

        print('Iniciando login...');
        String rut = _rutController.text.replaceAll(RegExp(r'[^0-9kK]'), '');
        String password = _passwordController.text;

        print('Llamando al API de login...');
        final responseData = await _apiService.post('auth/login_tecnico', {
          'rut': rut,
          'password': password,
        });

        print('Respuesta del API: $responseData');
        if (responseData == null) {
          throw Exception('No se recibió respuesta del servidor');
        }

        if (responseData['token'] == null) {
          throw Exception('No se recibió token en la respuesta');
        }

        print('Token recibido, guardando en SharedPreferences...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwtToken', responseData['token']);

        print('Decodificando token...');
        final decodedToken = JwtDecoder.decode(responseData['token']);
        final userData = UserModel.fromDecodedToken(decodedToken);
        print('Usuario decodificado: ${userData.name}');

        if (!kIsWeb) {
          try {
            print('Iniciando operaciones de DB local...');
            await db.database;

            print('Guardando usuario en DB local...');
            await db.insertUser(userData);

            print('Obteniendo solicitudes...');
            final data = await _apiService.get('solicitar-visita/tecnico/$rut');

            if (data != null && data is List && data.isNotEmpty) {
              // Imprimir detalladamente el local de la primera solicitud
              final primeraSolicitud = data[0];
              final local = primeraSolicitud['local'];
              print('\n=== DATOS DEL LOCAL ===');
              print(JsonEncoder.withIndent('  ').convert(local));
              print('=====================\n');

              for (var solicitud in data) {
                try {
                  final solicitudId = solicitud['id'];
                  final local = solicitud['local'];
                  if (local == null) {
                    print('Solicitud $solicitudId sin campo "local"');
                    continue;
                  }

                  final activos = local['activoFijoLocales'];
                  if (activos == null) {
                    print(
                        'Solicitud $solicitudId: campo "activoFijoLocales" nulo');
                  } else if (activos is List && activos.isNotEmpty) {
                    print(
                        'Solicitud $solicitudId: ${activos.length} activos fijos encontrados');
                    for (var af in activos) {
                      print('Activo fijo: ${jsonEncode(af)}');
                    }
                  } else {
                    print('Solicitud $solicitudId: sin activos fijos');
                  }

                  // Guardar toda la solicitud, incluso si no tiene activos
                  await db.insertSolicitud(jsonEncode(solicitud));
                } catch (e) {
                  print('Error al procesar solicitud: $e');
                }
              }
            } else {
              print('No se recibieron solicitudes o el formato es incorrecto');
            }
            print('Obteniendo repuestos...');
            final repuestosData = await _apiService.get('repuestos');
            if (repuestosData != null) {
              print('Repuestos obtenidos: ${repuestosData.length}');
              final repuestos = (repuestosData as List)
                  .map((json) => Repuesto.fromJson(json))
                  .toList();
              await db.subirListadoRepuestos(repuestos);
            }

            print('Obteniendo repuestos clima...');
            try {
              final repuestosClimaData =
                  await _apiService.get('repuestos/clima');
              if (repuestosClimaData != null) {
                print(
                    'Repuestos clima obtenidos: ${repuestosClimaData.length}');
                final repuestosClima = (repuestosClimaData as List)
                    .map((json) => Repuesto.fromJson(json))
                    .toList();
                await db.subirListadoRepuestosClima(repuestosClima);
              }
            } catch (e) {
              print('Error al obtener repuestos clima (no crítico): $e');
              // Continuar con el flujo normal aunque falle repuestos-clima
            }
          } catch (dbError) {
            print('Error con DB local: $dbError');
          }
        }

        print('Navegando al HomeScreen...');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userData: userData),
            ),
          );
        }
      } catch (e, stackTrace) {
        print('Error en login: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getErrorMessage(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Failed to fetch')) {
      return 'No se pudo conectar con el servidor. Por favor, verifica tu conexión a internet.';
    } else if (error.contains('401')) {
      return 'RUT o contraseña incorrectos';
    } else if (error.contains('404')) {
      return 'Usuario no encontrado';
    } else if (error.contains('500')) {
      return 'Error en el servidor. Por favor, intenta más tarde.';
    }
    return 'Ha ocurrido un error';
  }

  Future<void> _handleOfflineLogin() async {
    if (_formKey.currentState!.validate()) {
      String rut = _rutController.text.replaceAll(RegExp(r'[^0-9kK]'), '');
      if (mounted) {
        final userData = UserModel(
          id: 0,
          rut: rut,
          email: 'usuario@offline.com',
          name: 'Usuario Offline',
          especialidades: [],
          profile: 'offline',
          clients: [],
          isOffline: true,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: userData),
          ),
        );
      }
    }
  }

  Widget _buildConnectionBanner() {
    if (_hasConnection) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Sin conexión a internet trabajara localmente',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: _hasConnection ? _handleLogin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F3FFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'INICIAR SESIÓN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (!_hasConnection) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _handleOfflineLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'INGRESAR OFFLINE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF3F3FFF),
        child: SafeArea(
          child: Column(
            children: [
              _buildConnectionBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center, // Centrar verticalmente
                      children: [
                        // Card del formulario
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo dentro de la card
                              Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  height: 80,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _rutController,
                                decoration: InputDecoration(
                                  labelText: 'Rut',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                keyboardType: TextInputType.text,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(12),
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9kK\.-]')),
                                ],
                                onChanged: (value) {
                                  final formatted = _formatRut(value);
                                  if (formatted != value) {
                                    _rutController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(
                                          offset: formatted.length),
                                    );
                                  }
                                },
                                validator: _validateRut,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingrese su contraseña';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              _buildLoginButtons(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Ya no necesitamos cerrar el cron
    // cron.close();
    _rutController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
