import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

  Delivery({
    required this.nome,
    required this.endereco,
    required this.cidade,
    required this.estado,
    required this.cep,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker picker = ImagePicker();
  final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final List<Delivery> entregas = [];
  bool carregando = false;

  Future<void> escanearEtiqueta() async {
    final XFile? foto = await picker.pickImage(source: ImageSource.camera);

    if (foto == null) return;

    setState(() => carregando = true);

    final inputImage = InputImage.fromFile(File(foto.path));
    final recognizedText = await recognizer.processImage(inputImage);

    final entrega = extrairEntrega(recognizedText.text);

    setState(() {
      entregas.add(entrega);
      carregando = false;
    });
  }

  Delivery extrairEntrega(String texto) {
    final linhas = texto
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final cepRegex = RegExp(r'\d{5}-\d{3}');
    final cep = cepRegex.firstMatch(texto)?.group(0) ?? '';

    String cidade = '';
    String estado = 'SP';

    if (texto.toLowerCase().contains('hortolândia')) {
      cidade = 'Hortolândia';
    }

    String nome = linhas.isNotEmpty ? linhas.first : 'Sem nome';

    String endereco = '';

    for (final linha in linhas) {
      final l = linha.toLowerCase();

      if (l.contains('rua') ||
          l.contains('avenida') ||
          l.contains('av.') ||
          l.contains('travessa') ||
          l.contains('estrada')) {
        endereco = linha;
        break;
      }
    }

    if (endereco.isEmpty && linhas.length > 1) {
      endereco = linhas.skip(1).join(' ');
    }

    return Delivery(
      nome: nome,
      endereco: endereco,
      cidade: cidade,
      estado: estado,
      cep: cep,
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

  void limparLista() {
    setState(() => entregas.clear());
  }

  @override
  void dispose() {
    recognizer.close();
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: carregando ? null : escanearEtiqueta,
                icon: const Icon(Icons.camera_alt),
                label: Text(carregando ? 'Lendo etiqueta...' : 'Escanear etiqueta'),
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
