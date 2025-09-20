// lib/features/flashcards/presentation/ai_pdf_import.dart
import 'package:flutter/material.dart';

class AiPdfImportScreen extends StatelessWidget {
  const AiPdfImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI: PDF → Flashcards')),
      body: const Center(
        child: Text('AI-PDF-Import vorübergehend deaktiviert.'),
      ),
    );
  }
}