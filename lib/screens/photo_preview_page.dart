import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/captures.dart';

class PhotoPreviewPage extends StatelessWidget {
  const PhotoPreviewPage({
    super.key,
    required this.photoBytes,
    this.metadata,
  });

  final Uint8List photoBytes;
  final CaptureMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final Widget photo = InteractiveViewer(
      child: Image.memory(photoBytes, fit: BoxFit.contain),
    );

    final Widget metadataPanel = metadata == null
        ? const SizedBox.shrink()
        : Container(
            width: 250,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBE4F0)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Datos de la foto',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Fecha: ${metadata!.capturedAt.toLocal().toString().substring(0, 19)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Latitud: ${metadata!.latitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Longitud: ${metadata!.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Vista de foto')),
      body: Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (metadata == null || constraints.maxWidth < 820) {
              return photo;
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: photo),
                const SizedBox(width: 16),
                metadataPanel,
              ],
            );
          },
        ),
      ),
    );
  }
}
