import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'dart:typed_data';
// Web-only imports - using conditional import
import 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';

class WebFileViewer extends StatefulWidget {
  final String signedUrl;
  final String fileName;

  const WebFileViewer({
    super.key,
    required this.signedUrl,
    required this.fileName,
  });

  @override
  State<WebFileViewer> createState() => _WebFileViewerState();
}

class _WebFileViewerState extends State<WebFileViewer> {
  bool _loading = true;
  String? _error;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadFileSecurely();
    }
  }

  @override
  void dispose() {
    // Clean up blob URL when widget is disposed
    if (_blobUrl != null) {
      revokeBlobUrl(_blobUrl!);
    }
    super.dispose();
  }

  Future<void> _loadFileSecurely() async {
    try {
      // Download file securely through the app
      final response = await Dio().get(
        widget.signedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Create secure blob URL
      final bytes = Uint8List.fromList(response.data);
      final mimeType = _getMimeTypeFromFileName(widget.fileName);
      final blobUrl = createBlobUrl(bytes, mimeType);

      if (mounted) {
        setState(() {
          _blobUrl = blobUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().contains('404') ? 'File not found' : 'Failed to load file';
          _loading = false;
        });
      }
    }
  }

  String _getMimeTypeFromFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'bmp':
        return 'image/bmp';
      case 'tiff':
        return 'image/tiff';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }

  void _downloadFile() {
    if (_blobUrl != null && kIsWeb) {
      try {
        // Re-download and use utility function for download
        Dio().get(
          widget.signedUrl,
          options: Options(responseType: ResponseType.bytes),
        ).then((response) {
          final bytes = Uint8List.fromList(response.data);
          final mimeType = _getMimeTypeFromFileName(widget.fileName);
          downloadBlob(bytes, mimeType, widget.fileName);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${widget.fileName} downloaded'),
                backgroundColor: Colors.green.shade600,
              ),
            );
          }
        }).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download failed: $e'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  void _openInNewTab() {
    if (_blobUrl != null && kIsWeb) {
      try {
        // Re-download and use utility function for opening
        Dio().get(
          widget.signedUrl,
          options: Options(responseType: ResponseType.bytes),
        ).then((response) {
          final bytes = Uint8List.fromList(response.data);
          final mimeType = _getMimeTypeFromFileName(widget.fileName);
          openBlobInNewTab(bytes, mimeType);
        }).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to open file: $e'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open file: $e'),
              backgroundColor: Colors.red.shade600,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Text('Web file viewer is only available on web platform'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        actions: [
          if (_blobUrl != null) ...[
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open in new tab',
              onPressed: _openInNewTab,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download',
              onPressed: _downloadFile,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red.shade600)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                )
              : _blobUrl != null
                  ? _buildFileViewer()
                  : const Center(child: Text('Unable to load file')),
    );
  }

  Widget _buildFileViewer() {
    final ext = widget.fileName.split('.').last.toLowerCase();
    
    // For all files, show download option with preview info
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // File icon based on type
          Icon(
            _getFileIcon(ext), 
            size: 64, 
            color: _getFileColor(ext)
          ),
          const SizedBox(height: 16),
          Text(
            widget.fileName, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'File loaded securely', 
            style: TextStyle(color: Colors.grey.shade600)
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in New Tab'),
                onPressed: _openInNewTab,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Download'),
                onPressed: _downloadFile,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Files are processed securely without exposing database URLs',
            style: TextStyle(
              fontSize: 12, 
              color: Colors.green.shade600,
              fontStyle: FontStyle.italic
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'webp':
        return Icons.image;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
      case 'csv':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'dwg':
      case 'dxf':
        return Icons.architecture;
      case 'step':
      case 'stp':
      case 'iges':
      case 'igs':
      case 'stl':
        return Icons.view_in_ar;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red.shade600;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
      case 'webp':
        return Colors.blue.shade600;
      case 'doc':
      case 'docx':
        return Colors.blue.shade800;
      case 'xls':
      case 'xlsx':
        return Colors.green.shade600;
      case 'ppt':
      case 'pptx':
        return Colors.orange.shade600;
      case 'txt':
      case 'csv':
        return Colors.grey.shade600;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple.shade600;
      case 'dwg':
      case 'dxf':
        return Colors.teal.shade600;
      case 'step':
      case 'stp':
      case 'iges':
      case 'igs':
      case 'stl':
        return Colors.indigo.shade600;
      default:
        return Colors.grey.shade400;
    }
  }
}