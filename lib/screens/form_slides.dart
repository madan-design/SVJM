import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../widgets/input_formatters.dart';
import 'preview_screen.dart';

class FormSlides extends StatefulWidget {
  final Map<String, dynamic>? existingQuote;
  
  const FormSlides({super.key, this.existingQuote});

  @override
  State<FormSlides> createState() => _FormSlidesState();
}

class _FormSlidesState extends State<FormSlides> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  
  // Component form controllers
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _machineController = TextEditingController();
  
  List<Map<String, String>> _components = [];
  List<String> _companyHistory = [];
  bool _isMachine = false;
  int? _editingIndex;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeForm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _dateController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _subjectController.dispose();
    _componentController.dispose();
    _amountController.dispose();
    _machineController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDraft();
    } else if (state == AppLifecycleState.paused) {
      _saveDraft();
    }
  }

  void _initializeForm() {
    _dateController.text = _formatDate(DateTime.now());
    _loadCompanyHistory();
    
    // Load existing quote data if editing
    if (widget.existingQuote != null) {
      _loadExistingQuote();
    } else {
      _loadDraft();
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  Future<void> _loadCompanyHistory() async {
    try {
      final quotes = await StorageService.getAllQuotes();
      final companies = quotes.map((q) => q['company'] as String).toSet().toList();
      setState(() {
        _companyHistory = companies;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadExistingQuote() async {
    final quote = widget.existingQuote!;
    setState(() {
      _dateController.text = quote['date'] ?? _formatDate(DateTime.now());
      _companyController.text = quote['company'] ?? '';
      _addressController.text = quote['address'] ?? '';
      _subjectController.text = quote['subject'] ?? '';
      _components = (quote['components'] as List?)
          ?.map((c) => Map<String, String>.from(c as Map))
          .toList() ?? [];
    });
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'date': _dateController.text,
      'company': _companyController.text,
      'address': _addressController.text,
      'subject': _subjectController.text,
      'components': _components,
    };
    await prefs.setString('quote_draft', json.encode(draft));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString('quote_draft');
    if (draftString != null) {
      final draft = json.decode(draftString);
      setState(() {
        _dateController.text = draft['date'] ?? _formatDate(DateTime.now());
        _companyController.text = draft['company'] ?? '';
        _addressController.text = draft['address'] ?? '';
        _subjectController.text = draft['subject'] ?? '';
        _components = (draft['components'] as List?)
            ?.map((c) => Map<String, String>.from(c as Map))
            .toList() ?? [];
      });
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('quote_draft');
  }

  void _addComponent() {
    if (_componentController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      setState(() {
        _components.add({
          'description': _componentController.text,
          'amount': _amountController.text,
          if (_isMachine && _machineController.text.isNotEmpty) 'machine': _machineController.text,
        });
        _componentController.clear();
        _amountController.clear();
        _machineController.clear();
        _isMachine = false;
      });
      _saveDraft();
    }
  }

  void _editComponent(int index) {
    final component = _components[index];
    setState(() {
      _editingIndex = index;
      _componentController.text = component['description'] ?? '';
      _amountController.text = component['amount'] ?? '';
      _isMachine = component.containsKey('machine');
      if (_isMachine) {
        _machineController.text = component['machine'] ?? '';
      }
    });
  }

  void _updateComponent() {
    if (_editingIndex != null && _componentController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      setState(() {
        _components[_editingIndex!] = {
          'description': _componentController.text,
          'amount': _amountController.text,
          if (_isMachine && _machineController.text.isNotEmpty) 'machine': _machineController.text,
        };
        _componentController.clear();
        _amountController.clear();
        _machineController.clear();
        _isMachine = false;
        _editingIndex = null;
      });
      _saveDraft();
    }
  }

  void _cancelEdit() {
    setState(() {
      _componentController.clear();
      _amountController.clear();
      _machineController.clear();
      _isMachine = false;
      _editingIndex = null;
    });
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
    });
    _saveDraft();
  }

  Future<void> _generateQuote() async {
    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final quoteData = {
        'date': _dateController.text,
        'company': _companyController.text,
        'address': _addressController.text,
        'subject': _subjectController.text,
        'components': _components,
        'includeMachine': _components.any((c) => c.containsKey('machine')),
        'status': widget.existingQuote?['status'] ?? 'draft', // Preserve existing status
      };

      final pdfBytes = await PdfService.generateQuote(quoteData);
      
      // If editing existing quote, use existing fileName
      String fileName;
      if (widget.existingQuote != null) {
        fileName = widget.existingQuote!['fileName'];
      } else {
        fileName = await StorageService.generateFileName(_companyController.text);
        await _clearDraft();
      }
      
      // Save the quote
      await StorageService.saveQuote(
        fileName: fileName,
        pdfBytes: pdfBytes,
        metadata: quoteData,
      );
      
      if (mounted) {
        if (widget.existingQuote != null) {
          // Return to previous screen with success indicator
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quote updated successfully')),
          );
        } else {
          // Navigate to preview for new quotes
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PreviewScreen(
                pdfData: pdfBytes,
                quoteData: quoteData,
                savedFileName: fileName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${widget.existingQuote != null ? 'updating' : 'generating'} quote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktopWeb ? null : AppBar(
        title: Text(widget.existingQuote != null ? 'Edit Quote' : 'Create Quote'),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Page indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index 
                        ? const Color(0xFFC40000) 
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildPage1(),
                _buildPage2(),
                _buildPage3(),
              ],
            ),
          ),
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text('Previous'),
                  ),
                const Spacer(),
                if (_currentPage < 2)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC40000),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Next'),
                  ),
                if (_currentPage == 2)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateQuote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC40000),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.existingQuote != null ? 'Update Quote' : 'Generate Quote'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildCompanyField(),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildAddressField(),
          const SizedBox(height: 16),
          _buildSubjectField(),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Components',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          _buildComponentForm(),
          const SizedBox(height: 16),
          Expanded(child: _buildComponentsList()),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      decoration: const InputDecoration(
        labelText: 'Date',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) {
          _dateController.text = _formatDate(date);
          _saveDraft();
        }
      },
    );
  }

  Widget _buildCompanyField() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _companyHistory.where((company) =>
            company.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        _companyController.text = selection;
        _saveDraft();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _companyController.text = controller.text;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          onChanged: (value) {
            _companyController.text = value;
            _saveDraft();
          },
        );
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: const InputDecoration(
        labelText: 'Address',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
      ),
      maxLines: 3,
      onChanged: (value) => _saveDraft(),
    );
  }

  Widget _buildSubjectField() {
    return TextFormField(
      controller: _subjectController,
      decoration: const InputDecoration(
        labelText: 'Subject',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.subject),
      ),
      onChanged: (value) => _saveDraft(),
    );
  }

  Widget _buildComponentForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _componentController,
              decoration: const InputDecoration(
                labelText: 'Component Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [IndianAmountFormatter()],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Switch(
                  value: _isMachine,
                  onChanged: (value) {
                    setState(() {
                      _isMachine = value;
                      if (!value) {
                        _machineController.clear();
                      }
                    });
                  },
                  activeThumbColor: const Color(0xFFC40000),
                ),
                const Text('Machine Component'),
              ],
            ),
            if (_isMachine) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _machineController,
                decoration: const InputDecoration(
                  labelText: 'Machine Tonnage',
                  border: OutlineInputBorder(),
                  suffixText: 'Ton',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [MachineFormatter()],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _editingIndex != null ? _updateComponent : _addComponent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC40000),
                  foregroundColor: Colors.white,
                ),
                child: Text(_editingIndex != null ? 'Update Component' : 'Add Component'),
              ),
            ),
            if (_editingIndex != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Cancel Edit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComponentsList() {
    if (_components.isEmpty) {
      return const Center(
        child: Text('No components added yet'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _components.length,
      itemBuilder: (context, index) {
        final component = _components[index];
        return Card(
          child: ListTile(
            title: Text(component['description'] ?? ''),
            subtitle: Text('₹ ${component['amount']}${component.containsKey('machine') ? ' - ${component['machine']} Ton' : ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editComponent(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeComponent(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}