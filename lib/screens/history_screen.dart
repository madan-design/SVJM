import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import 'mail_preview_screen.dart';
import 'preview_screen.dart';
import 'form_slides.dart';
import 'company_projects_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _quotes = [];
  Map<String, List<Map<String, dynamic>>> _groupedQuotes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get both draft and approved quotes (confirmed + completed)
      final draftQuotes = await StorageService.getDraftQuotes();
      final approvedQuotes = await StorageService.getAllProjects(); // confirmed + completed
      
      final allQuotes = [...draftQuotes, ...approvedQuotes];
      final grouped = <String, List<Map<String, dynamic>>>{};
      
      for (final quote in allQuotes) {
        final company = quote['company'] as String;
        if (!grouped.containsKey(company)) {
          grouped[company] = [];
        }
        grouped[company]!.add(quote);
      }
      
      // Sort quotes within each company: drafts first, then confirmed, then completed
      for (final companyQuotes in grouped.values) {
        companyQuotes.sort((a, b) {
          final statusA = a['status'] as String? ?? 'draft';
          final statusB = b['status'] as String? ?? 'draft';
          
          // Define sort order: draft = 0, confirmed = 1, completed = 2
          int getStatusOrder(String status) {
            switch (status) {
              case 'draft': return 0;
              case 'confirmed': return 1;
              case 'completed': return 2;
              default: return 3;
            }
          }
          
          return getStatusOrder(statusA).compareTo(getStatusOrder(statusB));
        });
      }

      setState(() {
        _quotes = allQuotes;
        _groupedQuotes = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quotes: $e')),
        );
      }
    }
  }

  Future<void> _shareQuote(Map<String, dynamic> quote) async {
    try {
      final pdfBytes = Uint8List.fromList(await StorageService.readPdfBytes(quote['pdfPath']));
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '${quote['fileName']}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing quote: $e')),
        );
      }
    }
  }

  Future<void> _mailQuote(Map<String, dynamic> quote) async {
    try {
      final emailContent = await GeminiService.generateEmailContent(quote);
      final pdfBytes = Uint8List.fromList(await StorageService.readPdfBytes(quote['pdfPath']));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MailPreviewScreen(
              subject: emailContent['subject'] ?? 'Quote from SVJM',
              body: emailContent['body'] ?? 'Please find the attached quote.',
              pdfBytes: pdfBytes,
              fileName: quote['fileName'],
              quoteData: quote,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing email: $e')),
        );
      }
    }
  }

  Future<void> _deleteQuote(Map<String, dynamic> quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quote'),
        content: Text('Are you sure you want to delete the quote for ${quote['company']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageService.deleteQuote(quote['pdfPath'], quote['metadataPath']);
        _loadQuotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quote deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting quote: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmQuote(Map<String, dynamic> quote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Quote'),
        content: Text('Confirm quote for ${quote['company']}? This will move it to Projects.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFC40000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await StorageService.confirmQuote(quote['metadataPath']);
        _loadQuotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quote confirmed and moved to Projects')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error confirming quote: $e')),
          );
        }
      }
    }
  }

  void _viewQuote(Map<String, dynamic> quote) async {
    try {
      final pdfBytes = Uint8List.fromList(await StorageService.readPdfBytes(quote['pdfPath']));
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(
              pdfData: pdfBytes,
              quoteData: quote,
              savedFileName: quote['fileName'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quote: $e')),
        );
      }
    }
  }

  void _editQuote(Map<String, dynamic> quote) async {
    if (mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FormSlides(existingQuote: quote),
        ),
      );
      if (result == true) {
        _loadQuotes(); // Refresh the list if quote was updated
      }
    }
  }

  void _navigateToProjectFolder(Map<String, dynamic> quote) async {
    final company = quote['company'] as String;
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompanyProjectsScreen(companyName: company),
        ),
      ).then((_) => _loadQuotes()); // Refresh when returning
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktopWeb ? null : AppBar(
        title: const Text('Quote History'),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quotes.isEmpty
              ? const Center(
                  child: Text(
                    'No quotes found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupedQuotes.length,
                  itemBuilder: (context, index) {
                    final company = _groupedQuotes.keys.elementAt(index);
                    final quotes = _groupedQuotes[company]!;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text(
                          company,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text('${quotes.length} quote${quotes.length > 1 ? 's' : ''}'),
                        children: quotes.map((quote) => _buildQuoteItem(quote)).toList(),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildQuoteItem(Map<String, dynamic> quote) {
    final status = quote['status'] as String? ?? 'draft';
    final isDraft = status == 'draft';
    final isConfirmed = status == 'confirmed';
    final isCompleted = status == 'completed';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote['subject'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${quote['date'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Draft',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isConfirmed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '✓ Confirmed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '✓ Completed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.visibility,
                    label: 'View',
                    onPressed: () => _viewQuote(quote),
                  ),
                  if (isDraft) ...[
                    _buildActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      color: Colors.blue,
                      onPressed: () => _editQuote(quote),
                    ),
                    _buildActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onPressed: () => _shareQuote(quote),
                    ),
                    _buildActionButton(
                      icon: Icons.email,
                      label: 'Mail',
                      onPressed: () => _mailQuote(quote),
                    ),
                    _buildActionButton(
                      icon: Icons.check_circle,
                      label: 'Confirm',
                      color: const Color(0xFFC40000),
                      onPressed: () => _confirmQuote(quote),
                    ),
                    _buildActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      color: Colors.red,
                      onPressed: () => _deleteQuote(quote),
                    ),
                  ] else ...[
                    // For approved quotes, show folder button
                    _buildActionButton(
                      icon: Icons.folder,
                      label: 'Folder',
                      color: isCompleted ? Colors.green : Colors.blue,
                      onPressed: () => _navigateToProjectFolder(quote),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.grey[600], size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}