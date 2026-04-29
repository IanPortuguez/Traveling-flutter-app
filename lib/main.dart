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
  final List<Uint8List> _photoBytesList = <Uint8List>[];
  final List<String> _audioPaths = <String>[];
  final List<String> _notes = <String>[];
  final TextEditingController _receiverNameController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? _lastQrText;
  String? _savedReceiverName;
  String? _currentAudioPath;
  bool _isRecording = false;
  bool _isAudioPlaying = false;

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
    _noteController.dispose();
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
    if (_photoBytesList.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo puedes tomar un máximo de 10 fotos.'),
        ),
      );
      return;
    }

    final XFile? photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1280,
    );

    if (photo == null || !mounted) {
      return;
    }

    final Uint8List bytes = await photo.readAsBytes();

    setState(() {
      _photoBytesList.add(bytes);
    });
  }

  void _openPhotoPreview(Uint8List photoBytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoPreviewPage(photoBytes: photoBytes),
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
    final bool isValid = name.isNotEmpty && name.length <= 50;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nombre inválido. Debe tener entre 1 y 50 caracteres.',
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

  Future<void> _showAddNoteDialog() async {
    _noteController.clear();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Añadir nota'),
          content: TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Escribe tu nota',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final String note = _noteController.text.trim();
                if (note.isEmpty) {
                  return;
                }
                setState(() {
                  _notes.add(note);
                });
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _actionPanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color background = const Color(0xFFE9E7EF),
    Color foreground = const Color(0xFF665A94),
  }) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090812),
        foregroundColor: Colors.white,
        title: const Text('Almacén 3R manager'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              'https://images.unsplash.com/photo-1565793298595-6a879b1d9492?auto=format&fit=crop&w=800&q=60',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _pillButton(
                  icon: Icons.route,
                  label: 'INICIAR RUTA',
                  onPressed: () {},
                  background: const Color(0xFF6DB560),
                  foreground: Colors.white,
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nombre del Receptor(a):',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _receiverNameController,
                        enabled: _savedReceiverName == null,
                        decoration: InputDecoration(
                          hintText: 'Mínimo 1 carácter, Máximo 50.',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _pillButton(
                        icon: Icons.check_circle_outline,
                        label: _savedReceiverName == null ? 'Guardar Nombre' : 'Nombre guardado',
                        onPressed: _savedReceiverName == null ? _saveReceiverName : null,
                        background: const Color(0xFF439B2A),
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pillButton(
                        icon: Icons.qr_code_scanner,
                        label: 'Escanear QR',
                        onPressed: _openQrScanner,
                      ),
                      if (_lastQrText != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: QrImageView(
                            data: _lastQrText!,
                            size: 160,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _lastQrText!,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pillButton(
                        icon: Icons.camera_alt,
                        label: 'Tomar Foto (${_photoBytesList.length}/10)',
                        onPressed: _takePhoto,
                      ),
                      if (_photoBytesList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photoBytesList.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (BuildContext context, int index) {
                              return GestureDetector(
                                onTap: () => _openPhotoPreview(_photoBytesList[index]),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _photoBytesList[index],
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    cacheWidth: 180,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pillButton(
                        icon: Icons.note_add,
                        label: 'Añadir Nota',
                        onPressed: _showAddNoteDialog,
                      ),
                      if (_notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._notes.asMap().entries.map(
                          (MapEntry<int, String> entry) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.sticky_note_2_outlined),
                              title: Text('Nota ${entry.key + 1}'),
                              subtitle: Text(
                                entry.value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => NotePreviewPage(noteText: entry.value),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _pillButton(
                        icon: Icons.mic,
                        label: _isRecording ? 'Detener Audio' : 'Grabar Audio',
                        onPressed: _toggleRecording,
                      ),
                      if (_audioPaths.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._audioPaths.asMap().entries.map(
                          (MapEntry<int, String> entry) => Card(
                            child: ListTile(
                              leading: Icon(
                                _currentAudioPath == entry.value && _isAudioPlaying
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                              title: Text('Audio ${entry.key + 1}'),
                              onTap: () => _togglePlayPauseAudio(entry.value),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
  const PhotoPreviewPage({super.key, required this.photoBytes});

  final Uint8List photoBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista de foto')),
      body: Center(
        child: InteractiveViewer(
          child: Image.memory(photoBytes, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class NotePreviewPage extends StatelessWidget {
  const NotePreviewPage({super.key, required this.noteText});

  final String noteText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista de nota')),
      body: Center(
        child: InteractiveViewer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              noteText,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }
}
