import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'form_slides.dart';
import 'mail_preview_screen.dart';

class PreviewScreen extends StatefulWidget {
  final Uint8List pdfData;
  final Map<String, dynamic>? quoteData;
  final String? savedFileName;
  final bool isDraft;

  const PreviewScreen({
    super.key,
    required this.pdfData,
    this.quoteData,
    this.savedFileName,
    this.isDraft = false,
  });

  // readOnly = true only for confirmed/completed quotes
  bool get readOnly => savedFileName != null && !isDraft;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final TextEditingController nameController = TextEditingController();
  bool isSaved = false;
  bool isLoadingMail = false;

  @override
  void initState() {
    super.initState();
    _loadFileName();
    // If opened from history, it's already saved
    if (widget.savedFileName != null) {
      isSaved = true;
    }
  }

  Future<void> _loadFileName() async {
    if (widget.savedFileName != null) {
      nameController.text = widget.savedFileName!;
      return;
    }
    final company = widget.quoteData?['company'] ?? 'Quote';
    final generatedName = await StorageService.generateFileName(company);
    if (mounted) setState(() => nameController.text = generatedName);
  }

  Future<void> _saveQuote() async {
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a file name')),
      );
      return;
    }
    // If editing a draft, delete the old file first
    if (widget.isDraft && widget.savedFileName != null) {
      final quotes = await StorageService.getAllQuotes();
      final old = quotes.firstWhere(
        (q) => q['fileName'] == widget.savedFileName,
        orElse: () => {},
      );
      if (old.isNotEmpty) {
        await StorageService.deleteQuote(old['pdfPath'], old['metadataPath']);
      }
    }
    await StorageService.saveQuote(
      fileName: nameController.text.trim(),
      pdfBytes: widget.pdfData,
      metadata: {
        'fileName': nameController.text.trim(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'date': widget.quoteData?['date'] ?? '',
        'company': widget.quoteData?['company'] ?? '',
        'address': widget.quoteData?['address'] ?? '',
        'subject': widget.quoteData?['subject'] ?? '',
        'components': widget.quoteData?['components'] ?? [],
      },
    );
    if (mounted) {
      setState(() => isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote saved successfully!')),
      );
    }
  }

  Future<void> _openMailPreview() async {
    setState(() => isLoadingMail = true);
    try {
      final quoteForMail = {
        ...?widget.quoteData,
        'fileName': nameController.text.trim(),
      };
      final emailContent = await GeminiService.generateEmailContent(quoteForMail);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MailPreviewScreen(
            subject: emailContent['subject']!,
            body: emailContent['body']!,
            pdfBytes: widget.pdfData,
            fileName: nameController.text.trim(),
            quoteData: widget.quoteData ?? {},
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoadingMail = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Preview'),
        actions: [
          if (!widget.readOnly && widget.quoteData != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modify',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FormSlides(existingData: widget.quoteData),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              await Printing.sharePdf(
                bytes: widget.pdfData,
                filename: '${nameController.text}.pdf',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // File name + Save row — hidden in readOnly mode
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'File Name: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: TextField(
                      controller: nameController,
                      onChanged: (_) {
                        if (isSaved) setState(() => isSaved = false);
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveQuote,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),

          // PDF Preview
          Expanded(
            child: PdfPreview(
              canChangeOrientation: false,
              canChangePageFormat: false,
              allowPrinting: true,
              allowSharing: true,
              build: (format) async => widget.pdfData,
            ),
          ),

          // Complete button — hidden in readOnly mode
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaved
                      ? (isLoadingMail ? null : _openMailPreview)
                      : null,
                  icon: isLoadingMail
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    isSaved
                        ? (isLoadingMail ? 'Preparing...' : 'Complete')
                        : 'Save to Continue',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isSaved
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
