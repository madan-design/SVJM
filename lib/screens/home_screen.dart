import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'form_slides.dart';
import 'history_screen.dart';
import 'projects_screen.dart';
import 'archive_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  String _userRole = 'user';
  int _selectedIndex = 0;
  Widget? _currentSubPage; // For nested navigation within app shell

  // Pages for web sidebar navigation
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _pages = [
      const _DashboardPage(),
      _QuoteMenuScreen(onNavigate: navigateToSubPage),
      const ProjectsScreen(),
      const ArchiveScreen(),
    ];
  }

  void navigateToSubPage(Widget page) {
    if (kIsWeb && AppBreakpoints.isDesktop(context)) {
      setState(() {
        _currentSubPage = page;
      });
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }
  }

  void navigateToSubPageWithScaffold(Widget page) {
    // Always use full navigation for complex screens
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void navigateBack() {
    setState(() {
      _currentSubPage = null;
    });
  }

  void navigateToProjectsTab() {
    setState(() {
      _selectedIndex = 2; // Projects tab
      _currentSubPage = null;
    });
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.getProfile();
    if (mounted && profile != null) {
      setState(() {
        _userName = profile['name'] ?? 'User';
        _userRole = profile['role'] ?? 'user';
      });
    }
  }

  static const _navItems = [
    _NavItemData('Dashboard', Icons.dashboard_rounded),
    _NavItemData('Quote Generator', Icons.description_rounded),
    _NavItemData('Projects', Icons.work_rounded),
    _NavItemData('Archive', Icons.archive_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb && AppBreakpoints.isDesktop(context);

    if (isDesktop) {
      // Web: sidebar layout with persistent navigation
      return _WebHomeShell(
        userName: _userName,
        userRole: _userRole,
        selectedIndex: _selectedIndex,
        onNavTap: (i) {
          setState(() {
            _selectedIndex = i;
            _currentSubPage = null; // Reset sub-page when changing main nav
          });
        },
        navItems: _navItems,
        pages: _pages,
        currentSubPage: _currentSubPage,
        onNavigateBack: navigateBack,
        onLogout: () => confirmLogout(context),
      );
    }

    // Mobile: show dashboard cards
    return _MobileHome(
      userName: _userName,
      userRole: _userRole,
      isDark: isDark,
      onLogout: () => confirmLogout(context),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final Color accentColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuoteMenuScreen extends StatelessWidget {
  final Function(Widget)? onNavigate;
  
  const _QuoteMenuScreen({this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isInAppShell = kIsWeb && AppBreakpoints.isDesktop(context) && onNavigate != null;
    
    return isInAppShell ? _buildContent(context) : Scaffold(
      appBar: AppBar(title: const Text('Quote Generator'), centerTitle: true),
      body: _buildContent(context),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MenuCard(
            icon: Icons.add_circle_outline_rounded,
            label: 'Create Quote',
            subtitle: 'Start a new quote',
            color: const Color(0xFFC40000),
            onTap: () {
              if (onNavigate != null) {
                onNavigate!(_AppShellFormSlides());
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FormSlides()));
              }
            },
          ),
          const SizedBox(height: 16),
          _MenuCard(
            icon: Icons.history_rounded,
            label: 'Quote History',
            subtitle: 'View all quotes & projects',
            color: const Color(0xFF1565C0),
            onTap: () {
              if (onNavigate != null) {
                onNavigate!(_AppShellHistoryScreen());
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }
}

// ── Web Home Shell ────────────────────────────────────────────────────────────

class _WebHomeShell extends StatelessWidget {
  final String userName;
  final String userRole;
  final int selectedIndex;
  final ValueChanged<int> onNavTap;
  final List<_NavItemData> navItems;
  final List<Widget> pages;
  final Widget? currentSubPage;
  final VoidCallback? onNavigateBack;
  final VoidCallback onLogout;

  const _WebHomeShell({
    required this.userName, required this.userRole, required this.selectedIndex,
    required this.onNavTap, required this.navItems,
    required this.pages, required this.onLogout,
    this.currentSubPage, this.onNavigateBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark ? const Color(0xFF0F0F0F) : const Color(0xFF1A1A2E);
    final shellBg = isDark ? const Color(0xFF000000) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: shellBg,
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
                      child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
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
                    child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(userName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                    Text(userRole == 'admin' ? 'Administrator' : 'User', 
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
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
                      if (currentSubPage != null && onNavigateBack != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: onNavigateBack,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        currentSubPage != null 
                            ? _getSubPageTitle(currentSubPage!)
                            : navItems[selectedIndex].label, 
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                        )
                      ),
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
                            child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Text(userName, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF1A1A2E))),
                          const SizedBox(width: 4),
                          Text('· ${userRole == 'admin' ? 'Admin' : 'User'}', 
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                        if (currentSubPage != null)
                          MaterialPage(
                            key: const ValueKey('subPage'),
                            child: currentSubPage!,
                          ),
                      ],
                      onPopPage: (route, result) {
                        if (!route.didPop(result)) return false;
                        if (onNavigateBack != null && currentSubPage != null) {
                          onNavigateBack!();
                          return true;
                        }
                        return true;
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

  String _getSubPageTitle(Widget page) {
    if (page is FormSlides) return 'Create Quote';
    if (page is HistoryScreen) return 'Quote History';
    if (page is ProjectsScreen) return 'Projects';
    return 'Page';
  }
}

// ── Mobile Home ──────────────────────────────────────────────────────────────

class _MobileHome extends StatelessWidget {
  final String userName;
  final String userRole;
  final bool isDark;
  final VoidCallback onLogout;

  const _MobileHome({required this.userName, required this.userRole, required this.isDark, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Gradient app bar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFC40000), Color(0xFF8B0000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('SVJM',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Mould & Solutions',
                            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ),
              ),
                titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
            ),
            backgroundColor: const Color(0xFFC40000),
            actions: [
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

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                _NavCard(
                  title: 'Quote Generator',
                  subtitle: 'Create & manage quotes',
                  icon: Image.asset('assets/Quote generator.png', width: 32, height: 32, fit: BoxFit.contain),
                  accentColor: const Color(0xFFC40000),
                  bgColor: isDark ? const Color(0xFF2A1A1A) : const Color(0xFFFFF5F5),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _QuoteMenuScreen())),
                ),

                const SizedBox(height: 12),

                _NavCard(
                  title: 'Projects',
                  subtitle: 'Track live & completed projects',
                  icon: Image.asset('assets/projects.png', width: 32, height: 32, fit: BoxFit.contain),
                  accentColor: const Color(0xFF1565C0),
                  bgColor: isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F6FF),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
                ),

                const SizedBox(height: 12),

                _NavCard(
                  title: 'Archive',
                  subtitle: 'View & restore archived items',
                  icon: const Icon(Icons.archive_rounded, size: 32, color: Color(0xFF555555)),
                  accentColor: const Color(0xFF555555),
                  bgColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen())),
                ),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItemData {
  final String label;
  final IconData icon;
  const _NavItemData(this.label, this.icon);
}

// ── Dashboard Page (web only) ──────────────────────────────────────────────────

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Welcome to SVJM', style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 6),
        Text('Manage your quotes, projects, and business operations.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        const SizedBox(height: 32),
        
        // Quick Actions
        Text('Quick Actions', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : const Color(0xFF1A1A2E))),
        const SizedBox(height: 16),
        
        Wrap(spacing: 12, runSpacing: 12, children: [
          _QuickActionCard('Create Quote', Icons.add_circle_outline, const Color(0xFFC40000), isDark, () {
            // Find the parent HomeScreen and navigate
            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
            homeState?.navigateToSubPage(_AppShellFormSlides());
          }),
          _QuickActionCard('View Projects', Icons.work_outline, const Color(0xFF1565C0), isDark, () {
            // Navigate to projects tab
            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
            homeState?.navigateToProjectsTab();
          }),
          _QuickActionCard('Quote History', Icons.history, const Color(0xFF2E7D32), isDark, () {
            // Find the parent HomeScreen and navigate
            final homeState = context.findAncestorStateOfType<_HomeScreenState>();
            homeState?.navigateToSubPage(_AppShellHistoryScreen());
          }),
        ]),
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

// ── App Shell Wrapper Screens ──────────────────────────────────────────────────

class _AppShellFormSlides extends StatefulWidget {
  @override
  State<_AppShellFormSlides> createState() => _AppShellFormSlidesState();
}

class _AppShellFormSlidesState extends State<_AppShellFormSlides> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  
  // Component form controllers
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _machineController = TextEditingController();
  
  final List<Map<String, String>> _components = [];
  bool _isMachine = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(DateTime.now());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dateController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _subjectController.dispose();
    _componentController.dispose();
    _amountController.dispose();
    _machineController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  void _addComponent() {
    if (_componentController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      setState(() {
        _components.add({
          'description': _componentController.text,
          'amount': _amountController.text,
          if (_isMachine && _machineController.text.isNotEmpty) 'machine': _machineController.text,
        });
        _componentController.clear();
        _amountController.clear();
        _machineController.clear();
        _isMachine = false;
      });
    }
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
    });
  }

  Future<void> _generateQuote() async {
    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one component')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For app shell, we'll navigate back and show success
      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
      homeState?.navigateBack();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote created successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating quote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Page indicator
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index 
                      ? const Color(0xFFC40000) 
                      : Colors.grey.shade300,
                ),
              );
            }),
          ),
        ),
        // Page content
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildPage1(),
              _buildPage2(),
              _buildPage3(),
            ],
          ),
        ),
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentPage > 0)
                ElevatedButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('Previous'),
                ),
              const Spacer(),
              if (_currentPage < 2)
                ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC40000),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next'),
                ),
              if (_currentPage == 2)
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateQuote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC40000),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Generate Quote'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPage1() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _dateController,
            decoration: const InputDecoration(
              labelText: 'Date',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            readOnly: true,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                _dateController.text = _formatDate(date);
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.subject),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Components',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFFC40000),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _componentController,
                    decoration: const InputDecoration(
                      labelText: 'Component Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addComponent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC40000),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Component'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _components.isEmpty
                ? const Center(child: Text('No components added yet'))
                : ListView.builder(
                    itemCount: _components.length,
                    itemBuilder: (context, index) {
                      final component = _components[index];
                      return Card(
                        child: ListTile(
                          title: Text(component['description'] ?? ''),
                          subtitle: Text('₹ ${component['amount']}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeComponent(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppShellHistoryScreen extends StatefulWidget {
  @override
  State<_AppShellHistoryScreen> createState() => _AppShellHistoryScreenState();
}

class _AppShellHistoryScreenState extends State<_AppShellHistoryScreen> {
  List<Map<String, dynamic>> _quotes = [];
  Map<String, List<Map<String, dynamic>>> _groupedQuotes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final draftQuotes = await StorageService.getDraftQuotes();
      final approvedQuotes = await StorageService.getAllProjects();
      
      final allQuotes = [...draftQuotes, ...approvedQuotes];
      final grouped = <String, List<Map<String, dynamic>>>{};
      
      for (final quote in allQuotes) {
        final company = quote['company'] as String;
        if (!grouped.containsKey(company)) {
          grouped[company] = [];
        }
        grouped[company]!.add(quote);
      }

      setState(() {
        _quotes = allQuotes;
        _groupedQuotes = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading quotes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_quotes.isEmpty) {
      return const Center(
        child: Text(
          'No quotes found',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedQuotes.length,
      itemBuilder: (context, index) {
        final company = _groupedQuotes.keys.elementAt(index);
        final quotes = _groupedQuotes[company]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              company,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text('${quotes.length} quote${quotes.length > 1 ? 's' : ''}'),
            children: quotes.map((quote) => _buildQuoteItem(quote)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildQuoteItem(Map<String, dynamic> quote) {
    final status = quote['status'] as String? ?? 'draft';
    final isDraft = status == 'draft';
    final isConfirmed = status == 'confirmed';
    final isCompleted = status == 'completed';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote['subject'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${quote['date'] ?? ''}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDraft)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Draft',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isConfirmed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '✓ Confirmed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '✓ Completed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Company: ${quote['company'] ?? ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}