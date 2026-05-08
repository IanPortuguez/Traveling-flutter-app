import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:record/record.dart';

import '../models/captures.dart';
import 'note_preview_page.dart';
import 'photo_preview_page.dart';
import 'qr_scanner_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.transportistaName});

  final String title;
  final String transportistaName;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<PhotoCapture> _photoCaptures = <PhotoCapture>[];
  final List<AudioCapture> _audioCaptures = <AudioCapture>[];
  final List<NoteCapture> _noteCaptures = <NoteCapture>[];
  final List<QrCapture> _qrCaptures = <QrCapture>[];
  final List<CaptureMetadata> _routePoints = <CaptureMetadata>[];
  final TextEditingController _receiverNameController = TextEditingController();
  final List<DeliveryRecord> _deliveryRecords = <DeliveryRecord>[];
  final TextEditingController _noteController = TextEditingController();
  QrCapture? _lastQrCapture;
  String? _savedReceiverName;
  String? _currentAudioPath;
  bool _isRecording = false;
  bool _isAudioPlaying = false;
  bool _isRouteTracking = false;
  bool _routeStartedOnce = false;
  bool _routeCompleted = false;
  Timer? _routeTimer;
  Duration _currentAudioDuration = Duration.zero;
  Duration _currentAudioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedDeliveries());
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
        if (state == PlayerState.stopped || state == PlayerState.completed) {
          _currentAudioPosition = Duration.zero;
        }
      });
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAudioDuration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentAudioPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _receiverNameController.dispose();
    _noteController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<CaptureMetadata?> _captureMetadata() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final Position position = await Geolocator.getCurrentPosition();
    return CaptureMetadata(
      capturedAt: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<void> _openQrScanner() async {
    final String? scannedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );

    if (scannedText == null || !mounted) {
      return;
    }

    final CaptureMetadata? metadata = await _captureMetadata();
    if (!mounted) {
      return;
    }

    final QrCapture capture = QrCapture(
      value: scannedText,
      metadata: metadata ??
          CaptureMetadata(capturedAt: DateTime.now(), latitude: 0, longitude: 0),
    );

    setState(() {
      _lastQrCapture = capture;
      _qrCaptures.add(capture);
    });
  }

  Future<void> _takePhoto() async {
    if (_photoCaptures.length >= 10) {
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
    final CaptureMetadata? metadata = await _captureMetadata();

    if (!mounted) {
      return;
    }

    setState(() {
      _photoCaptures.add(
        PhotoCapture(
          bytes: bytes,
          metadata: metadata ??
              CaptureMetadata(capturedAt: DateTime.now(), latitude: 0, longitude: 0),
        ),
      );
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
      final CaptureMetadata? metadata = await _captureMetadata();
      if (!mounted) {
        return;
      }
      Uint8List? audioBytes;
      if (path != null) {
        final File audioFile = File(path);
        if (await audioFile.exists()) {
          audioBytes = await audioFile.readAsBytes();
        }
      }
      setState(() {
        _isRecording = false;
        if (audioBytes != null) {
          _audioCaptures.add(
            AudioCapture(
              bytes: audioBytes,
              metadata: metadata ??
                  CaptureMetadata(capturedAt: DateTime.now(), latitude: 0, longitude: 0),
            ),
          );
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
    _currentAudioDuration = Duration.zero;
    _currentAudioPosition = Duration.zero;
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(path));
  }

  Future<void> _seekAudio(double value) async {
    if (_currentAudioPath == null) {
      return;
    }
    await _audioPlayer.seek(Duration(milliseconds: value.round()));
  }

  Future<void> _confirmStopRoute() async {
    final bool? shouldStop = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('¿Detener ruta?'),
          content: const Text(
            '¿En verdad deseas detener la ruta? No se va a poder retomar para este pedido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    if (shouldStop != true || !mounted) {
      return;
    }

    _routeTimer?.cancel();
    setState(() {
      _isRouteTracking = false;
      _routeCompleted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ruta detenida y almacenada internamente.')),
    );
  }

  Future<void> _loadSavedDeliveries() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String filePath = '${appDir.path}/entregas_guardadas.json';
    final File file = File(filePath);

    if (!await file.exists()) {
      return;
    }

    final String content = await file.readAsString();
    if (content.trim().isEmpty) {
      return;
    }

    final dynamic decoded = jsonDecode(content);
    if (decoded is! List<dynamic>) {
      return;
    }

    final List<DeliveryRecord> loadedRecords = decoded
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) {
          final String qrTitle = (item['qrTitle'] as String?) ?? 'SIN_QR';
          final String? savedAtRaw = item['savedAt'] as String?;
          final DateTime savedAt = DateTime.tryParse(savedAtRaw ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return DeliveryRecord(savedAt: savedAt, qrTitle: qrTitle, filePath: filePath);
        })
        .toList()
      ..sort((DeliveryRecord a, DeliveryRecord b) => b.savedAt.compareTo(a.savedAt));

    if (!mounted) {
      return;
    }

    setState(() {
      _deliveryRecords
        ..clear()
        ..addAll(loadedRecords);
    });
  }

  Future<void> _saveDelivery() async {
    final String receiverName = (_savedReceiverName ?? _receiverNameController.text).trim();
    if (receiverName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes guardar obligatoriamente el nombre del receptor.')),
      );
      return;
    }
    if (_lastQrCapture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes escanear obligatoriamente un QR antes de guardar.')),
      );
      return;
    }
    if (_isRouteTracking || !_routeCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero detén la ruta para poder almacenar la entrega.')),
      );
      return;
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String filePath = '${appDir.path}/entregas_guardadas.json';
    final File file = File(filePath);

    List<dynamic> existingData = <dynamic>[];
    if (await file.exists()) {
      final String content = await file.readAsString();
      if (content.trim().isNotEmpty) {
        existingData = jsonDecode(content) as List<dynamic>;
      }
    }

    final DateTime now = DateTime.now();
    final String qrTitle = _lastQrCapture?.value ?? 'SIN_QR';
    final Map<String, dynamic> payload = <String, dynamic>{
      'savedAt': now.toIso8601String(),
      'transportista': widget.transportistaName,
      'receiverName': receiverName,
      'routeTaken': _routePoints
          .map(
            (CaptureMetadata item) => <String, dynamic>{
              'capturedAt': item.capturedAt.toIso8601String(),
              'latitude': item.latitude,
              'longitude': item.longitude,
            },
          )
          .toList(),
      'routeStatus': <String, dynamic>{
        'started': _routeStartedOnce,
        'completed': _routeCompleted,
      },
      'photosCount': _photoCaptures.length,
      'photos': _photoCaptures
          .map(
            (PhotoCapture item) => <String, dynamic>{
              'base64': base64Encode(item.bytes),
              'capturedAt': item.metadata.capturedAt.toIso8601String(),
              'latitude': item.metadata.latitude,
              'longitude': item.metadata.longitude,
            },
          )
          .toList(),
      'audios': _audioCaptures
          .map(
            (AudioCapture item) => <String, dynamic>{
              'base64': base64Encode(item.bytes),
              'capturedAt': item.metadata.capturedAt.toIso8601String(),
              'latitude': item.metadata.latitude,
              'longitude': item.metadata.longitude,
            },
          )
          .toList(),
      'notes': _noteCaptures
          .map(
            (NoteCapture item) => <String, dynamic>{
              'note': item.note,
              'capturedAt': item.metadata.capturedAt.toIso8601String(),
              'latitude': item.metadata.latitude,
              'longitude': item.metadata.longitude,
            },
          )
          .toList(),
      'qrs': _qrCaptures
          .map(
            (QrCapture item) => <String, dynamic>{
              'value': item.value,
              'capturedAt': item.metadata.capturedAt.toIso8601String(),
              'latitude': item.metadata.latitude,
              'longitude': item.metadata.longitude,
            },
          )
          .toList(),
      'qrPrimary': _lastQrCapture?.value,
      'qrTitle': qrTitle,
    };

    existingData.add(payload);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(existingData),
      flush: true,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _deliveryRecords.insert(
        0,
        DeliveryRecord(savedAt: now, qrTitle: qrTitle, filePath: filePath),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Entrega guardada en: $filePath')),
    );

    await _resetFormAfterSave();
  }


  Future<void> _resetFormAfterSave() async {
    _receiverNameController.clear();
    _noteController.clear();
    await _audioPlayer.stop();
    _routeTimer?.cancel();
    setState(() {
      _savedReceiverName = null;
      _lastQrCapture = null;
      _photoCaptures.clear();
      _audioCaptures.clear();
      _noteCaptures.clear();
      _qrCaptures.clear();
      _routePoints.clear();
      _isRecording = false;
      _isAudioPlaying = false;
      _isRouteTracking = false;
      _routeStartedOnce = false;
      _routeCompleted = false;
      _currentAudioPath = null;
      _currentAudioDuration = Duration.zero;
      _currentAudioPosition = Duration.zero;
    });
  }


  Future<void> _sendSavedInvoices() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entities = appDir.listSync();
    final List<File> jsonFiles = entities
        .whereType<File>()
        .where((File file) => file.path.toLowerCase().endsWith('.json'))
        .toList();

    if (jsonFiles.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay facturas guardadas para enviar.')),
      );
      return;
    }

    final Uri endpoint = Uri.parse('http://192.168.1.72:8000/api/shipments/');

    try {
      for (final File jsonFile in jsonFiles) {
        final String content = await jsonFile.readAsString();
        final http.Response response = await http.post(
          endpoint,
          headers: <String, String>{'Content-Type': 'application/json'},
          body: content,
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Error enviando ${jsonFile.path}: ${response.statusCode}');
        }
      }

      for (final File jsonFile in jsonFiles) {
        if (await jsonFile.exists()) {
          await jsonFile.delete();
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryRecords.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facturas enviadas correctamente.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron enviar las facturas. Verifica tu red local e intenta nuevamente.'),
        ),
      );
    }
  }

  Future<void> _toggleRouteTracking() async {
    if (_isRouteTracking) {
      await _confirmStopRoute();
      return;
    }

    if (_routeCompleted || _routeStartedOnce) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta ruta ya fue usada para este pedido y no se puede retomar.')),
      );
      return;
    }

    final CaptureMetadata? initialPoint = await _captureMetadata();
    if (!mounted) {
      return;
    }

    if (initialPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar el rastreo de ruta por permisos de ubicación.')),
      );
      return;
    }

    setState(() {
      _isRouteTracking = true;
      _routeStartedOnce = true;
      _routePoints.add(initialPoint);
    });

    _routeTimer = Timer.periodic(const Duration(minutes: 4), (Timer timer) async {
      final CaptureMetadata? point = await _captureMetadata();
      if (!mounted || point == null || !_isRouteTracking) {
        return;
      }
      setState(() {
        _routePoints.add(point);
      });
    });
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
              onPressed: () async {
                final String note = _noteController.text.trim();
                if (note.isEmpty) {
                  return;
                }
                final CaptureMetadata? metadata = await _captureMetadata();
                if (!context.mounted) {
                  return;
                }
                setState(() {
                  _noteCaptures.add(
                    NoteCapture(
                      note: note,
                      metadata: metadata ?? CaptureMetadata(capturedAt: DateTime.now(), latitude: 0, longitude: 0),
                    ),
                  );
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
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDBE4F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A0F172A), blurRadius: 22, offset: Offset(0, 12)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF0F172A)),
        ),
      ],
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
        disabledBackgroundColor: background.withValues(alpha: 0.75),
        foregroundColor: foreground,
        disabledForegroundColor: foreground.withValues(alpha: 0.95),
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
    final double progressMax = _currentAudioDuration.inMilliseconds.toDouble().clamp(1, double.infinity);
    final double progressValue = _currentAudioPosition.inMilliseconds
        .toDouble()
        .clamp(0, progressMax);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090812),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/img/traveling-logo.png',
              height: 24,
            ),
            const SizedBox(width: 8),
            const Text('Traveling'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEFF4FF), Color(0xFFF8FAFC)],
            ),
          ),
          child: Container(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewPadding.bottom,
              ),
            child: Column(
              children: [
                _pillButton(
                  icon: Icons.route,
                  label: _isRouteTracking ? 'DETENER RUTA' : 'INICIAR RUTA',
                  onPressed: _routeCompleted ? null : _toggleRouteTracking,
                  background: _routeCompleted
                      ? const Color(0xFF6DB560).withValues(alpha: 0.35)
                      : _isRouteTracking
                          ? Colors.red
                          : const Color(0xFF6DB560),
                  foreground: Colors.white,
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(Icons.badge_outlined, 'Nombre del Receptor(a)'),
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
                      _sectionHeader(Icons.qr_code_2_rounded, 'Código QR'),
                      const SizedBox(height: 10),
                      _pillButton(
                        icon: Icons.qr_code_scanner,
                        label: 'Escanear QR',
                        onPressed: _openQrScanner,
                      ),
                      if (_lastQrCapture != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: QrImageView(
                            data: _lastQrCapture!.value,
                            size: 160,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _lastQrCapture!.value,
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
                      _sectionHeader(Icons.photo_camera_back_outlined, 'Evidencia fotográfica'),
                      const SizedBox(height: 10),
                      _pillButton(
                        icon: Icons.camera_alt,
                        label: 'Tomar Foto (${_photoCaptures.length}/10)',
                        onPressed: _takePhoto,
                      ),
                      if (_photoCaptures.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photoCaptures.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (BuildContext context, int index) {
                              return GestureDetector(
                                onTap: () => _openPhotoPreview(_photoCaptures[index].bytes),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _photoCaptures[index].bytes,
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
                const SizedBox(height: 20),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader(Icons.note_alt_outlined, 'Notas de entrega'),
                      const SizedBox(height: 10),
                      _pillButton(
                        icon: Icons.note_add,
                        label: 'Añadir Nota',
                        onPressed: _showAddNoteDialog,
                      ),
                      if (_noteCaptures.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._noteCaptures.asMap().entries.map(
                          (MapEntry<int, NoteCapture> entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                leading: const Icon(Icons.sticky_note_2_outlined),
                                title: Text('Nota ${entry.key + 1}'),
                                subtitle: Text(
                                  entry.value.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => NotePreviewPage(noteText: entry.value.note),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 27),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _sectionHeader(Icons.mic_none_rounded, 'Audio de respaldo'),
                      const SizedBox(height: 10),
                      _pillButton(
                        icon: Icons.mic,
                        label: _isRecording ? 'Detener Audio' : 'Grabar Audio',
                        onPressed: _toggleRecording,
                      ),
                      if (_audioCaptures.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._audioCaptures.asMap().entries.map(
                          (MapEntry<int, AudioCapture> entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      _currentAudioPath == 'audio_${entry.key}' && _isAudioPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_fill,
                                    ),
                                    title: Text('Audio ${entry.key + 1}'),
                                    onTap: () async {
                                      final Directory appDir = await getApplicationDocumentsDirectory();
                                      final String tempPath =
                                          '${appDir.path}/audio_preview_${entry.key}.m4a';
                                      await File(tempPath).writeAsBytes(entry.value.bytes, flush: true);
                                      await _togglePlayPauseAudio(tempPath);
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        _currentAudioPath = 'audio_${entry.key}';
                                      });
                                    },
                                  ),
                                  if (_currentAudioPath == 'audio_${entry.key}')
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Slider(
                                        value: progressValue,
                                        max: progressMax,
                                        onChanged: _seekAudio,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _pillButton(
                  icon: Icons.save,
                  label: 'Guardar Entrega',
                  onPressed: _saveDelivery,
                  background: const Color(0xFF2979FF),
                  foreground: Colors.white,
                ),
                const SizedBox(height: 14),
                _actionPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(Icons.inventory_2_outlined, 'Entregas guardadas'),
                      const SizedBox(height: 8),
                      if (_deliveryRecords.isEmpty)
                        const Text('Aún no hay entregas guardadas.')
                      else
                        ..._deliveryRecords.map(
                          (DeliveryRecord record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              child: ListTile(
                                title: Text(record.qrTitle),
                                subtitle: Text(
                                  'Guardado: ${record.savedAt.toLocal().toString().substring(0, 19)}',
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _pillButton(
                        icon: Icons.send_rounded,
                        label: 'Enviar facturas guardadas',
                        onPressed: _deliveryRecords.isEmpty ? null : _sendSavedInvoices,
                        background: const Color(0xFF16A34A),
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
