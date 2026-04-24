import re

with open('lib/screens/mde/legacy_files_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

# REVERT 1: build() back to Scaffold without TabController
old_build = """  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;
    final folderName = widget.folder['folder_name'] as String;
    final status = widget.folder['status'] as String;
    final isDraft = status == 'draft';
    
    final activeFiles = _files.where((f) => f['archived'] != true).toList();
    final archivedFiles = _files.where((f) => f['archived'] == true).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: Text(folderName),
          backgroundColor: const Color(0xFFC40000),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Active Files'),
              Tab(text: 'Archive'),
            ],
          ),
          actions: [
            if (isDraft)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _markComplete,
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildFilesTab(isDark, isWide, isDraft, activeFiles, false),
                  _buildFilesTab(isDark, isWide, false, archivedFiles, true),
                ],
              ),
      ),
    );
  }"""

new_build = """  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;
    final folderName = widget.folder['folder_name'] as String;
    final status = widget.folder['status'] as String;
    final isDraft = status == 'draft';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(folderName),
        backgroundColor: const Color(0xFFC40000),
        foregroundColor: Colors.white,
        actions: [
          if (isDraft)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _markComplete,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildFilesTab(isDark, isWide, isDraft),
    );
  }"""

if old_build in code:
    code = code.replace(old_build, new_build)

# REVERT 2: _buildFilesTab
old_buildFilesTab = """  Widget _buildFilesTab(bool isDark, bool isWide, bool isDraft, List<Map<String, dynamic>> displayFiles, bool isArchiveTab) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildFileList(isDark, isWide, isDraft, displayFiles, isArchiveTab)),
              const SizedBox(width: 24),
              if (isDraft && !isArchiveTab) SizedBox(width: 320, child: _buildUploadPanel(isDark)),
            ])
          : Column(children: [
              if (isDraft && !isArchiveTab) ...[_buildUploadPanel(isDark), const SizedBox(height: 20)],
              _buildFileList(isDark, isWide, isDraft, displayFiles, isArchiveTab),
            ]),
    );
  }"""

new_buildFilesTab = """  Widget _buildFilesTab(bool isDark, bool isWide, bool isDraft) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildFileList(isDark, isWide, isDraft)),
              const SizedBox(width: 24),
              if (isDraft) SizedBox(width: 320, child: _buildUploadPanel(isDark)),
            ])
          : Column(children: [
              if (isDraft) ...[_buildUploadPanel(isDark), const SizedBox(height: 20)],
              _buildFileList(isDark, isWide, isDraft),
            ]),
    );
  }"""
if old_buildFilesTab in code:
    code = code.replace(old_buildFilesTab, new_buildFilesTab)

# REVERT 3: _buildFileList
old_buildFileList = """  Widget _buildFileList(bool isDark, bool isWide, bool isDraft, List<Map<String, dynamic>> displayFiles, bool isArchiveTab) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.folder_open_rounded, size: 20),
        const SizedBox(width: 8),
        Text('Files (${displayFiles.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      if (!isWide && displayFiles.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('← Swipe left to reveal actions',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
      const SizedBox(height: 12),
      if (displayFiles.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(isArchiveTab ? Icons.archive_outlined : Icons.upload_file_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(isArchiveTab ? 'No archived files' : 'No files uploaded yet', style: TextStyle(color: Colors.grey.shade500)),
          ]),
        )
      else
        ...displayFiles.map((f) {"""

new_buildFileList = """  Widget _buildFileList(bool isDark, bool isWide, bool isDraft) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.folder_open_rounded, size: 20),
        const SizedBox(width: 8),
        Text('Files (${_files.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
      if (!isWide && _files.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text('← Swipe left to reveal actions',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
      const SizedBox(height: 12),
      if (_files.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(Icons.upload_file_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No files uploaded yet', style: TextStyle(color: Colors.grey.shade500)),
          ]),
        )
      else
        ..._files.map((f) {"""
if old_buildFileList in code:
    code = code.replace(old_buildFileList, new_buildFileList)


# REVERT Buttons in wide UI (remove isArchiveTab logic, just use archive)
# We use regex to replace the action buttons up until `_LegacySlidableFileItem`
code = re.sub(
    r"""                      if \(isDraft && !isArchiveTab\) \.\.\.\[.*?if \(isArchiveTab\) \.\.\.\[.*?\]\,""",
    """                      if (isDraft) ...[
                        const SizedBox(width: 6),
                        _LegacyFileActionBtn(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          color: Colors.orange.shade400,
                          onTap: () => _archiveFile(f),
                        ),
                      ],""",
    code, flags=re.DOTALL
)

# REVERT Slidable mobile UI
code = code.replace(
"""              : _LegacySlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isDraft: isDraft,
                  isArchiveTab: isArchiveTab,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                  onUnarchive: () => _unarchiveFile(f),
                );""",
"""              : _LegacySlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isDraft: isDraft,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                );"""
)

# REVERT _LegacySlidableFileItem class arguments
old_sclass = """  final bool isArchiveTab;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  const _LegacySlidableFileItem({
    required this.fileData,
    required this.fileName,
    required this.filePath,
    required this.canView,
    required this.isDark,
    required this.isDraft,
    required this.isArchiveTab,
    required this.onView,
    required this.onDownload,
    required this.onArchive,
    required this.onUnarchive,
  });"""

new_sclass = """  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onArchive;

  const _LegacySlidableFileItem({
    required this.fileData,
    required this.fileName,
    required this.filePath,
    required this.canView,
    required this.isDark,
    required this.isDraft,
    required this.onView,
    required this.onDownload,
    required this.onArchive,
  });"""
if old_sclass in code:
    code = code.replace(old_sclass, new_sclass)

# REVERT action_panel
old_action_panel = """            if (widget.canView)
              _actionBtn(Icons.visibility_rounded, const Color(0xFF1565C0), widget.onView),
            _actionBtn(Icons.download_rounded, const Color(0xFF2E7D32), widget.onDownload),
            if (widget.isDraft && !widget.isArchiveTab)
              _actionBtn(Icons.archive_outlined, Colors.orange.shade600, widget.onArchive),
            if (widget.isArchiveTab)
              _actionBtn(Icons.unarchive_rounded, Colors.green, widget.onUnarchive),"""

new_action_panel = """            if (widget.canView)
              _actionBtn(Icons.visibility_rounded, const Color(0xFF1565C0), widget.onView),
            _actionBtn(Icons.download_rounded, const Color(0xFF2E7D32), widget.onDownload),
            if (widget.isDraft)
              _actionBtn(Icons.archive_outlined, Colors.orange.shade600, widget.onArchive),"""

if old_action_panel in code:
    code = code.replace(old_action_panel, new_action_panel)

with open('lib/screens/mde/legacy_files_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

print("Reverted legacy_files_screen.dart")

with open('lib/screens/admin/assign_project_screen.dart', 'r', encoding='utf-8') as f:
    code2 = f.read()

code2 = code2.replace('preferredSize: const Size.fromHeight(88),', 'preferredSize: const Size.fromHeight(96),')

with open('lib/screens/admin/assign_project_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code2)

print("Patched assign_project_screen.dart height")
