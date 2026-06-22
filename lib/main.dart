import 'package:flutter/material.dart';

void main() {
  runApp(const CircuitScannerPro());
}

class CircuitScannerPro extends StatelessWidget {
  const CircuitScannerPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Circuit Scanner PRO',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Circuit Scanner PRO')),
        body: const Center(
          child: Text('App funcionando 🚚'),
        ),
      ),
    );
  }
}
