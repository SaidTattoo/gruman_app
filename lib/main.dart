import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/splash_screen.dart';
import 'widgets/connectivity_wrapper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'DB/LocalDB.dart';

Future<void> initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (!kIsWeb) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await LocalDatabase().database;
    }
  } catch (e) {
    debugPrint('Error inicializando la base de datos: $e');
  }
}

void main() async {
  try {
    await initializeApp();

    runApp(
      ConnectivityWrapper(
        child: MaterialApp(
          title: 'Atlantis',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFF3F3FFF),
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3F3FFF),
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  } catch (e) {
    debugPrint('Error iniciando la aplicación: $e');
    // Asegurar que la app inicie incluso si hay errores
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error iniciando la aplicación: $e'),
          ),
        ),
      ),
    );
  }
}
