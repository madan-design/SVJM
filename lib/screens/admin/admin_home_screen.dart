import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../projects_screen.dart';
import '../archive_screen.dart';
import '../form_slides.dart';
import '../history_screen.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_shell.dart';
import 'assign_project_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String _adminName = 'Admin';
  int _selectedIndex = 0;

  // Pages for web sidebar navigation
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _pages = [
      const _DashboardPage(),
      const _QuoteMenuScreen(),
      const ProjectsScreen(),
      const ArchiveScreen(),
      const AssignProjectScreen(),
    ];
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getProfile();
    if (mounted && profile != null) {
      setState(() => _adminName = profile['name'] ?? 'Admin');
    }
  }

  static const _navItems = [
    _NavItemData('Dashboard', Icons.dashboard_rounded),
    _NavItemData('Quote Generator', Icons.description_rounded),
    _NavItemData('Projects', Icons.work_rounded),
    _NavItemData('Archive', Icons.archive_rounded),
    _NavItemData('Assign Designer', Icons.assignment_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && AppBreakpoints.isDesktop(context);

    if (isDesktop) {
      // Web: sidebar layout with persistent navigation
      return _WebAdminShell(
        adminName: _adminName,
        selectedIndex: _selectedIndex,
        onNavTap: (i) => setState(() => _selectedIndex = i),
        navItems: _navItems,
        pages: _pages,
        onLogout: () => confirmLogout(context),
      );
    }

    // Mobile: show dashboard cards
    return _MobileAdminHome(
      adminName: _adminName,
      isDark: isDark,
      onLogout: () => confirmLogout(context),
    );
  }
}

// ── Web Admin Shell ────────────────────────────────────────────────────────────

class _WebAdminShell extends StatelessWidget {
  final String adminName;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final List<_NavItemData> navItems;
  final List<Widget> pages;
  final VoidCallback onLogout;

  const _WebAdminShell({
    required this.adminName, required this.selectedIndex,
    required this.onNavTap, required this.navItems,
    required this.pages, required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      body: Row(children: [
        // Sidebar
        SizedBox(
          width: 240,
          child: Container(
            color: sidebarBg,
            child: Column(children: [
              // Brand
              Container(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/new_logo.png', fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SVJM', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Mould & Solutions', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                  ]),
                ]),
              ),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),
              // Nav
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
                        color: selected ? const Color(0xFFC40000).withValues(alpha: 0.85) : Colors.transparent,
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
              // User + logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFC40000),
                    child: Text(adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(adminName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                    Text('Administrator', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                  ])),
                  IconButton(
                    icon: Icon(Icons.logout_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                    tooltip: 'Logout',
                    onPressed: onLogout,
                  ),
                ]),
              ),
            ]),
          ),
        ),
        // Main content area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200), // Max-width container
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(children: [
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
                      Text(navItems[selectedIndex].label, style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      )),
                      const Spacer(),
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
                            child: Text(adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(adminName, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
                          const SizedBox(width: 4),
                          Text('· Admin', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: Navigator(
                      key: ValueKey('NavRoot_$selectedIndex'), // Ensure fresh navigator per main tab
                      pages: [
                        MaterialPage(
                          key: ValueKey('base_$selectedIndex'),
                          child: pages[selectedIndex],
                        ),
                      ],
                      onPopPage: (route, result) {
                        return route.didPop(result);
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Mobile Admin Home ──────────────────────────────────────────────────────────

class _MobileAdminHome extends StatelessWidget {
  final String adminName;
  final bool isDark;
  final VoidCallback onLogout;

  const _MobileAdminHome({required this.adminName, required this.isDark, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData('Quote Generator', 'Create & manage quotes',
          Image.asset('assets/Quote generator.png', width: 28, height: 28, fit: BoxFit.contain),
          const Color(0xFFC40000), isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF5F5),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _QuoteMenuScreen()))),
      _CardData('Projects', 'Track live & completed projects',
          Image.asset('assets/projects.png', width: 28, height: 28, fit: BoxFit.contain),
          const Color(0xFF1565C0), isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F6FF),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()))),
      _CardData('Archive', 'View & restore archived items',
          const Icon(Icons.archive_rounded, size: 28, color: Color(0xFF555555)),
          const Color(0xFF555555), isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen()))),
      _CardData('Assign Designer', 'Create tokens, assign & view files',
          const Icon(Icons.assignment_rounded, size: 28, color: Color(0xFF2E7D32)),
          const Color(0xFF2E7D32), isDark ? const Color(0xFF0A1F0A) : const Color(0xFFF0FFF0),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignProjectScreen()))),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset('assets/new_logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          const Text('SVJM'),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white24,
                child: Text(adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 2),
              Text(adminName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: onLogout,
              ),
            ]),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final c = cards[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: c.bgColor,
              borderRadius: BorderRadius.circular(16),
              elevation: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: c.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14)),
                      child: Center(child: c.icon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 3),
                      Text(c.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ])),
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CardData {
  final String title, subtitle;
  final Widget icon;
  final Color accent, bgColor;
  final VoidCallback onTap;
  const _CardData(this.title, this.subtitle, this.icon, this.accent, this.bgColor, this.onTap);
}

class _NavItemData {
  final String label;
  final IconData icon;
  const _NavItemData(this.label, this.icon);
}

// ── Quote Menu ─────────────────────────────────────────────────────────────────

class _QuoteMenuScreen extends StatelessWidget {
  const _QuoteMenuScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 700;

    final items = [
      _MenuItemData(Icons.add_circle_outline_rounded, 'Create Quote', 'Start a new quote',
          const Color(0xFFC40000),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormSlides()))),
      _MenuItemData(Icons.history_rounded, 'History', 'View all past quotes',
          const Color(0xFF1565C0),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()))),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6FA),
      appBar: kIsWeb ? null : AppBar(title: const Text('Quote Generator')),
      body: Padding(
        padding: EdgeInsets.all(isWide ? 32 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isWide) ...[
              Text('Quote Generator', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
              const SizedBox(height: 8),
              Text('Create new quotes or browse history',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              const SizedBox(height: 32),
            ],
            Wrap(
              spacing: 16, runSpacing: 16,
              children: items.map((item) => SizedBox(
                width: isWide ? 280 : double.infinity,
                child: Material(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 2,
                  shadowColor: Colors.black12,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: item.onTap,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14)),
                          child: Icon(item.icon, color: item.color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(height: 3),
                          Text(item.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        ])),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                      ]),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuItemData(this.icon, this.label, this.subtitle, this.color, this.onTap);
}

// ── Dashboard Page (web only) ──────────────────────────────────────────────────

class _DashboardPage extends StatefulWidget {
  const _DashboardPage();

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await StorageService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading dashboard stats: $e');
      if (mounted) {
        setState(() {
          _stats = {
            'totalQuotes': 0,
            'drafts': 0,
            'approved': 0,
            'completed': 0,
            'tasksAssigned': 0,
            'tasksCompleted': 0,
          };
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dashboard Overview', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Track your business metrics and team performance.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 32),
        
        // Stats Grid
        Wrap(spacing: 16, runSpacing: 16, children: [
          _StatCard('Total Quotes', '${_stats['totalQuotes'] ?? 0}', Icons.description_rounded, const Color(0xFFC40000), isDark),
          _StatCard('Quotes Approved', '${_stats['approved'] ?? 0}', Icons.check_circle_rounded, const Color(0xFF2E7D32), isDark),
          _StatCard('Tasks Assigned', '${_stats['tasksAssigned'] ?? 0}', Icons.assignment_rounded, const Color(0xFF1565C0), isDark),
          _StatCard('Tasks Completed', '${_stats['tasksCompleted'] ?? 0}', Icons.task_alt_rounded, const Color(0xFF7B1FA2), isDark),
        ]),
        
        const SizedBox(height: 24),
        
        // Quick Actions
        Text('Quick Actions', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 16),
        
        Wrap(spacing: 12, runSpacing: 12, children: [
          _QuickActionCard('Create Quote', Icons.add_circle_outline, const Color(0xFFC40000), isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const FormSlides()));
          }),
          _QuickActionCard('View Projects', Icons.work_outline, const Color(0xFF1565C0), isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
          }),
          _QuickActionCard('Assign Task', Icons.assignment_ind, const Color(0xFF2E7D32), isDark, () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignProjectScreen()));
          }),
        ]),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  
  const _StatCard(this.title, this.value, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
      ]),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  
  const _QuickActionCard(this.title, this.icon, this.color, this.isDark, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
