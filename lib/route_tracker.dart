import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RouteTrackerPage extends StatelessWidget {
  const RouteTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: RouteTracker(),
      ),
    );
  }
}

class RouteTracker extends StatefulWidget {
  const RouteTracker({super.key});

  @override
  State<RouteTracker> createState() => _RouteTrackerState();
}

class _RouteTrackerState extends State<RouteTracker> {
  final List<LatLng> _locations = <LatLng>[];

  @override
  void initState() {
    super.initState();
    _trackLocation();
  }

  Future<void> _trackLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled || !mounted) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if ((permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de ubicación denegado.'),
        ),
      );
      return;
    }

    final Position position = await Geolocator.getCurrentPosition();

    if (!mounted) {
      return;
    }

    setState(() {
      _locations.add(LatLng(position.latitude, position.longitude));
    });
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _locations.isNotEmpty
        ? _locations.last
        : const LatLng(19.4326, -99.1332);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.traveling',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _locations,
              color: Colors.blue,
              strokeWidth: 4,
            ),
          ],
        ),
      ],
    );
  }
}
