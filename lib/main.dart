import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'GPS Tracker'),
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
  Timer? _timer;
  final List<LatLng> _locations = [];
  bool _tracking = false;
  String _lastQrText = 'Aún no se ha escaneado ningún código.';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<bool> _checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _startTracking() async {
    final bool hasPermission = await _checkPermission();

    if (!hasPermission) {
      debugPrint('Sin permisos de ubicación');
      return;
    }

    setState(() {
      _tracking = true;
    });

    _timer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      final Position position = await Geolocator.getCurrentPosition();

      if (!mounted) {
        return;
      }

      setState(() {
        _locations.add(
          LatLng(position.latitude, position.longitude),
        );
      });
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    setState(() {
      _tracking = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final LatLng center =
        _locations.isNotEmpty ? _locations.last : LatLng(19.4326, -99.1332);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: center,
              zoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _locations,
                    strokeWidth: 4,
                    color: Colors.blue,
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: () {
                _tracking ? _stopTracking() : _startTracking();
              },
              child: Text(_tracking ? 'Detener Ruta' : 'Iniciar Ruta'),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              color: Colors.white.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                  ],
                ),
              ),
            ),
          ),
        ],
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
