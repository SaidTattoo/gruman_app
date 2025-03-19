import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import '../models/user_model.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken');

    await Future.delayed(
        const Duration(seconds: 2)); // Mostrar splash por 2 segundos

    if (mounted) {
      if (token != null && !JwtDecoder.isExpired(token)) {
        final decodedToken = JwtDecoder.decode(token);
        final userData = UserModel.fromDecodedToken(decodedToken);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => HomeScreen(userData: userData)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 200, // Ajusta el tamaño según necesites
        ),
      ),
    );
  }
}
