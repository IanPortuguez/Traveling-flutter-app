import 'package:flutter/material.dart';

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
