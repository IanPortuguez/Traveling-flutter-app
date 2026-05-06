import 'dart:typed_data';

class CaptureMetadata {
  const CaptureMetadata({
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
  });

  final DateTime capturedAt;
  final double latitude;
  final double longitude;
}

class PhotoCapture {
  const PhotoCapture({required this.bytes, required this.metadata});

  final Uint8List bytes;
  final CaptureMetadata metadata;
}

class AudioCapture {
  const AudioCapture({required this.bytes, required this.metadata});

  final Uint8List bytes;
  final CaptureMetadata metadata;
}

class NoteCapture {
  const NoteCapture({required this.note, required this.metadata});

  final String note;
  final CaptureMetadata metadata;
}

class DeliveryRecord {
  const DeliveryRecord({
    required this.savedAt,
    required this.qrTitle,
    required this.filePath,
  });

  final DateTime savedAt;
  final String qrTitle;
  final String filePath;
}

class QrCapture {
  const QrCapture({required this.value, required this.metadata});

  final String value;
  final CaptureMetadata metadata;
}

