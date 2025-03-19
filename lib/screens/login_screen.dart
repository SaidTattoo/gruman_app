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
      String rut = _rutController.text.replaceAll(RegExp(r'[^0-9kK]'), '');
      String password = _passwordController.text;

      try {
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
            SnackBar(content: Text('Error: ${e.toString()}')),
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
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                                12), // Limita la longitud incluyendo puntos y guión
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
}
