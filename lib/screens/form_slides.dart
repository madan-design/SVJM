import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quote_model.dart';
import 'preview_screen.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';
import '../widgets/capitalize_formatter.dart';
import '../widgets/input_formatters.dart';

class FormSlides extends StatefulWidget {
  final Map<String, dynamic>? existingData;

  const FormSlides({super.key, this.existingData});

  @override
  State<FormSlides> createState() => _FormSlidesState();
}

class _FormSlidesState extends State<FormSlides> {

  final PageController pageController = PageController();
  int currentPage = 0;

  // CONTROLLERS
  final dateController = TextEditingController();
  final companyController = TextEditingController();
  final addressController = TextEditingController();
  final subjectController = TextEditingController();

  final descController = TextEditingController();
  final amountController = TextEditingController();
  final machineController = TextEditingController();

  DateTime? selectedDate;
  List<Map<String,String>> components = [];
  bool includeMachine = true;
  List<String> pastCompanies = [];
  Map<String, String> companyAddressMap = {};

  @override
  void initState() {
    super.initState();
    _loadPastCompanies();
    if (widget.existingData != null) {
      _loadFromExisting(widget.existingData!);
    } else {
      _loadDraft();
    }
    _addDraftListeners();
  }

  void _loadFromExisting(Map<String, dynamic> data) {
    companyController.text = data['company'] ?? '';
    addressController.text = data['address'] ?? '';
    subjectController.text = data['subject'] ?? '';
    includeMachine = data['includeMachine'] ?? true;

    final existingDate = data['date'] ?? '';
    if (existingDate.isNotEmpty) {
      try {
        final parts = existingDate.split('/');
        selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        dateController.text = existingDate;
      } catch (_) {}
    }

    if (data['components'] != null) {
      components = List<Map<String, String>>.from(
        (data['components'] as List).map(
          (item) => Map<String, String>.from(item),
        ),
      );
    }
  }

  void _addDraftListeners() {
    for (final c in [dateController, companyController, addressController, subjectController, descController, amountController, machineController]) {
      c.addListener(_saveDraft);
    }
  }

  void _saveDraft() {
    if (widget.existingData != null) return; // don't draft when editing saved quote
    DraftService.saveDraft({
      'date': dateController.text,
      'company': companyController.text,
      'address': addressController.text,
      'subject': subjectController.text,
      'includeMachine': includeMachine,
      'components': components,
      'pendingDesc': descController.text,
      'pendingAmount': amountController.text,
      'pendingMachine': machineController.text,
    });
  }

  Future<void> _loadDraft() async {
    final draft = await DraftService.loadDraft();
    if (draft == null || !mounted) return;
    setState(() {
      dateController.text = draft['date'] ?? '';
      companyController.text = draft['company'] ?? '';
      addressController.text = draft['address'] ?? '';
      subjectController.text = draft['subject'] ?? '';
      includeMachine = draft['includeMachine'] ?? true;
      descController.text = draft['pendingDesc'] ?? '';
      amountController.text = draft['pendingAmount'] ?? '';
      machineController.text = draft['pendingMachine'] ?? '';

      final dateStr = draft['date'] ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final parts = dateStr.split('/');
          selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } catch (_) {}
      }

      if (draft['components'] != null) {
        components = List<Map<String, String>>.from(
          (draft['components'] as List).map((item) => Map<String, String>.from(item)),
        );
      }
    });
  }

  Future<void> _loadPastCompanies() async {
    final quotes = await StorageService.getAllQuotes();

    final Map<String, String> addressMap = {};
    for (var q in quotes) {
      final company = q['company'] as String;
      final address = q['address'] as String;
      if (company.isNotEmpty) {
        // Keep the most recent address for each company
        addressMap.putIfAbsent(company, () => address);
      }
    }

    if (mounted) {
      setState(() {
        pastCompanies = addressMap.keys.toList();
        companyAddressMap = addressMap;
      });
    }
  }

  String _normalizeMachine(String input) {
    final match = RegExp(r'^(\d+)', caseSensitive: false).firstMatch(input.trim());
    if (match == null) return input;
    return '${match.group(1)} ton';
  }

  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
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

  void nextPage(){
    if(currentPage < 2){
      pageController.nextPage(
        duration: Duration(milliseconds:300),
        curve: Curves.ease,
      );
    }
  }

  void previousPage(){
    if(currentPage > 0){
      pageController.previousPage(
        duration: Duration(milliseconds:300),
        curve: Curves.ease,
      );
    }
  }

  void addComponent(){

    if(descController.text.isEmpty ||
       amountController.text.isEmpty ||
       (includeMachine && machineController.text.isEmpty)){
      return;
    }

    final machine = includeMachine ? _normalizeMachine(machineController.text) : null;

    setState(() {
      components.add({
        "description": descController.text,
        "amount": amountController.text,
        if (includeMachine) "machine": machine!,
      });
    });

    descController.clear();
    amountController.clear();
    machineController.clear();
    _saveDraft();
  }

  void _editComponent(int index) {
    final editDescController = TextEditingController(text: components[index]["description"]);
    final editAmountController = TextEditingController(text: components[index]["amount"]);
    final editMachineController = TextEditingController(text: components[index]["machine"] ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Component"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editDescController,
                inputFormatters: [CapitalizeFirstLetterFormatter()],
                decoration: const InputDecoration(
                  labelText: "Component Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editAmountController,
                keyboardType: TextInputType.number,
                inputFormatters: [IndianAmountFormatter()],
                decoration: const InputDecoration(
                  labelText: "Amount",
                  border: OutlineInputBorder(),
                ),
              ),
              if (includeMachine) ...
              [
                const SizedBox(height: 12),
                TextField(
                  controller: editMachineController,
                  inputFormatters: [MachineFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Machine",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (editDescController.text.isEmpty || editAmountController.text.isEmpty ||
                  (includeMachine && editMachineController.text.isEmpty)) {
                return;
              }

              setState(() {
                components[index] = {
                  "description": editDescController.text,
                  "amount": editAmountController.text,
                  if (includeMachine) "machine": _normalizeMachine(editMachineController.text),
                };
              });
              _saveDraft();
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void generateQuote() async {

    // Validate required fields
    if(dateController.text.isEmpty || 
       companyController.text.isEmpty ||
       addressController.text.isEmpty ||
       subjectController.text.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // AUTO ADD LAST COMPONENT IF USER DIDN'T CLICK ADD
    if(descController.text.isNotEmpty &&
       amountController.text.isNotEmpty &&
       (!includeMachine || machineController.text.isNotEmpty)){

      final machine = includeMachine ? _normalizeMachine(machineController.text) : null;
      components.add({
        "description": descController.text,
        "amount": amountController.text,
        if (includeMachine) "machine": machine!,
      });

    }

    if(components.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      QuoteModel quote = QuoteModel(
        date: dateController.text,
        company: companyController.text,
        address: addressController.text,
        subject: subjectController.text,
        components: components,
      );

      final quoteData = quote.toJson();
      quoteData['includeMachine'] = includeMachine;

      final pdfBytes = await PdfService.generateQuote(quoteData);

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      // If editing an existing saved quote, delete old files before saving new one
      if (widget.existingData != null && widget.existingData!['metadataPath'] != null) {
        await StorageService.deleteQuote(
          widget.existingData!['pdfPath'] as String,
          widget.existingData!['metadataPath'] as String,
        );
      }

      // Navigate to preview with quote data
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PreviewScreen(
              pdfData: pdfBytes,
              quoteData: quoteData,
              savedFileName: widget.existingData?['fileName'] as String?,
              isDraft: widget.existingData != null,
            ),
          ),
        );
      }
      DraftService.clearDraft();

    } catch (e) {
      // Close loading indicator
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  Widget input(String label, TextEditingController controller, {TextInputFormatter? formatter}){

    return Padding(
      padding: const EdgeInsets.only(bottom:20),
      child: TextField(
        controller: controller,
        inputFormatters: [
          if (formatter != null) formatter
          else CapitalizeFirstLetterFormatter(),
        ],
        keyboardType: (formatter is IndianAmountFormatter)
            ? TextInputType.number
            : (formatter is MachineFormatter)
                ? TextInputType.text
                : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text("Create Quote"),
      ),

      body: Column(
        children: [

          Expanded(

            child: PageView(

              controller: pageController,

              onPageChanged: (index){
                setState(() {
                  currentPage = index;
                });
              },

              children: [

                // PAGE 1
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [

                      // Date picker field
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: GestureDetector(
                          onTap: pickDate,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: dateController,
                              decoration: InputDecoration(
                                labelText: 'Date',
                                border: const OutlineInputBorder(),
                                suffixIcon: const Icon(Icons.calendar_today),
                                hintText: 'DD/MM/YYYY',
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Company name with autocomplete from history
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textValue) {
                            if (textValue.text.isEmpty) {
                              return pastCompanies;
                            }
                            return pastCompanies.where((company) =>
                              company.toLowerCase().contains(
                                textValue.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (String selected) {
                            companyController.text = selected;
                            // Auto-fill address if available
                            if (companyAddressMap.containsKey(selected)) {
                              addressController.text = companyAddressMap[selected]!;
                            }
                          },
                          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                            // Sync with companyController
                            controller.text = companyController.text;
                            controller.addListener(() {
                              companyController.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              inputFormatters: [CapitalizeFirstLetterFormatter()],
                              decoration: InputDecoration(
                                labelText: 'Company Name',
                                border: const OutlineInputBorder(),
                                suffixIcon: pastCompanies.isEmpty
                                    ? null
                                    : GestureDetector(
                                        onTap: () {
                                          controller.clear();
                                          focusNode.requestFocus();
                                        },
                                        child: const Icon(Icons.arrow_drop_down),
                                      ),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final company = options.elementAt(index);
                                      return ListTile(
                                        title: Text(company),
                                        onTap: () => onSelected(company),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // PAGE 2
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      input("Address", addressController),
                      input("Subject", subjectController),
                    ],
                  ),
                ),

                // PAGE 3
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [

                        // Toggle for Machine column
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Include Machine Column:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: includeMachine,
                              onChanged: (value) {
                                setState(() {
                                  includeMachine = value;
                                  if (!value) machineController.clear();
                                });
                                _saveDraft();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        input("Component Description", descController),
                        input("Amount", amountController, formatter: IndianAmountFormatter()),
                        
                        if (includeMachine)
                          input("Machine", machineController, formatter: MachineFormatter()),

                        const SizedBox(height:20),

                        ElevatedButton(
                          onPressed: addComponent,
                          child: const Text("Add Component"),
                        ),

                        const SizedBox(height:20),

                        if(components.isNotEmpty)
                          const Text(
                            "Added Components:",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        const SizedBox(height:10),

                        for(int i = 0; i < components.length; i++)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(components[i]["description"]!),
                              subtitle: Text(
                                includeMachine && components[i].containsKey("machine")
                                    ? "Rs. ${components[i]["amount"]} | ${components[i]["machine"]}"
                                    : "Rs. ${components[i]["amount"]}"
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editComponent(i),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        components.removeAt(i);
                                      });
                                      _saveDraft();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Component removed'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),

                      ],
                    ),
                  ),
                ),

              ],
            ),

          ),

          Container(
            constraints: const BoxConstraints(minHeight: 60),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 400;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: isNarrow ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                      children: [
                        if(currentPage != 0)
                          SizedBox(
                            width: isNarrow ? double.infinity : null,
                            child: ElevatedButton(
                              onPressed: previousPage,
                              child: const Text("Back"),
                            ),
                          )
                        else
                          isNarrow ? const SizedBox.shrink() : const Spacer(),

                        if (isNarrow && currentPage != 0) const SizedBox(height: 8),

                        if(currentPage < 2)
                          SizedBox(
                            width: isNarrow ? double.infinity : null,
                            child: ElevatedButton(
                              onPressed: nextPage,
                              child: const Text("Next"),
                            ),
                          ),

                        if(currentPage == 2)
                          SizedBox(
                            width: isNarrow ? double.infinity : null,
                            child: ElevatedButton(
                              onPressed: generateQuote,
                              child: const Text("Generate Quote"),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          )

        ],
      ),

    );

  }
}