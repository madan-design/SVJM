import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import 'mail_preview_screen.dart';
import 'preview_screen.dart';
import 'project_detail_screen.dart';
import 'form_slides.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, List<Map<String, dynamic>>> groupedQuotes = {};
  bool isLoading = true;
  int expandedIndex = -1;

  @override
  void initState() {
    super.initState();
    loadQuotes();
  }

  Future<void> loadQuotes() async {
    setState(() => isLoading = true);
    final all = await StorageService.getAllQuotes();
    final relevant = all
        .where((q) => ['draft', 'confirmed', 'completed'].contains(q['status'] ?? 'draft') && q['status'] != 'archived')
        .toList();
    relevant.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in relevant) {
      grouped.putIfAbsent(q['company'] as String, () => []).add(q);
    }
    setState(() {
      groupedQuotes = grouped;
      isLoading = false;
    });
  }

  Future<void> _confirmQuote(Map<String, dynamic> quote) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Quote'),
        content: Text('Confirm "${quote['fileName']}"?\n\nThis will move it to Projects and cannot be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.confirmQuote(quote['metadataPath']);
      loadQuotes();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote confirmed and moved to Projects')));
    }
  }

  Future<void> _archiveQuote(Map<String, dynamic> quote) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Quote'),
        content: Text('Archive "${quote['fileName']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StorageService.archiveItem(quote['metadataPath']);
      loadQuotes();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote archived')));
    }
  }

  Future<void> _shareQuote(Map<String, dynamic> quote) async {
    final bytes = await StorageService.readPdfBytes(quote['pdfPath']);
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '${quote['fileName']}.pdf');
  }

  Future<void> _mailQuote(Map<String, dynamic> quote) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Preparing email...')]),
      ),
    );
    try {
      final emailContent = await GeminiService.generateEmailContent(quote);
      final bytes = await StorageService.readPdfBytes(quote['pdfPath']);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => MailPreviewScreen(
          subject: emailContent['subject']!,
          body: emailContent['body']!,
          pdfBytes: Uint8List.fromList(bytes),
          fileName: quote['fileName'],
          quoteData: quote,
        ),
      ));
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to prepare mail: $e')));
      }
    }
  }

  Future<void> _editQuote(Map<String, dynamic> quote) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => FormSlides(existingData: {
        'date': quote['date'],
        'company': quote['company'],
        'address': quote['address'],
        'subject': quote['subject'],
        'components': quote['components'],
        'fileName': quote['fileName'],
        'pdfPath': quote['pdfPath'],
        'metadataPath': quote['metadataPath'],
      }),
    ));
    loadQuotes();
  }

  Future<void> _openQuotePdf(Map<String, dynamic> quote, {bool isDraft = false}) async {
    final nav = Navigator.of(context);
    final pdfBytes = await StorageService.readPdfBytes(quote['pdfPath']);
    if (!mounted) return;
    nav.push(MaterialPageRoute(
      builder: (_) => PreviewScreen(
        pdfData: Uint8List.fromList(pdfBytes),
        quoteData: {
          'date': quote['date'],
          'company': quote['company'],
          'address': quote['address'],
          'subject': quote['subject'],
          'components': quote['components'],
        },
        savedFileName: quote['fileName'],
        isDraft: isDraft,
      ),
    )).then((_) => loadQuotes());
  }

  String _fmt(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final companies = groupedQuotes.keys.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Quote History')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedQuotes.isEmpty
              ? const Center(child: Text('No quotes generated yet', style: TextStyle(fontSize: 16)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: companies.length,
                  itemBuilder: (context, i) {
                    final company = companies[i];
                    final quotes = groupedQuotes[company]!;
                    final isOpen = expandedIndex == i;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () => setState(() => expandedIndex = isOpen ? -1 : i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  const Icon(Icons.folder),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('${quotes.length} quote${quotes.length > 1 ? 's' : ''}',
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                                      ],
                                    ),
                                  ),
                                  Icon(isOpen ? Icons.expand_less : Icons.expand_more),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            child: ClipRect(
                              child: Column(
                                children: isOpen
                                    ? quotes.map((quote) {
                                        final status = quote['status'] ?? 'draft';
                                        return _SwipeableQuoteRow(
                                          key: ValueKey(quote['fileName']),
                                          quote: quote,
                                          isDraft: status == 'draft',
                                          isConfirmed: status == 'confirmed',
                                          isCompleted: status == 'completed',
                                          formatTimestamp: _fmt,
                                          onTap: () => _openQuotePdf(quote, isDraft: status == 'draft'),
                                          onShare: status == 'draft' ? () => _shareQuote(quote) : null,
                                          onMail: status == 'draft' ? () => _mailQuote(quote) : null,
                                          onDelete: status == 'draft' ? () => _archiveQuote(quote) : null,
                                          onConfirm: status == 'draft' ? () => _confirmQuote(quote) : null,
                                          onEdit: status == 'draft' ? () => _editQuote(quote) : null,
                                          onOpenProject: (status == 'confirmed' || status == 'completed')
                                              ? () => Navigator.push(context, MaterialPageRoute(
                                                    builder: (_) => ProjectDetailScreen(project: quote),
                                                  )).then((_) => loadQuotes())
                                              : null,
                                        );
                                      }).toList()
                                    : [const SizedBox.shrink()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Swipeable quote row ───────────────────────────────────────────────────────

class _SwipeableQuoteRow extends StatefulWidget {
  final Map<String, dynamic> quote;
  final bool isDraft, isConfirmed, isCompleted;
  final String Function(int) formatTimestamp;
  final VoidCallback onTap;
  final VoidCallback? onShare, onMail, onDelete, onConfirm, onOpenProject, onEdit;

  const _SwipeableQuoteRow({
    super.key,
    required this.quote,
    required this.isDraft,
    required this.isConfirmed,
    required this.isCompleted,
    required this.formatTimestamp,
    required this.onTap,
    this.onShare,
    this.onMail,
    this.onDelete,
    this.onConfirm,
    this.onOpenProject,
    this.onEdit,
  });

  @override
  State<_SwipeableQuoteRow> createState() => _SwipeableQuoteRowState();
}

class _SwipeableQuoteRowState extends State<_SwipeableQuoteRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _drag = 0;
  bool _isOpen = false;

  static const double _revealFraction = 0.25;
  static const double _snapThreshold = 0.15;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    _anim = _ctrl.drive(CurveTween(curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d, double max) =>
      setState(() => _drag = (_drag - d.delta.dx).clamp(0.0, max));

  void _onDragEnd(DragEndDetails d, double max) =>
      _drag / max >= _snapThreshold ? _snapOpen(max) : _snapClose();

  void _snapOpen(double max) {
    _anim = Tween<double>(begin: _drag, end: max).chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
    _ctrl.forward(from: 0).then((_) => setState(() { _drag = max; _isOpen = true; }));
  }

  void _snapClose() {
    _anim = Tween<double>(begin: _drag, end: 0).chain(CurveTween(curve: Curves.easeOut)).animate(_ctrl);
    _ctrl.forward(from: 0).then((_) => setState(() { _drag = 0; _isOpen = false; }));
  }

  Widget _actionPanel(BuildContext context, double w) {
    final bg = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

    if (widget.isConfirmed || widget.isCompleted) {
      final col = widget.isCompleted ? Colors.blue.shade600 : Colors.green.shade600;
      return Container(
        width: w, color: bg,
        child: Center(
          child: GestureDetector(
            onTap: () { _snapClose(); widget.onOpenProject?.call(); },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]),
              child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      );
    }

    return Container(
      width: w, color: bg,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: () { _snapClose(); widget.onConfirm?.call(); },
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: Colors.green.shade600, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () { _snapClose(); widget.onDelete?.call(); },
            child: Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: Colors.grey.shade600, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]),
              child: const Icon(Icons.archive_rounded, color: Colors.white, size: 15),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;

    Widget badge() {
      if (widget.isCompleted) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(10)),
          child: Text('✓ Completed', style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
        );
      }
      if (widget.isConfirmed) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
          child: const Text('✓ Approved', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
        );
      }
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), tooltip: 'Edit Quote', onPressed: widget.onEdit),
        IconButton(icon: const Icon(Icons.mail_outline, size: 20), tooltip: 'Send via Email', onPressed: widget.onMail),
        IconButton(icon: const Icon(Icons.share, size: 20), tooltip: 'Share PDF', onPressed: widget.onShare),
      ]);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final fullWidth = constraints.maxWidth;
      final maxSwipe = fullWidth * _revealFraction;

      return GestureDetector(
        onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxSwipe),
        onHorizontalDragEnd: (d) => _onDragEnd(d, maxSwipe),
        child: SizedBox(
          width: fullWidth,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (ctx, child) {
                final offset = _ctrl.isAnimating ? _anim.value : _drag;
                return Stack(
                  children: [
                    // Action panel — starts just outside the right edge
                    Positioned(
                      left: fullWidth - offset,
                      top: 0,
                      bottom: 0,
                      width: maxSwipe,
                      child: _actionPanel(context, maxSwipe),
                    ),
                    // Foreground — always fullWidth, slides left
                    Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: fullWidth,
                        child: Container(
                          color: Theme.of(context).cardColor,
                          child: Column(children: [
                            const Divider(height: 1),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              title: Text(quote['fileName'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                'Date: ${quote['date']}  •  Saved: ${widget.formatTimestamp(quote['timestamp'])}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: badge(),
                              onTap: () => _isOpen ? _snapClose() : widget.onTap(),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }
}
