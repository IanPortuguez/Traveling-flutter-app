import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: RouteTracker(),
    );
  }
}

class RouteTracker extends StatefulWidget {
  @override
  _RouteTrackerState createState() => _RouteTrackerState();
}

class _RouteTrackerState extends State<RouteTracker> {
  Timer? _timer;
  List<LatLng> _locations = [];
  bool _tracking = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) return;

    setState(() {
      _tracking = true;
    });

    _timer = Timer.periodic(Duration(minutes: 3), (timer) async {
      Position position = await Geolocator.getCurrentPosition();

      setState(() {
        _locations.add(LatLng(position.latitude, position.longitude));
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
    return Scaffold(
      appBar: AppBar(title: Text('GPS Tracker GRATIS')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: _locations.isNotEmpty
                  ? _locations.last
                  : LatLng(0, 0),
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
              child: Text(_tracking ? 'Detener' : 'Iniciar Ruta'),
            ),
          ),
        ],
      ),
    );
  }
}