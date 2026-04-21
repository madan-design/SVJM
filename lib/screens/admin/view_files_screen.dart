import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';

class ViewFilesScreen extends StatefulWidget {
  const ViewFilesScreen({super.key});

  @override
  State<ViewFilesScreen> createState() => _ViewFilesScreenState();
}

class _ViewFilesScreenState extends State<ViewFilesScreen> {
  List<Map<String, dynamic>> _tokens = [];
  bool _loading = true;
  int _expandedIndex = -1;
  final Map<String, List<Map<String, dynamic>>> _filesCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tokens = await SupabaseService.getAllTokens();
    setState(() { _tokens = tokens; _loading = false; });
  }

  Future<List<Map<String, dynamic>>> _getFiles(String tokenId) async {
    if (_filesCache.containsKey(tokenId)) return _filesCache[tokenId]!;
    final files = await SupabaseService.getFilesForToken(tokenId);
    _filesCache[tokenId] = files;
    return files;
  }

  Future<void> _openFile(String filePath) async {
    try {
      final url = await SupabaseService.getSignedUrl(filePath);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(ext)) return '🖼️';
    if (['pdf'].contains(ext)) return '📄';
    if (['doc', 'docx'].contains(ext)) return '📝';
    if (['dwg', 'dxf'].contains(ext)) return '📐';
    if (['step', 'stp', 'x_t', 'xt', 'prt', 'igs', 'iges', 'stl', 'obj'].contains(ext)) return '🧊';
    return '📁';
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View Files'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tokens.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.folder_open_rounded, size: 56, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No tokens assigned yet', style: TextStyle(color: Colors.grey.shade500)),
                ]))
              : ListView.builder(
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
                          onTap: () {
                            setState(() {
                              _expandedIndex = isOpen ? -1 : i;
                              if (!isOpen) _filesCache.remove(token['id']);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE6A817).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.folder_special_rounded, color: Color(0xFFE6A817), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(token['project_name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 3),
                                Text('Designer: $mdeName', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status == 'completed' ? Colors.green.shade100 : const Color(0xFFFFF3CD),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status == 'completed' ? '✓ Done' : '⏳ Active',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                      color: status == 'completed' ? Colors.green.shade800 : Colors.orange.shade800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(isOpen ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
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
                                      children: files.map((f) => ListTile(
                                        leading: Text(_fileIcon(f['file_name'] as String),
                                            style: const TextStyle(fontSize: 22)),
                                        title: Text(f['file_name'] as String,
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                        subtitle: Text(_formatSize(f['file_size'] as int?),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.download_rounded, size: 20),
                                          onPressed: () => _openFile(f['file_path'] as String),
                                        ),
                                      )).toList(),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
