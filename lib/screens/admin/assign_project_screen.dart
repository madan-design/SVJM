import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_shell.dart';

class AssignProjectScreen extends StatefulWidget {
  const AssignProjectScreen({super.key});

  @override
  State<AssignProjectScreen> createState() => _AssignProjectScreenState();
}

class _AssignProjectScreenState extends State<AssignProjectScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Assign tab state ───────────────────────────────────────
  List<Map<String, dynamic>> _approvedQuotes = [];
  List<Map<String, dynamic>> _mdeList = [];
  List<Map<String, dynamic>> _tokens = [];
  bool _loading = true;
  String? _selectedMdeId;
  String? _selectedQuoteFileName;
  final _customNameCtrl = TextEditingController();
  bool _useCustom = false;
  bool _submitting = false;

  // ── View Files tab state ───────────────────────────────────
  int _expandedIndex = -1;
  final Map<String, List<Map<String, dynamic>>> _filesCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final quotes = await StorageService.getAllQuotes();
    final approved = quotes
        .where((q) => q['status'] == 'confirmed' || q['status'] == 'completed')
        .toList();
    final mdes = await SupabaseService.getMdeList();
    final tokens = await SupabaseService.getAllTokens();
    setState(() {
      _approvedQuotes = approved;
      _mdeList = mdes;
      _tokens = tokens;
      _loading = false;
    });
  }

  // ── Assign logic ───────────────────────────────────────────

  Future<void> _assign() async {
    final projectName =
        _useCustom ? _customNameCtrl.text.trim() : _selectedQuoteFileName;
    if (projectName == null || projectName.isEmpty) {
      _snack('Please enter or select a project name.');
      return;
    }
    if (_selectedMdeId == null) {
      _snack('Please select a designer.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await SupabaseService.createToken(
        projectName: projectName,
        quoteRef: _useCustom ? null : _selectedQuoteFileName,
        assignedTo: _selectedMdeId!,
      );
      _customNameCtrl.clear();
      setState(() {
        _selectedQuoteFileName = null;
        _selectedMdeId = null;
        _submitting = false;
      });
      _snack('Project assigned successfully!');
      _filesCache.clear();
      _load();
    } catch (e) {
      setState(() => _submitting = false);
      _snack('Error: $e');
    }
  }

  Future<void> _deleteToken(String tokenId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Token'),
        content: const Text('Delete this assignment token?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseService.deleteToken(tokenId);
      _filesCache.clear();
      _load();
    }
  }

  // ── View Files logic ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> _getFiles(String tokenId) async {
    if (_filesCache.containsKey(tokenId)) return _filesCache[tokenId]!;
    final files = await SupabaseService.getFilesForToken(tokenId);
    _filesCache[tokenId] = files;
    return files;
  }

  Future<void> _viewFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.viewFile(context, url);
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _downloadFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.downloadFile(context, url, fileName);
    } catch (e) {
      _snack('Error: $e');
    }
  }

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Project'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_rounded), text: 'Assign'),
            Tab(icon: Icon(Icons.folder_special_rounded), text: 'View Files'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAssignTab(),
                _buildViewFilesTab(),
              ],
            ),
    );
  }

  // ── Assign Tab ─────────────────────────────────────────────

  Widget _buildAssignTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildForm(isDark)),
              const SizedBox(width: 20),
              Expanded(child: _buildTokenList(isDark)),
            ])
          : Column(children: [
              _buildForm(isDark),
              const SizedBox(height: 24),
              _buildTokenList(isDark),
            ]),
    );
  }

  Widget _buildForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('New Assignment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: _ToggleBtn(
              label: 'From Approved Quotes',
              selected: !_useCustom,
              onTap: () => setState(() => _useCustom = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleBtn(
              label: 'Custom Project',
              selected: _useCustom,
              onTap: () => setState(() => _useCustom = true),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        if (!_useCustom) ...[
          const Text('Select Approved Quote',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedQuoteFileName,
            hint: const Text('Choose a quote...'),
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _approvedQuotes
                .map((q) => DropdownMenuItem(
                      value: q['fileName'] as String,
                      child: Text(q['fileName'] as String,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedQuoteFileName = v),
          ),
        ] else ...[
          const Text('Project Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _customNameCtrl,
            decoration: InputDecoration(
              hintText: 'Enter project name...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],

        const SizedBox(height: 16),
        const Text('Assign To (Designer)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedMdeId,
          hint: const Text('Choose a designer...'),
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: _mdeList
              .map((m) => DropdownMenuItem(
                    value: m['id'] as String,
                    child: Text(m['name'] as String),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedMdeId = v),
        ),

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Assign Project', style: TextStyle(fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _submitting ? null : _assign,
          ),
        ),
      ]),
    );
  }

  Widget _buildTokenList(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Assigned Tokens',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (_tokens.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No tokens created yet',
                style: TextStyle(color: Colors.grey.shade500)),
          ),
        )
      else
        ..._tokens.map((t) {
          final status = t['status'] as String;
          final mdeName = (t['assigned_profile'] as Map?)?['name'] ?? 'Unknown';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? Colors.green.withValues(alpha: 0.12)
                      : const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  status == 'completed' ? Icons.check_circle_rounded : Icons.pending_rounded,
                  color: status == 'completed' ? Colors.green : const Color(0xFF2E7D32),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['project_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text('Designer: $mdeName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? Colors.green.shade100
                      : const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status == 'completed' ? '✓ Done' : '⏳ Active',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: status == 'completed'
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                onPressed: () => _deleteToken(t['id'] as String),
              ),
            ]),
          );
        }),
    ]);
  }

  // ── View Files Tab ─────────────────────────────────────────

  Widget _buildViewFilesTab() {
    if (_tokens.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No tokens assigned yet',
              style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tokens.length,
      itemBuilder: (context, i) {
        final token = _tokens[i];
        final isOpen = _expandedIndex == i;
        final mdeName = (token['assigned_profile'] as Map?)?['name'] ?? 'Unknown';
        final status = token['status'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.hardEdge,
          child: Column(children: [
            InkWell(
              onTap: () => setState(() {
                _expandedIndex = isOpen ? -1 : i;
                if (!isOpen) _filesCache.remove(token['id']);
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6A817).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.folder_special_rounded,
                        color: Color(0xFFE6A817), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(token['project_name'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text('Designer: $mdeName',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'completed'
                          ? Colors.green.shade100
                          : const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status == 'completed' ? '✓ Done' : '⏳ Active',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: status == 'completed'
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey),
                ]),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              child: isOpen
                  ? FutureBuilder<List<Map<String, dynamic>>>(
                      future: _getFiles(token['id'] as String),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final files = snap.data ?? [];
                        if (files.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No files uploaded yet.',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          );
                        }
                        return Column(
                          children: files.map((f) {
                            final fileName = f['file_name'] as String;
                            final filePath = f['file_path'] as String;
                            final canView = FileActions.isViewable(fileName);
                            return ListTile(
                              leading: Text(FileActions.fileIcon(fileName),
                                  style: const TextStyle(fontSize: 22)),
                              title: Text(fileName,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              subtitle: Text(FileActions.formatSize(f['file_size'] as int?),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                if (canView)
                                  IconButton(
                                    icon: const Icon(Icons.visibility_rounded, size: 20, color: Color(0xFF1565C0)),
                                    tooltip: 'View',
                                    onPressed: () => _viewFile(filePath, fileName),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, size: 20, color: Color(0xFF2E7D32)),
                                  tooltip: 'Download',
                                  onPressed: () => _downloadFile(filePath, fileName),
                                ),
                              ]),
                            );
                          }).toList(),
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ]),
        );
      },
    );
  }
}

// ── Toggle Button ──────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2E7D32) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              )),
        ),
      ),
    );
  }
}
