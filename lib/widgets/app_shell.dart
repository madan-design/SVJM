import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
// Web-only imports - using conditional import
import 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';

/// Breakpoints
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < mobile;
  static bool isDesktop(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width >= tablet;
}

/// Web-aware scaffold: sidebar nav on desktop, bottom/drawer on mobile
class AppShell extends StatelessWidget {
  final String title;
  final Widget body;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final List<Widget>? appBarActions;

  const AppShell({
    super.key,
    required this.title,
    required this.body,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavTap,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && AppBreakpoints.isDesktop(context)) {
      return _WebLayout(
        title: title,
        body: body,
        navItems: navItems,
        selectedIndex: selectedIndex,
        onNavTap: onNavTap,
        userName: userName,
        userRole: userRole,
        onLogout: onLogout,
      );
    }
    return _MobileLayout(
      title: title,
      body: body,
      userName: userName,
      userRole: userRole,
      onLogout: onLogout,
      appBarActions: appBarActions,
    );
  }
}

// ── Web Sidebar Layout ─────────────────────────────────────────────────────────

class _WebLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<_NavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;

  const _WebLayout({
    required this.title, required this.body, required this.navItems,
    required this.selectedIndex, required this.onNavTap,
    required this.userName, required this.userRole, required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFF1A1A2E);
    final sidebarText = Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────
          SizedBox(
            width: 240,
            child: Container(
              color: sidebarBg,
              child: Column(
                children: [
                  // Logo + brand
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('SVJM', style: TextStyle(
                          color: sidebarText, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Mould & Solutions', style: TextStyle(
                          color: sidebarText.withValues(alpha: 0.5), fontSize: 10)),
                      ]),
                    ]),
                  ),

                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // Nav items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: navItems.length,
                      itemBuilder: (_, i) {
                        final item = navItems[i];
                        final selected = selectedIndex == i;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Material(
                            color: selected
                                ? const Color(0xFFC40000).withValues(alpha: 0.85)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => onNavTap(i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(children: [
                                  Icon(item.icon,
                                    color: selected ? Colors.white : sidebarText.withValues(alpha: 0.6),
                                    size: 20),
                                  const SizedBox(width: 12),
                                  Text(item.label, style: TextStyle(
                                    color: selected ? Colors.white : sidebarText.withValues(alpha: 0.75),
                                    fontSize: 14,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                  )),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // User info + logout
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFC40000),
                        child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(userName, style: TextStyle(color: sidebarText, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                        Text(userRole == 'admin' ? 'Administrator' : 'Mould Design Engineer',
                          style: TextStyle(color: sidebarText.withValues(alpha: 0.5), fontSize: 11)),
                      ])),
                      IconButton(
                        icon: Icon(Icons.logout_rounded, color: sidebarText.withValues(alpha: 0.6), size: 18),
                        tooltip: 'Logout',
                        onPressed: onLogout,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border(bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))),
                  ),
                  child: Row(children: [
                    Text(title, style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    )),
                    const Spacer(),
                    // User chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF4F6FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFC40000),
                          child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(userName, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
                        const SizedBox(width: 4),
                        Text('· ${userRole == 'admin' ? 'Admin' : 'MDE'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ]),
                    ),
                  ]),
                ),
                // Page content
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mobile Layout ──────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final List<Widget>? appBarActions;

  const _MobileLayout({
    required this.title, required this.body,
    required this.userName, required this.userRole,
    required this.onLogout, this.appBarActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Text(title),
        ]),
        actions: [
          ...(appBarActions ?? []),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Logout',
                onPressed: onLogout,
              ),
            ]),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ── Nav Item model ─────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

// ── File action helpers (View + Download) ──────────────────────────────────────

class FileActions {
  static const _viewableExts = [
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp',
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
  ];

  static bool isViewable(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return _viewableExts.contains(ext);
  }

  /// Open file — secure in-app viewing without exposing URLs
  static Future<void> viewFile(BuildContext context, String signedUrl, {String? fileName}) async {
    if (kIsWeb) {
      // For web, directly open file securely without popup
      await _directWebFileView(context, signedUrl, fileName ?? 'file');
      return;
    }
    
    // Mobile: download to temp and open with system viewer
    await _downloadAndOpen(context, signedUrl, view: true);
  }

  /// Download file — secure download without exposing URLs
  static Future<void> downloadFile(BuildContext context, String signedUrl, String fileName) async {
    if (kIsWeb) {
      // For web, directly download file without messages
      await _directWebFileDownload(context, signedUrl, fileName);
      return;
    }
    
    // Mobile: download to device Downloads folder
    await _downloadToDownloads(context, signedUrl, fileName);
  }

  /// Direct web file viewing - downloads and opens immediately
  static Future<void> _directWebFileView(BuildContext context, String signedUrl, String fileName) async {
    try {
      // Download file through the app
      final response = await Dio().get(
        signedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Create blob URL and open immediately
      final bytes = Uint8List.fromList(response.data);
      final mimeType = _getMimeTypeFromFileName(fileName);
      openBlobInNewTab(bytes, mimeType);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: ${e.toString().contains('404') ? 'File not found' : 'Network error'}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  /// Direct web file download - downloads immediately
  static Future<void> _directWebFileDownload(BuildContext context, String signedUrl, String fileName) async {
    try {
      // Download file through the app
      final response = await Dio().get(
        signedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Create blob and trigger download immediately
      final bytes = Uint8List.fromList(response.data);
      final mimeType = _getMimeTypeFromFileName(fileName);
      downloadBlob(bytes, mimeType, fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().contains('404') ? 'File not found' : 'Network error'}'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  /// Get MIME type from file extension
  static String _getMimeTypeFromFileName(String fileName) {
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
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'dwg':
        return 'application/acad';
      case 'dxf':
        return 'application/dxf';
      case 'step':
      case 'stp':
        return 'application/step';
      case 'iges':
      case 'igs':
        return 'application/iges';
      case 'stl':
        return 'application/sla';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> _downloadToDownloads(BuildContext context, String signedUrl, String fileName) async {
    try {
      // Use app documents directory as it's always accessible
      final appDir = await getApplicationDocumentsDirectory();
      final downloadPath = '${appDir.path}/$fileName';

      // Download file
      await Dio().download(signedUrl, downloadPath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                final result = await OpenFilex.open(downloadPath);
                if (result.type != ResultType.done && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No app found to open this file type')));
                }
              },
            ),
          ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString().contains('Permission') ? 'Storage permission required' : 'Network error'}'),
            backgroundColor: Colors.red.shade600,
          ));
      }
    }
  }

  static Future<void> _downloadAndOpen(BuildContext context, String signedUrl,
      {bool view = false, String? fileName}) async {
    try {
      // Get appropriate directory
      final dir = view ? await getTemporaryDirectory() : await getApplicationDocumentsDirectory();
      
      // Extract filename from URL if not provided
      final name = fileName ?? Uri.parse(signedUrl).pathSegments.last.split('?').first;
      final savePath = '${dir.path}/$name';

      // Download file
      await Dio().download(signedUrl, savePath);

      if (view) {
        // Open with system viewer
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No app found to open this file type')));
        }
      } else {
        // For downloads, try to save to Downloads folder if possible
        try {
          final downloadsDir = await getExternalStorageDirectory();
          if (downloadsDir != null) {
            final downloadPath = '${downloadsDir.path}/Download/$name';
            await Dio().download(signedUrl, downloadPath);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloaded to Downloads: $name')));
            }
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloaded: $name')));
          }
        } catch (e) {
          // Fallback: file is already saved to app documents
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Downloaded: $name')));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static String fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp'].contains(ext)) return '🖼️';
    if (ext == 'pdf') return '📄';
    if (['doc', 'docx'].contains(ext)) return '📝';
    if (['xls', 'xlsx'].contains(ext)) return '📊';
    if (['ppt', 'pptx'].contains(ext)) return '📑';
    if (['dwg', 'dxf'].contains(ext)) return '📐';
    if (['step', 'stp', 'x_t', 'xt', 'prt', 'igs', 'iges', 'stl', 'obj',
         'catpart', 'catproduct', 'ipt', 'iam', 'sldprt', 'sldasm', 'sat'].contains(ext)) return '🧊';
    if (['zip', 'rar', '7z'].contains(ext)) return '🗜️';
    return '📁';
  }

  static String formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Logout helper ──────────────────────────────────────────────────────────────

Future<void> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC40000), foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (ok == true) {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }
}
