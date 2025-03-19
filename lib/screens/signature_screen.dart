import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:ui' as ui;
import 'dart:convert';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({Key? key}) : super(key: key);

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Firma del Cliente',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3F3FFF),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Por favor, firme para confirmar la inspección',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              height: 200, // Altura reducida
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () {
                    _controller.clear();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    if (_controller.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, firme antes de continuar'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    final signature = await _controller.toPngBytes();
                    if (signature != null) {
                      final String base64Signature =
                          'data:image/png;base64,${base64Encode(signature)}';
                      if (context.mounted) {
                        Navigator.pop(context, base64Signature);
                      }
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3F3FFF),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
