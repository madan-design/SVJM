import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/gemini_service.dart';

class MailPreviewScreen extends StatefulWidget {
  final String subject;
  final String body;
  final Uint8List pdfBytes;
  final String fileName;
  final Map<String, dynamic> quoteData;

  const MailPreviewScreen({
    super.key,
    required this.subject,
    required this.body,
    required this.pdfBytes,
    required this.fileName,
    required this.quoteData,
  });

  @override
  State<MailPreviewScreen> createState() => _MailPreviewScreenState();
}

class _MailPreviewScreenState extends State<MailPreviewScreen> {
  late TextEditingController subjectController;
  late TextEditingController bodyController;
  bool isSending = false;
  bool isRegenerating = false;

  @override
  void initState() {
    super.initState();
    subjectController = TextEditingController(text: widget.subject);
    bodyController = TextEditingController(text: widget.body);
  }

  @override
  void dispose() {
    subjectController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  Future<void> regenerateContent() async {
    setState(() => isRegenerating = true);
    try {
      final emailContent = await GeminiService.generateEmailContent({
        ...widget.quoteData,
        'fileName': widget.fileName,
      });
      if (mounted) {
        subjectController.text = emailContent['subject']!;
        bodyController.text = emailContent['body']!;
      }
    } finally {
      if (mounted) setState(() => isRegenerating = false);
    }
  }

  Future<void> sendMail() async {
    setState(() => isSending = true);
    try {
      final cacheDir = await getTemporaryDirectory();
      final tempFile = File('${cacheDir.path}/${widget.fileName}.pdf');
      await tempFile.writeAsBytes(widget.pdfBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'application/pdf')],
        subject: subjectController.text,
        text: bodyController.text,
      );
    } finally {
      if (mounted) setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mail Preview'),
        actions: [
          // Dice / regenerate button
          isRegenerating
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate Content',
                  onPressed: regenerateContent,
                ),
          // Send button
          isSending
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: 'Send Mail',
                  onPressed: sendMail,
                ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Attachment indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.fileName}.pdf',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Subject field
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Body field
            Expanded(
              child: Stack(
                children: [
                  TextField(
                    controller: bodyController,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: 'Email Body',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (isRegenerating)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSending ? null : sendMail,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Open Mail App'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
