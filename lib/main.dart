import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(240, 48),
          ),
        ),
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _photoBase64List = <String>[];
  final List<String> _audioPaths = <String>[];
  final TextEditingController _receiverNameController = TextEditingController();
  final RegExp _receiverNamePattern = RegExp(r'^[A-Za-z]+(?: [A-Za-z]+)*$');
  String? _lastQrText;
  String? _savedReceiverName;
  String? _currentAudioPath;
  bool _isRecording = false;
  bool _isAudioPlaying = false;

  static const double _sectionHeight = 280;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _receiverNameController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final String? path = await _audioRecorder.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = false;
        if (path != null) {
          _audioPaths.add(path);
        }
      });
      return;
    }

    final bool hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere permiso de micrófono para grabar audio.')),
      );
      return;
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String path = '${appDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _togglePlayPauseAudio(String path) async {
    if (_currentAudioPath == path) {
      if (_isAudioPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      return;
    }

    _currentAudioPath = path;
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
  }

  void _saveReceiverName() {
    final String name = _receiverNameController.text.trim();
    final bool isValid = _receiverNamePattern.hasMatch(name);
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nombre inválido. Usa solo letras y espacios, sin espacios al inicio o final.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _savedReceiverName = name;
      _receiverNameController.text = name;
    });
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: _sectionHeight,
                child: Card(
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Texto del QR escaneado:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(_lastQrText ?? 'Aún no se ha escaneado ningún código.'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 240,
                        child: FilledButton.icon(
                          onPressed: _openQrScanner,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear QR'),
                        ),
                      ),
                      if (_lastQrText != null) ...[
                        const SizedBox(height: 16),
                        QrImageView(
                          data: _lastQrText!,
                          size: 170,
                          backgroundColor: Colors.white,
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _sectionHeight,
                child: Card(
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        child: FilledButton.icon(
                          onPressed: _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tomar foto'),
                        ),
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
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _sectionHeight,
                child: Card(
                  child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 240,
                        child: FilledButton.icon(
                          onPressed: _toggleRecording,
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording ? 'Detener grabación' : 'Grabar audio'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_audioPaths.isNotEmpty)
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _audioPaths.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (BuildContext context, int index) {
                            return ListTile(
                              tileColor: Colors.grey.shade200,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              leading: const Icon(Icons.audiotrack),
                              title: Text('Audio ${index + 1}'),
                              subtitle: const Text('Grabación guardada'),
                              trailing: IconButton(
                                onPressed: () => _togglePlayPauseAudio(_audioPaths[index]),
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: Icon(
                                    _currentAudioPath == _audioPaths[index] && _isAudioPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    key: ValueKey<bool>(
                                      _currentAudioPath == _audioPaths[index] && _isAudioPlaying,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: _sectionHeight,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Nombre del receptor',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _receiverNameController,
                          enabled: _savedReceiverName == null,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Escribe el nombre',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _savedReceiverName == null ? _saveReceiverName : null,
                            icon: const Icon(Icons.check),
                            label: const Text('Guardar nombre'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _savedReceiverName == null
                              ? 'Aún no se ha guardado el nombre.'
                              : 'Nombre guardado: $_savedReceiverName',
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
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
