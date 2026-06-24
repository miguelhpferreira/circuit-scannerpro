import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class Delivery {
  final String nome;
  final String endereco;
  final String cidade;
  final String estado;
  final String cep;
  final String qr;

  Delivery({
    required this.nome,
    required this.endereco,
    required this.cidade,
    required this.estado,
    required this.cep,
    required this.qr,
  });

  String get enderecoCompleto => '$endereco, $cidade - $estado, $cep';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();

  final textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  final barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );

  final List<Delivery> entregas = [];
  bool carregando = false;

  Future<void> escanearEtiqueta() async {
    final foto = await picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() => carregando = true);

    final input = InputImage.fromFile(File(foto.path));

    final qrCodes = await barcodeScanner.processImage(input);
    final textoReconhecido = await textRecognizer.processImage(input);

    String qrText = '';
    if (qrCodes.isNotEmpty) {
      qrText = qrCodes.first.rawValue ?? '';
    }

    final entrega = extrairEntrega(textoReconhecido, qrText);

    setState(() {
      entregas.add(entrega);
      carregando = false;
    });
  }

  Delivery extrairEntrega(RecognizedText recognizedText, String qr) {
  final todasLinhas = recognizedText.blocks
      .expand((b) => b.lines)
      .map((l) => l.text.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final texto = todasLinhas.join('\n');

  final ceps = RegExp(r'\b\d{5}-?\d{3}\b')
      .allMatches(texto)
      .map((m) => m.group(0)!.replaceAll('-', ''))
      .toList();

  String cep = '';
  if (ceps.isNotEmpty) {
    cep = ceps.last;
    cep = '${cep.substring(0, 5)}-${cep.substring(5)}';
  }

  int inicio = -1;
  int fim = todasLinhas.length;

  for (int i = 0; i < todasLinhas.length; i++) {
    final l = todasLinhas[i].toLowerCase();

    if (l == 'to' || l.contains(' to ') || l.startsWith('to ')) {
      inicio = i + 1;
      break;
    }
  }

  if (inicio == -1) {
    for (int i = 0; i < todasLinhas.length; i++) {
      final l = todasLinhas[i].toLowerCase();
      if (l.contains('remetente')) {
        inicio = i + 4;
        break;
      }
    }
  }

  if (inicio == -1) inicio = 0;

  for (int i = inicio; i < todasLinhas.length; i++) {
    final l = todasLinhas[i].toLowerCase();

    if (l.contains('tiktok') ||
        l.contains('shop') ||
        l.contains('qntd') ||
        l.contains('peso') ||
        l.contains('site') ||
        l.contains('sku') ||
        l.contains('deadline') ||
        l.contains('pick up') ||
        l.contains('d2d')) {
      fim = i;
      break;
    }
  }

  final blocoDestino = todasLinhas.sublist(inicio, fim);

  final ignorar = [
    'imile',
    'delivery',
    'remetente',
    'data de envio',
    'nº de ref',
    'hot',
    'sp2',
    'barcode',
    'tracking',
    'order',
    'express',
    'cod',
    'kg',
  ];

  final linhas = blocoDestino.where((linha) {
    final l = linha.toLowerCase();

    for (final item in ignorar) {
      if (l.contains(item)) return false;
    }

    if (RegExp(r'^\d{6,}$').hasMatch(linha)) return false;
    if (RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(linha)) return false;

    return true;
  }).toList();

  String nome = linhas.isNotEmpty ? linhas.first : 'Sem nome';

  String cidade = '';
  String estado = 'SP';

  final lower = texto.toLowerCase();

  if (lower.contains('hortolândia')) {
    cidade = 'Hortolândia';
  } else if (lower.contains('campinas')) {
    cidade = 'Campinas';
  } else if (lower.contains('sumaré')) {
    cidade = 'Sumaré';
  } else if (lower.contains('monte mor')) {
    cidade = 'Monte Mor';
  } else if (lower.contains('paulínia')) {
    cidade = 'Paulínia';
  }

  final enderecoLinhas = linhas.where((e) => e != nome).toList();

  String endereco = enderecoLinhas.join(', ');

  endereco = endereco
      .replaceAll(RegExp(r'\b\d{5}-?\d{3}\b'), '')
      .replaceAll('Hortolândia', '')
      .replaceAll('São Paulo', '')
      .replaceAll('Sao Paulo', '')
      .replaceAll('SP', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r',\s*,'), ',')
      .trim();

  if (endereco.endsWith(',')) {
    endereco = endereco.substring(0, endereco.length - 1).trim();
  }

  return Delivery(
    nome: nome,
    endereco: endereco,
    cidade: cidade,
    estado: estado,
    cep: cep,
    qr: qr,
  );
}

  Future<void> gerarCsv() async {
    if (entregas.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/circuit_scanner_pro.csv');

    final buffer = StringBuffer();
    buffer.writeln('name,address,city,state,postal_code');

    for (final e in entregas) {
      buffer.writeln(
        '"${e.nome}","${e.endereco}","${e.cidade}","${e.estado}","${e.cep}"',
      );
    }

    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'CSV para importar no Circuit',
    );
  }

  Future<void> abrirNoMaps(Delivery entrega) async {
    final query = Uri.encodeComponent(entrega.enderecoCompleto);
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void limparLista() {
    setState(() => entregas.clear());
  }

  @override
  void dispose() {
    textRecognizer.close();
    barcodeScanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Circuit Scanner PRO'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Pacotes escaneados: ${entregas.length}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: carregando ? null : escanearEtiqueta,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(
                  carregando
                      ? 'Lendo etiqueta...'
                      : 'Escanear etiqueta / QR Code',
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: entregas.isEmpty ? null : gerarCsv,
                icon: const Icon(Icons.file_download),
                label: const Text('Gerar CSV para Circuit'),
              ),
            ),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: entregas.isEmpty ? null : limparLista,
                icon: const Icon(Icons.delete),
                label: const Text('Limpar lista'),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: entregas.isEmpty
                  ? const Center(
                      child: Text('Nenhuma etiqueta escaneada ainda.'),
                    )
                  : ListView.builder(
                      itemCount: entregas.length,
                      itemBuilder: (context, index) {
                        final e = entregas[index];

                        return Card(
                          child: ListTile(
                            title: Text(e.nome),
                            subtitle: Text(
                              '${e.endereco}\n${e.cidade} - ${e.estado}\nCEP: ${e.cep}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () => abrirNoMaps(e),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}