import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
  List<Map<String, dynamic>> _archivedTokens = [];
  bool _loading = true;
  String? _selectedMdeId;
  String? _selectedQuoteFileName;
  final _customNameCtrl = TextEditingController();
  bool _useCustom = false;
  bool _submitting = false;

  // ── View Files tab state ───────────────────────────────────
  final Map<String, List<Map<String, dynamic>>> _filesCache = {};
  String _viewFilesSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    final archivedTokens = await SupabaseService.getArchivedTokens();
    setState(() {
      _approvedQuotes = approved;
      _mdeList = mdes;
      _tokens = tokens;
      _archivedTokens = archivedTokens;
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

  Future<void> _archiveToken(String tokenId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Token'),
        content: const Text('Archive this assignment token? You can restore it later from the Archive tab.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SupabaseService.archiveToken(tokenId);
        _filesCache.clear();
        _load();
        _snack('Token archived successfully');
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  Future<void> _unarchiveToken(String tokenId) async {
    try {
      await SupabaseService.unarchiveToken(tokenId);
      _load();
      _snack('Token restored successfully');
    } catch (e) {
      _snack('Error: $e');
    }
  }

  Future<void> _permanentlyDeleteToken(String tokenId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete'),
        content: const Text('This will permanently delete the token and ALL associated files. This action cannot be undone!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await SupabaseService.permanentlyDeleteToken(tokenId);
        _load();
        _snack('Token and files permanently deleted');
      } catch (e) {
        _snack('Error: $e');
      }
    }
  }

  // ── View Files logic ───────────────────────────────────────

  Future<void> _viewFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.viewFile(context, url, fileName: fileName);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: (kIsWeb && MediaQuery.of(context).size.width >= 1024)
            ? null
            : const Text('Assign Designer', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
        toolbarHeight: (kIsWeb && MediaQuery.of(context).size.width >= 1024) ? 0 : null,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFC40000),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.add_task_rounded, size: 18), text: 'Assign'),
                Tab(icon: Icon(Icons.folder_copy_rounded, size: 18), text: 'View Files'),
                Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Archive'),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text('Loading...', style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  )),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildModernAssignTab(),
                _buildModernViewFilesTab(),
                _buildModernArchiveTab(),
              ],
            ),
    );
  }

  // ── Modern Assign Tab ─────────────────────────────────────────

  Widget _buildModernAssignTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _buildModernForm(isDark)),
              const SizedBox(width: 32),
              Expanded(flex: 3, child: _buildModernTokenGrid(isDark)),
            ])
          : Column(children: [
              _buildModernForm(isDark),
              const SizedBox(height: 32),
              _buildModernTokenGrid(isDark),
            ]),
    );
  }

  Widget _buildModernForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC40000), Color(0xFFA30000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('New Assignment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Create and assign project to designer', 
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 28),

        // Toggle buttons
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: _ModernToggleBtn(
                label: 'From Quotes',
                icon: Icons.description_rounded,
                selected: !_useCustom,
                onTap: () => setState(() => _useCustom = false),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _ModernToggleBtn(
                label: 'Custom Project',
                icon: Icons.edit_rounded,
                selected: _useCustom,
                onTap: () => setState(() => _useCustom = true),
                isDark: isDark,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        if (!_useCustom) ...[
          _buildModernLabel('Select Approved Quote', Icons.description_rounded),
          const SizedBox(height: 8),
          _buildModernDropdown(
            value: _selectedQuoteFileName,
            hint: 'Choose a quote...',
            items: _approvedQuotes.map((q) => DropdownMenuItem(
              value: q['fileName'] as String,
              child: Text(q['fileName'] as String, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) => setState(() => _selectedQuoteFileName = v),
            isDark: isDark,
          ),
        ] else ...[
          _buildModernLabel('Project Name', Icons.edit_rounded),
          const SizedBox(height: 8),
          _buildModernTextField(
            controller: _customNameCtrl,
            hint: 'Enter project name...',
            isDark: isDark,
          ),
        ],

        const SizedBox(height: 20),
        _buildModernLabel('Assign To Designer', Icons.person_rounded),
        const SizedBox(height: 8),
        _buildModernDropdown(
          value: _selectedMdeId,
          hint: 'Choose a designer...',
          items: _mdeList.map((m) => DropdownMenuItem(
            value: m['id'] as String,
            child: Row(children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFC40000),
                child: Text((m['name'] as String)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Text(m['name'] as String),
            ]),
          )).toList(),
          onChanged: (v) => setState(() => _selectedMdeId = v),
          isDark: isDark,
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _assign,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Assign Project', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _buildModernTokenGrid(bool isDark) {
    // Split tokens into active and completed
    final activeTokens = _tokens.where((t) => t['status'] != 'completed').toList();
    final completedTokens = _tokens.where((t) => t['status'] == 'completed').toList();
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Active Tokens Section
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 16),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Active Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          Text('${activeTokens.length} active tokens', 
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      ]),
      const SizedBox(height: 20),
      if (activeTokens.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(children: [
            Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No active assignments', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Create your first assignment above', 
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
            mainAxisExtent: 110,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
          ),
          itemCount: activeTokens.length,
          itemBuilder: (context, index) {
            final token = activeTokens[index];
            return _buildModernTokenCard(token, isDark);
          },
        ),
      
      // Completed Tokens Section
      if (completedTokens.isNotEmpty) ...[
        const SizedBox(height: 40),
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Completed Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${completedTokens.length} completed tokens', 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
            mainAxisExtent: 110,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
          ),
          itemCount: completedTokens.length,
          itemBuilder: (context, index) {
            final token = completedTokens[index];
            return _buildModernTokenCard(token, isDark);
          },
        ),
      ],
    ]);
  }

  Widget _buildModernTokenCard(Map<String, dynamic> token, bool isDark) {
    final mdeName = (token['assigned_profile'] as Map?)?['name'] ?? 'Unknown';
    final isCompleted = token['status'] == 'completed';
    
    return InkWell(
      onTap: () {
        _tabController.animateTo(1);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted 
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    token['project_name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Row(children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mdeName,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? 'Done' : 'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _archiveToken(token['id'] as String),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC40000).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.archive_rounded, color: Color(0xFFC40000), size: 14),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Archive Tab ─────────────────────────────────────────────────────────────────



  // ── Modern View Files Tab ─────────────────────────────────────────

  Widget _buildModernViewFilesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: TextField(
            onChanged: (val) => setState(() => _viewFilesSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search files or projects...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: isDark ? const Color(0xFF111111) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: () async {
        // Run test queries first
        await SupabaseService.testFileQueries();
        return SupabaseService.getFilesGroupedByDesignerYearMonthAndToken();
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: const Color(0xFFC40000),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text('Loading files...', style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
                )),
              ],
            ),
          );
        }

        Map<String, Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>> groupedFiles;
        if (snapshot.data != null) {
          groupedFiles = Map<String, Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>>.from(snapshot.data!);
        } else {
          groupedFiles = {};
        }
        
        if (_viewFilesSearchQuery.isNotEmpty) {
          final query = _viewFilesSearchQuery.toLowerCase();
          final List<Map<String, dynamic>> folderResults = [];
          
          for (final designerName in groupedFiles.keys) {
            final yearMap = groupedFiles[designerName]!;
            for (final year in yearMap.keys) {
              final monthMap = yearMap[year]!;
              for (final month in monthMap.keys) {
                final tokenMap = monthMap[month]!;
                for (final tokenId in tokenMap.keys) {
                  final files = tokenMap[tokenId]!;
                  
                  bool folderMatches = false;
                  for (final file in files) {
                    final fileName = (file['file_name'] as String?)?.toLowerCase() ?? '';
                    final projectName = (file['project_name'] as String?)?.toLowerCase() ?? '';
                    if (fileName.contains(query) || projectName.contains(query) || designerName.toLowerCase().contains(query)) {
                      folderMatches = true;
                      break;
                    }
                  }
                  
                  if (folderMatches && files.isNotEmpty) {
                    final firstFile = files.first;
                    final projectName = firstFile['project_name'] as String? ?? 'Folder';
                    
                    folderResults.add({
                      'project_name': projectName,
                      'folder_path': '$designerName / $year / $month',
                      'files': files,
                    });
                  }
                }
              }
            }
          }

          if (folderResults.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                Text('No match found', 
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: folderResults.length,
            itemBuilder: (context, index) {
              final folderData = folderResults[index];
              final projectName = folderData['project_name'] as String;
              final path = folderData['folder_path'] as String;
              final files = folderData['files'] as List<Map<String, dynamic>>;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC40000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_copy_rounded, color: Color(0xFFC40000), size: 16),
                  ),
                  title: Text(projectName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Path: $path', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  children: files.map((file) {
                    final fileName = file['file_name'] as String;
                    final fileSize = file['file_size'] as int? ?? 0;
                    final filePath = file['file_path'] as String;
                    final canView = FileActions.isViewable(fileName);
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade200)),
                      ),
                      child: Row(children: [
                        Text(FileActions.fileIcon(fileName), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(fileName, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                            Text(FileActions.formatSize(fileSize), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ]),
                        ),
                        if (canView)
                          IconButton(
                            icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF1565C0)),
                            onPressed: () => _viewFile(filePath, fileName),
                            visualDensity: VisualDensity.compact,
                          ),
                        IconButton(
                          icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF2E7D32)),
                          onPressed: () => _downloadFile(filePath, fileName),
                          visualDensity: VisualDensity.compact,
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              );
            },
          );
        }

        if (groupedFiles.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text('No files found', 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Try adjusting your search query', 
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: groupedFiles.keys.length,
          itemBuilder: (context, designerIndex) {
            final designerName = groupedFiles.keys.elementAt(designerIndex);
            final yearGroups = groupedFiles[designerName]!;
            
            // Get designer ID from first file to fetch project counts
            final firstYear = yearGroups.keys.first;
            final firstMonth = yearGroups[firstYear]!.keys.first;
            final firstToken = yearGroups[firstYear]![firstMonth]!.keys.first;
            final firstFile = yearGroups[firstYear]![firstMonth]![firstToken]!.first;
            
            // Handle both regular tokens and legacy folders
            String designerId;
            if (firstFile['is_legacy'] == true) {
              designerId = (firstFile['legacy_folders'] as Map<String, dynamic>)['created_by'] as String;
            } else {
              designerId = (firstFile['tokens'] as Map<String, dynamic>)['assigned_to'] as String;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111111) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FutureBuilder<Map<String, int>>(
                future: SupabaseService.getDesignerProjectCounts(designerId),
                builder: (context, countsSnapshot) {
                  final counts = countsSnapshot.data ?? {'assigned': 0, 'completed': 0, 'legacy': 0};
                  final assignedCount = counts['assigned'] ?? 0;
                  final completedCount = counts['completed'] ?? 0;
                  final legacyCount = counts['legacy'] ?? 0;
                  
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    childrenPadding: const EdgeInsets.only(bottom: 16),
                    leading: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC40000), Color(0xFFA30000)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          designerName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                    title: Text(designerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        _buildProjectBadge(assignedCount, 'assigned', const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _buildProjectBadge(completedCount, 'completed', const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _buildProjectBadge(legacyCount, 'old', const Color(0xFF9C27B0)),
                      ]),
                    ),
                    children: yearGroups.keys.map((year) {
                      final monthGroups = yearGroups[year]!;
                      final yearProjectCount = monthGroups.values
                          .expand((monthData) => monthData.keys)
                          .toSet()
                          .length;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_today, color: Color(0xFF8B5CF6), size: 16),
                          ),
                          title: Text(year, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('$yearProjectCount projects', 
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          children: monthGroups.keys.map((month) {
                            final tokenGroups = monthGroups[month]!;
                            final monthProjectCount = tokenGroups.keys.length;
                            
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.date_range, color: Color(0xFF06B6D4), size: 14),
                                ),
                                title: Text(month, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                subtitle: Text('$monthProjectCount projects', 
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                children: tokenGroups.keys.map((tokenId) {
                                  final files = tokenGroups[tokenId]!;
                                  final projectName = files.first['project_name'] as String;
                                  final tokenStatus = files.first['token_status'] as String;
                                  final isTokenArchived = files.first['token_archived'] as bool? ?? false;
                                  final folderTimestamp = files.first['folder_timestamp'] as String;
                                  
                                  return MouseRegion(
                                    cursor: isTokenArchived ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isTokenArchived 
                                            ? (isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade100)
                                            : (isDark ? const Color(0xFF0F0F0F) : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: isTokenArchived ? Border.all(
                                          color: Colors.grey.shade400,
                                          width: 1,
                                        ) : null,
                                      ),
                                      child: isTokenArchived 
                                          ? Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                              child: Row(children: [
                                                Container(
                                                  width: 28, height: 28,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade400,
                                                    borderRadius: BorderRadius.circular(7),
                                                  ),
                                                  child: Icon(
                                                    tokenStatus == 'completed' 
                                                        ? Icons.check_circle_rounded 
                                                        : Icons.schedule_rounded,
                                                    color: Colors.grey.shade600,
                                                    size: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '$projectName • $folderTimestamp',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600, 
                                                          fontSize: 13,
                                                          color: Colors.grey.shade600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${files.length} files • ${tokenStatus == 'completed' ? 'Completed' : 'Active'} (Archived)',
                                                        style: TextStyle(
                                                          fontSize: 11, 
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (files.first['is_legacy'] == true) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'Old',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF9C27B0),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade300,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Archived',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ]),
                                            )
                                          : ExpansionTile(
                                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              leading: Container(
                                                width: 28, height: 28,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: tokenStatus == 'completed' 
                                                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: Icon(
                                                  tokenStatus == 'completed' 
                                                      ? Icons.check_circle_rounded 
                                                      : Icons.schedule_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                              title: Row(children: [
                                                Expanded(
                                                  child: Text(
                                                    '$projectName • $folderTimestamp',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600, 
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (files.first['is_legacy'] == true) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'Old',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF9C27B0),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ]),
                                              subtitle: Text(
                                                '${files.length} files • ${tokenStatus == 'completed' ? 'Completed' : 'Active'}',
                                                style: TextStyle(
                                                  fontSize: 11, 
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              children: files.map((file) {
                                                return _buildModernFileItem(file, context);
                                              }).toList(),
                                            ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            );
          },
        );
      },
    ),
  ),
],
);
}
  
  Widget _buildProjectBadge(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
  
  Widget _buildModernFileItem(Map<String, dynamic> file, BuildContext context) {
    final fileName = file['file_name'] as String;
    final filePath = file['file_path'] as String;
    final formattedDate = file['formatted_date'] as String;
    final canView = FileActions.isViewable(fileName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFC40000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              FileActions.fileIcon(fileName),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          formattedDate,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canView)
              _buildFileActionButton(
                Icons.visibility_rounded,
                const Color(0xFFC40000),
                () => _viewFile(filePath, fileName),
              ),
            const SizedBox(width: 4),
            _buildFileActionButton(
              Icons.download_rounded,
              const Color(0xFF10B981),
              () => _downloadFile(filePath, fileName),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }


  // ── Modern Archive Tab ─────────────────────────────────────────────────────────────────

  Widget _buildModernArchiveTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_archivedTokens.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.inventory_2_rounded, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text('No archived tokens', 
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Archived tokens will appear here', 
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _archivedTokens.length,
      itemBuilder: (context, index) {
        final token = _archivedTokens[index];
        return _buildModernArchivedTokenCard(token, isDark);
      },
    );
  }

  Widget _buildModernArchivedTokenCard(Map<String, dynamic> token, bool isDark) {
    final mdeName = (token['assigned_profile'] as Map?)?['name'] ?? 'Unknown';
    final archivedAt = token['archived_at'] as String?;
    final archivedDate = archivedAt != null 
        ? DateTime.parse(archivedAt)
        : DateTime.now();
    final formattedDate = '${archivedDate.day}/${archivedDate.month}/${archivedDate.year}';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                token['project_name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  mdeName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Archived',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.restore_rounded, size: 16),
              label: const Text('Restore', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _unarchiveToken(token['id'] as String),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, size: 16),
              label: const Text('Delete Forever', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _permanentlyDeleteToken(token['id'] as String),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Modern Helper Widgets ──────────────────────────────────────────────────────────────

  Widget _buildModernLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.grey.shade600),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC40000), width: 2),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildModernDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      hint: Text(hint, style: TextStyle(color: Colors.grey.shade500)),
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC40000), width: 2),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ── Modern Toggle Button ───────────────────────────────────────────────────────────────

class _ModernToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModernToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFC40000), Color(0xFFA30000)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File Actions Helper ──────────────────────────────────────────────────────────────────

class FileActions {
  static bool isViewable(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'txt', 'md'].contains(ext);
  }
  
  static String fileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf': return '📄';
      case 'jpg': case 'jpeg': case 'png': case 'gif': return '🖼️';
      case 'doc': case 'docx': return '📝';
      case 'xls': case 'xlsx': return '📊';
      case 'zip': case 'rar': return '🗜️';
      case 'dwg': case 'dxf': return '📐';
      case 'step': case 'stp': case 'iges': case 'igs': return '🔧';
      default: return '📁';
    }
  }
  
  static Future<void> viewFile(BuildContext context, String url, {String? fileName}) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${fileName ?? 'file'}...')),
    );
  }
  
  static Future<void> downloadFile(BuildContext context, String url, String fileName) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading $fileName...')),
    );
  }

  static String formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return 'Unknown size';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}