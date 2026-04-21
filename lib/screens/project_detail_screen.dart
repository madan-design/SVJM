import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/storage_service.dart';
import '../services/project_service.dart';
import '../services/expense_pdf_service.dart';
import '../widgets/input_formatters.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  List<Map<String, dynamic>> expenses = [];
  bool isLoading = true;
  late String projectId;
  late double budget;

  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final dateController = TextEditingController();
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    projectId = ProjectService.generateProjectId(
      widget.project['company'] as String,
      widget.project['fileName'] as String,
    );
    budget = ProjectService.totalBudget(widget.project['components'] as List);
    _loadExpenses();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    dateController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    setState(() => isLoading = true);
    final data = await StorageService.getExpenses(projectId);
    setState(() {
      expenses = data;
      isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _addExpense() async {
    final rawAmount = amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(rawAmount);
    if (amount == null || amount <= 0 || noteController.text.trim().isEmpty || dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all expense fields')),
      );
      return;
    }

    final expense = {
      'amount': amount,
      'note': noteController.text.trim(),
      'date': dateController.text,
    };

    await StorageService.addExpense(projectId, expense);
    amountController.clear();
    noteController.clear();
    dateController.clear();
    selectedDate = null;
    await _loadExpenses();
  }

  Future<void> _deleteExpense(int index) async {
    await StorageService.deleteExpense(projectId, index);
    await _loadExpenses();
  }

  Future<void> _editExpense(int index) async {
    final exp = expenses[index];
    final amountCtrl = TextEditingController(
      text: (exp['amount'] as num).toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController(text: exp['note'] ?? '');
    final dateCtrl = TextEditingController(text: exp['date'] ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.tryParse(exp['date'] ?? '') ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  dateCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: dateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today, size: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [IndianAmountFormatter()],
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note / Description',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final raw = amountCtrl.text.replaceAll(',', '').trim();
              final amount = double.tryParse(raw);
              if (amount == null || amount <= 0 || noteCtrl.text.trim().isEmpty || dateCtrl.text.isEmpty) return;
              await StorageService.updateExpense(projectId, index, {
                'amount': amount,
                'note': noteCtrl.text.trim(),
                'date': dateCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _loadExpenses();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _viewQuotePdf() async {
    final bytes = await StorageService.readPdfBytes(widget.project['pdfPath'] as String);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Quote — $projectId')),
          body: PdfPreview(
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: true,
            allowSharing: true,
            build: (_) async => Uint8List.fromList(bytes),
          ),
        ),
      ),
    );
  }

  Future<void> _generateExpenseSheet({bool share = false}) async {
    if (expenses.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No Expenses'),
          content: const Text('No expenses added yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final pdfBytes = await ExpensePdfService.generateExpenseSheet(
        projectId: projectId,
        companyName: widget.project['company'] as String,
        quoteDate: widget.project['date'] as String,
        budget: budget,
        expenses: expenses,
        completedDate: widget.project['completedDate'] as String? ?? '',
      );
      if (!mounted) return;
      Navigator.pop(context);

      if (share) {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Expense of $projectId.pdf',
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text('Expense of $projectId'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () async {
                      await Printing.sharePdf(
                        bytes: pdfBytes,
                        filename: 'Expense of $projectId.pdf',
                      );
                    },
                  ),
                ],
              ),
              body: PdfPreview(
                canChangeOrientation: false,
                canChangePageFormat: false,
                allowPrinting: true,
                allowSharing: true,
                build: (_) async => pdfBytes,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Mark this project as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.completeProject(widget.project['metadataPath'] as String);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project marked as completed')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = ProjectService.totalSpent(expenses);
    final remaining = budget - spent;
    final isLive = (widget.project['status'] ?? 'confirmed') == 'confirmed';

    return Scaffold(
      appBar: AppBar(
        title: Text(projectId),
        actions: [
          if (isLive)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _markCompleted,
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Project summary card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Company', widget.project['company'] as String),
                          _infoRow('Project ID', projectId),
                          _infoRow('Quote Date', widget.project['date'] as String),
                          const Divider(height: 20),
                          _infoRow('Total Budget', ProjectService.formatAmount(budget)),
                          _infoRow('Total Spent', ProjectService.formatAmount(spent),
                              valueColor: spent > budget ? Colors.red : null),
                          _infoRow(
                            isLive ? 'Remaining' : 'Profit',
                            ProjectService.formatAmount(remaining),
                            valueColor: remaining < 0 ? Colors.red : Colors.green.shade700,
                            labelColor: isLive ? null : Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quote PDF + Expense Sheet buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('View Quote'),
                          onPressed: _viewQuotePdf,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('Expense Sheet'),
                          onPressed: () => _generateExpenseSheet(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                        onPressed: () => _generateExpenseSheet(share: true),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Add Expense section — hidden for completed projects
                  if (isLive) ...[
                    const Text('Add Expense',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    // Date + Amount in a row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: dateController,
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  labelStyle: TextStyle(fontSize: 12),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  suffixIcon: Icon(Icons.calendar_today, size: 16),
                                  hintText: 'DD/MM/YYYY',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [IndianAmountFormatter()],
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Amount (₹)',
                              labelStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: noteController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Note / Description',
                              labelStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC40000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onPressed: _addExpense,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Expenses list
                  if (expenses.isNotEmpty) ...[
                    const Text('Expenses',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...expenses.asMap().entries.map((e) {
                      final idx = e.key;
                      final exp = e.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(exp['note'] ?? ''),
                          subtitle: Text(exp['date'] ?? ''),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ProjectService.formatAmount((exp['amount'] as num).toDouble()),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (isLive) ...
                              [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () => _editExpense(idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _deleteExpense(idx),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor ?? Colors.grey, fontSize: 13, fontWeight: labelColor != null ? FontWeight.w600 : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
