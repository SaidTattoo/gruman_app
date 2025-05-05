import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _hasConnection = true;

  bool get hasConnection => _hasConnection;

  ConnectivityProvider() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _hasConnection = result != ConnectivityResult.none;
      notifyListeners();
    });
  }
}
