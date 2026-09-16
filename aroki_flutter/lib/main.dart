import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/aroki_theme.dart';
import 'state/aroki_app_state.dart';
import 'screens/catalog_search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_sources_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ArokiAppState(),
      child: const ArokiApp(),
    ),
  );
}

class ArokiApp extends StatelessWidget {
  const ArokiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AROKI',
      debugShowCheckedModeBanner: false,
      theme: ArokiTheme.darkTheme,
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CatalogSearchScreen(),
    const LibraryScreen(),
    const ProfileSourcesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _GlassNavBar(
                  currentIndex: _currentIndex,
                  onTap: (index) => setState(() => _currentIndex = index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _navItems = [
  _NavBarItem(
    icon: CupertinoIcons.compass,
    activeIcon: CupertinoIcons.compass_fill,
    label: 'Discover',
  ),
  _NavBarItem(
    icon: CupertinoIcons.play_rectangle,
    activeIcon: CupertinoIcons.play_rectangle_fill,
    label: 'Library',
  ),
  _NavBarItem(
    icon: CupertinoIcons.person_crop_circle,
    activeIcon: CupertinoIcons.person_crop_circle_fill,
    label: 'Profile',
  ),
];

class _NavBarItem {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: ArokiTheme.glassOverlay,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: ArokiTheme.accent.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              for (int i = 0; i < _navItems.length; i++)
                Expanded(
                  child: _buildItem(i),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final isSelected = index == currentIndex;
    final item = _navItems[index];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected
              ? ArokiTheme.accent.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: ArokiTheme.accent.withValues(alpha: 0.25),
                  width: 0.8,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 20,
              color: isSelected
                  ? ArokiTheme.accent
                  : ArokiTheme.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? ArokiTheme.accent
                    : ArokiTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}