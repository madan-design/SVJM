import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/web_drag_drop_stub.dart'
    if (dart.library.html) '../../widgets/web_drag_drop.dart';

class MdeProjectScreen extends StatefulWidget {
  final Map<String, dynamic> token;
  const MdeProjectScreen({super.key, required this.token});

  @override
  State<MdeProjectScreen> createState() => _MdeProjectScreenState();
}

class _MdeProjectScreenState extends State<MdeProjectScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _uploading = false;
  bool _isDragOver = false;

  late final String _tokenId;
  late final String _projectName;
  late final bool _isCompleted;

  static const _allowedExtensions = [
    'x_t', 'xt', 'step', 'stp', 'prt', 'igs', 'iges', 'stl', 'obj', 'sat',
    'catpart', 'catproduct', 'ipt', 'iam', 'sldprt', 'sldasm',
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tiff',
    'dwg', 'dxf', 'zip', 'rar', '7z',
  ];

  @override
  void initState() {
    super.initState();
    _tokenId = widget.token['id'] as String;
    _projectName = widget.token['project_name'] as String;
    _isCompleted = widget.token['status'] == 'completed';
    _loadFiles();
    
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WebDragDropHandler.setupDragListeners(
          () => setState(() => _isDragOver = true),
          () => setState(() => _isDragOver = false),
          (files) => _handleWebDroppedFiles(files),
        );
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebDragDropHandler.removeDragListeners();
    }
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final files = await SupabaseService.getFilesForToken(_tokenId);
      
      if (mounted) {
        setState(() { 
          _files = files; 
          _loading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _files = [];
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    await _uploadFiles(result.files);
  }

  Future<void> _uploadFiles(List<PlatformFile> files) async {
    setState(() => _uploading = true);
    int success = 0;
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      
      // Check file extension
      final ext = file.name.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name}: File type not supported')));
        }
        continue;
      }
      
      final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
      try {
        await SupabaseService.uploadFile(
          tokenId: _tokenId,
          fileName: file.name,
          bytes: Uint8List.fromList(bytes),
          mimeType: mime,
        );
        success++;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload ${file.name}: $e')));
        }
      }
    }
    setState(() => _uploading = false);
    if (success > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$success file${success > 1 ? 's' : ''} uploaded')));
      }
      await _loadFiles();
    }
  }

  Future<void> _handleWebDroppedFiles(List<dynamic> files) async {
    if (!kIsWeb) return;
    
    try {
      final platformFiles = await WebDragDropHandler.handleDroppedFiles(
        files,
        _allowedExtensions,
      );
      
      if (platformFiles.isNotEmpty) {
        await _uploadFiles(platformFiles);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No supported files found')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing dropped files: $e')),
        );
      }
    }
  }

  Future<void> _archiveFile(Map<String, dynamic> file) async {
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Archive File'),
          content: Text('Archive "${file['file_name']}"? The file will be moved to your archive.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (ok == true) {
        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Archiving file...'), duration: Duration(seconds: 2)));
        }
        
        await SupabaseService.archiveFile(file['id'] as String);
        await _loadFiles();
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File archived successfully')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String message = 'Error archiving file';
        if (e.toString().contains('database schema')) {
          message = 'Archive feature requires database update. File was deleted instead.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.orange));
      }
    }
  }

  Future<void> _viewFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.viewFile(context, url, fileName: fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadFile(String filePath, String fileName) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (mounted) await FileActions.downloadFile(context, url, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text('Mark this project as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await SupabaseService.markTokenCompleted(_tokenId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project marked as completed!')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(_projectName),
        actions: [
          if (!_isCompleted)
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
          : _buildFilesTab(isDark, isWide),
    );
  }

  Widget _buildFileList(bool isDark, bool isWide) {
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
        ..._files.map((f) {
          final fileName = f['file_name'] as String;
          final filePath = f['file_path'] as String;
          final canView = FileActions.isViewable(fileName);

          return isWide 
              ? Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(children: [
                      Text(FileActions.fileIcon(fileName), style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(FileActions.formatSize(f['file_size'] as int?),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ])),
                      // View button (only for viewable types)
                      if (canView)
                        _FileActionBtn(
                          icon: Icons.visibility_rounded,
                          label: 'View',
                          color: const Color(0xFF1565C0),
                          onTap: () => _viewFile(filePath, fileName),
                        ),
                      const SizedBox(width: 6),
                      // Download button (always)
                      _FileActionBtn(
                        icon: Icons.download_rounded,
                        label: 'Download',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _downloadFile(filePath, fileName),
                      ),
                      if (!_isCompleted) ...[
                        const SizedBox(width: 6),
                        _FileActionBtn(
                          icon: Icons.archive_outlined,
                          label: 'Archive',
                          color: Colors.orange.shade400,
                          onTap: () => _archiveFile(f),
                        ),
                      ],
                    ]),
                  ),
                )
              : _SlidableFileItem(
                  fileData: f,
                  fileName: fileName,
                  filePath: filePath,
                  canView: canView,
                  isDark: isDark,
                  isCompleted: _isCompleted,
                  onView: () => _viewFile(filePath, fileName),
                  onDownload: () => _downloadFile(filePath, fileName),
                  onArchive: () => _archiveFile(f),
                );
        }),
    ]);
  }

  Widget _buildFilesTab(bool isDark, bool isWide) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 28 : 16),
      child: isWide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: _buildFileList(isDark, isWide)),
              const SizedBox(width: 24),
              if (!_isCompleted) SizedBox(width: 320, child: _buildUploadPanel(isDark)),
            ])
          : Column(children: [
              if (!_isCompleted) ...[_buildUploadPanel(isDark), const SizedBox(height: 20)],
              _buildFileList(isDark, isWide),
            ]),
    );
  }

  Widget _buildUploadPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Upload Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('3D files, PDFs, drawings, images & more',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        kIsWeb ? _CrossPlatformUploader(
          isDark: isDark,
          uploading: _uploading,
          isDragOver: _isDragOver,
          onTap: _uploading ? null : _pickAndUpload,
        ) : GestureDetector(
          onTap: _uploading ? null : _pickAndUpload,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _uploading
                ? const Column(children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 12),
                    Text('Uploading...', style: TextStyle(fontSize: 13)),
                  ])
                : Column(children: [
                    Icon(Icons.cloud_upload_rounded, size: 40,
                        color: const Color(0xFF1565C0).withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    const Text('Tap to choose files',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        Text('Supported: .step .x_t .prt .igs .stl .dwg .pdf .doc .jpg .png .zip and more',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    );
  }
}

class _SlidableFileItem extends StatefulWidget {
  final Map<String, dynamic> fileData;
  final String fileName;
  final String filePath;
  final bool canView;
  final bool isDark;
  final bool isCompleted;
  final VoidCallback onView;
  final VoidCallback onDownload;
  final VoidCallback onArchive;

  const _SlidableFileItem({
    required this.fileData,
    required this.fileName,
    required this.filePath,
    required this.canView,
    required this.isDark,
    required this.isCompleted,
    required this.onView,
    required this.onDownload,
    required this.onArchive,
  });

  @override
  State<_SlidableFileItem> createState() => _SlidableFileItemState();
}

class _SlidableFileItemState extends State<_SlidableFileItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _drag = 0;
  bool _isOpen = false;

  // File actions: view (optional) + download + archive = 2-3 buttons → moderate panel
  static const double _revealFraction = 0.35;
  static const double _snapThreshold = 0.15;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
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

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { 
        _snapClose(); 
        onTap(); 
      },
      child: Container(
        width: 36, 
        height: 36,
        decoration: BoxDecoration(
          color: color, 
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35), 
              blurRadius: 6, 
              offset: const Offset(0, 2)
            )
          ]
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _actionPanel(double w) {
    final bg = widget.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(12), 
        bottomRight: Radius.circular(12)
      ),
      child: Container(
        width: w, 
        color: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.canView)
              _actionBtn(Icons.visibility_rounded, const Color(0xFF1565C0), widget.onView),
            _actionBtn(Icons.download_rounded, const Color(0xFF2E7D32), widget.onDownload),
            if (!widget.isCompleted)
              _actionBtn(Icons.archive_outlined, Colors.orange.shade600, widget.onArchive),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(builder: (context, constraints) {
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
                builder: (ctx, _) {
                  final offset = _ctrl.isAnimating ? _anim.value : _drag;
                  return Stack(children: [
                    // Action panel background
                    Positioned(
                      left: fullWidth - offset, 
                      top: 0, 
                      bottom: 0, 
                      width: maxSwipe,
                      child: _actionPanel(maxSwipe),
                    ),
                    // Main file tile
                    Transform.translate(
                      offset: Offset(-offset, 0),
                      child: SizedBox(
                        width: fullWidth,
                        child: Material(
                          color: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 2,
                          shadowColor: Colors.black12,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _isOpen ? _snapClose() : widget.onView(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(children: [
                                Text(FileActions.fileIcon(widget.fileName), 
                                    style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start, 
                                    children: [
                                      Text(widget.fileName, 
                                          style: const TextStyle(
                                            fontSize: 14, 
                                            fontWeight: FontWeight.w500
                                          )),
                                      Text(FileActions.formatSize(widget.fileData['file_size'] as int?),
                                          style: TextStyle(
                                            fontSize: 12, 
                                            color: Colors.grey.shade500
                                          )),
                                    ]
                                  )
                                ),
                                Icon(
                                  Icons.chevron_left, 
                                  size: 14, 
                                  color: Colors.grey.shade400
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _FileActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FileActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _CrossPlatformUploader extends StatelessWidget {
  final bool isDark;
  final bool uploading;
  final bool isDragOver;
  final VoidCallback? onTap;

  const _CrossPlatformUploader({
    required this.isDark,
    required this.uploading,
    required this.isDragOver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: isDragOver 
              ? (isDark ? const Color(0xFF2E4A3D) : const Color(0xFFE8F5E8))
              : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F8FF)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDragOver 
                ? const Color(0xFF2E7D32)
                : Colors.grey.shade300,
            width: isDragOver ? 2 : 1,
          ),
        ),
        child: uploading
            ? const Column(children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(height: 12),
                Text('Uploading...', style: TextStyle(fontSize: 13)),
              ])
            : Column(children: [
                Icon(
                  isDragOver ? Icons.file_download : Icons.cloud_upload_rounded,
                  size: 40,
                  color: isDragOver 
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF1565C0).withValues(alpha: 0.7),
                ),
                const SizedBox(height: 10),
                Text(
                  isDragOver ? 'Drop files here' : 'Click to choose files',
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: FontWeight.w500,
                    color: isDragOver ? const Color(0xFF2E7D32) : null,
                  ),
                ),
                if (!isDragOver && kIsWeb) ...[
                  const SizedBox(height: 4),
                  Text(
                    'or drag & drop here',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ]),
      ),
    );
  }
}