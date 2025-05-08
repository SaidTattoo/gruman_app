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
        // Limpia el RUT y lo convierte a mayúsculas
        String rut = _rutController.text
            .replaceAll('.', '')
            .replaceAll('-', '')
            .toUpperCase();
        String password = _passwordController.text;

        final responseData = await _apiService.post('auth/login_tecnico', {
          'rut': rut,
          'password': password,
        });

        if (responseData['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwtToken', responseData['token']);
          final decodedToken = JwtDecoder.decode(responseData['token']);

          if (mounted) {
            final userData = UserModel.fromDecodedToken(decodedToken);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(userData: userData),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de inicio de sesión: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: const Color(0xFF3F3FFF),
        child: SafeArea(
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
                            labelText: 'RUT',
                            hintText: 'Ej: 19185237-K',
                            prefixIcon: Icon(Icons.person_outline),
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
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9kK-]')),
                            LengthLimitingTextInputFormatter(10),
                            RutFormatter(),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingrese su RUT';
                            }
                            if (value.length >= 9 && !isValidRut(value)) {
                              return 'RUT inválido';
                            }
                            return null;
                          },
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
                                  _isPasswordVisible = !_isPasswordVisible;
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
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rutController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool isValidRut(String rut) {
    try {
      // Limpia el RUT y convierte a mayúsculas
      rut = rut.replaceAll('.', '').toUpperCase();

      // Verifica que el RUT tenga un guión
      if (!rut.contains('-')) {
        return false;
      }

      List<String> rutParts = rut.split('-');
      if (rutParts.length != 2) {
        return false;
      }

      String number = rutParts[0];
      String dv = rutParts[1];

      // Verifica que el número sea válido y el DV sea un número o K
      if (!RegExp(r'^[0-9]{7,8}$').hasMatch(number) ||
          !RegExp(r'^[0-9K]$').hasMatch(dv)) {
        return false;
      }

      // Algoritmo para calcular dígito verificador
      int sum = 0;
      int multiplier = 2;

      // Iteramos de derecha a izquierda
      for (int i = number.length - 1; i >= 0; i--) {
        sum += int.parse(number[i]) * multiplier;
        multiplier = multiplier == 7 ? 2 : multiplier + 1;
      }

      int remainder = sum % 11;
      String expectedDv = (11 - remainder).toString();

      // Manejo de casos especiales
      if (expectedDv == '11') expectedDv = '0';
      if (expectedDv == '10') expectedDv = 'K';

      // Comparación case-insensitive para K
      return dv.toUpperCase() == expectedDv;
    } catch (e) {
      return false; // Si hay cualquier error en el proceso, el RUT es inválido
    }
  }
}

// Add this formatter to automatically format the RUT
class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.toUpperCase(); // Convertir a mayúsculas

    // Remover cualquier guión existente
    text = text.replaceAll('-', '');

    // Si la longitud es 0 o 1, retornar el texto tal cual
    if (text.length <= 1)
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

    // Insertar el guión antes del último carácter
    final withDash = text.substring(0, text.length - 1) +
        '-' +
        text.substring(text.length - 1);

    return TextEditingValue(
      text: withDash,
      selection: TextSelection.collapsed(offset: withDash.length),
    );
  }
}
