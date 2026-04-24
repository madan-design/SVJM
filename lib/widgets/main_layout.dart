import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import '../widgets/app_shell.dart';

/// Main layout wrapper that provides persistent sidebar and header on web
/// while maintaining mobile experience
class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final List<MainLayoutNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final bool showBackButton;
  final VoidCallback? onBack;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavTap,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = kIsWeb && MediaQuery.of(context).size.width >= 900;
    
    if (isDesktop) {
      return _WebMainLayout(
        title: widget.title,
        navItems: widget.navItems,
        selectedIndex: widget.selectedIndex,
        onNavTap: widget.onNavTap,
        userName: widget.userName,
        userRole: widget.userRole,
        onLogout: widget.onLogout,
        showBackButton: widget.showBackButton,
        onBack: widget.onBack,
        child: widget.child,
      );
    }
    
    // Mobile: return child as-is (no layout wrapper)
    return widget.child;
  }
}

/// Web layout with persistent sidebar and header
class _WebMainLayout extends StatelessWidget {
  final String title;
  final List<MainLayoutNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final String userName;
  final String userRole;
  final VoidCallback onLogout;
  final Widget child;
  final bool showBackButton;
  final VoidCallback? onBack;

  const _WebMainLayout({
    required this.title,
    required this.navItems,
    required this.selectedIndex,
    required this.onNavTap,
    required this.userName,
    required this.userRole,
    required this.onLogout,
    required this.child,
    this.showBackButton = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      body: Row(
        children: [
          // ── Fixed Sidebar ──────────────────────────────────────
          SizedBox(
            width: 240,
            child: Container(
              color: sidebarBg,
              child: Column(
                children: [
                  // Brand header
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
                          child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('SVJM', style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Mould & Solutions', style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                      ]),
                    ]),
                  ),

                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),

                  // Navigation items
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
                                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                    size: 20),
                                  const SizedBox(width: 12),
                                  Text(item.label, style: TextStyle(
                                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.75),
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
                        Text(userName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                        Text(userRole == 'admin' ? 'Administrator' : 'Mould Design Engineer',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                      ])),
                      IconButton(
                        icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                        tooltip: 'Logout',
                        onPressed: onLogout,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content Area ──────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Fixed top header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    border: Border(bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06))),
                  ),
                  child: Row(children: [
                    if (showBackButton && onBack != null) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                    ],
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
                
                // Dynamic content area with shaded container
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 1200),
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Navigation item data class
class MainLayoutNavItem {
  final String label;
  final IconData icon;
  
  const MainLayoutNavItem({
    required this.label,
    required this.icon,
  });
}