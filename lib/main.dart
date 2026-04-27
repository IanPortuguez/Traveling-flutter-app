import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  List<LatLng> _locations = [];
  bool _tracking = false;

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
    bool hasPermission = await _checkPermission();

    if (!hasPermission) {
      print("Sin permisos de ubicación");
      return;
    }

    setState(() {
      _tracking = true;
    });

    _timer = Timer.periodic(const Duration(minutes: 3), (timer) async {
      Position position = await Geolocator.getCurrentPosition();

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

  @override
  Widget build(BuildContext context) {
    LatLng center = _locations.isNotEmpty
        ? _locations.last
        : LatLng(19.4326, -99.1332); // ejemplo: CDMX

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
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
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
        ],
      ),
    );
  }
}