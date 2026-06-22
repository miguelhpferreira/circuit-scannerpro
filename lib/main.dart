import 'package:flutter/material.dart';

void main() {
  runApp(const CircuitScannerPro());
}

class CircuitScannerPro extends StatelessWidget {
  const CircuitScannerPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Circuit Scanner PRO',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Circuit Scanner PRO'),
        ),
        body: const Center(
          child: Text(
            'Aplicativo em construção 🚚',
            style: TextStyle(fontSize: 22),
          ),
        ),
      ),
    );
  }
}
