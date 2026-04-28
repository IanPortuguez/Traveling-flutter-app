import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traveling App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Traveling App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _photoBase64List = <String>[];
  String _lastQrText = 'Aún no se ha escaneado ningún código.';

  Future<void> _openQrScanner() async {
    final String? scannedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (scannedText == null || !mounted) {
      return;
    }

    setState(() {
      _lastQrText = scannedText;
    });
  }

  Future<void> _takePhoto() async {
    if (_photoBase64List.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes tomar un máximo de 10 fotos.'),
        ),
      );
      return;
    }

    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);

    if (photo == null || !mounted) {
      return;
    }

    final List<int> bytes = await photo.readAsBytes();
    final String encodedImage = base64Encode(bytes);

    setState(() {
      _photoBase64List.add(encodedImage);
    });
  }

  void _openPhotoPreview(String encodedImage) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoPreviewPage(encodedImage: encodedImage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Texto del QR escaneado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(_lastQrText),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear QR'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'QR generado con el texto escaneado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: QrImageView(
                          data: _lastQrText,
                          size: 170,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _lastQrText,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto (solo cámara)'),
              ),
              const SizedBox(height: 8),
              Text('Fotos tomadas: ${_photoBase64List.length}/10'),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: _photoBase64List.isEmpty
                    ? const Center(
                        child: Text('Todavía no has tomado fotos.'),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (BuildContext context, int index) {
                          final Uint8List decodedBytes = base64Decode(_photoBase64List[index]);
                          return GestureDetector(
                            onTap: () => _openPhotoPreview(_photoBase64List[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                decodedBytes,
                                width: 120,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemCount: _photoBase64List.length,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isHandlingScan = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isHandlingScan) {
      return;
    }

    final String? value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) {
      return;
    }

    _isHandlingScan = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escáner QR')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Apunta la cámara al código QR',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoPreviewPage extends StatelessWidget {
  const PhotoPreviewPage({super.key, required this.encodedImage});

  final String encodedImage;

  @override
  Widget build(BuildContext context) {
    final Uint8List decodedBytes = base64Decode(encodedImage);

    return Scaffold(
      appBar: AppBar(title: const Text('Vista de foto')),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(decodedBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
