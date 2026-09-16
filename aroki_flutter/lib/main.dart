import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/aroki_theme.dart';
import 'state/aroki_app_state.dart';
import 'screens/catalog_search_screen.dart';
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
    const Center(
        child: Text('Library & History Screen',
            style: TextStyle(color: Colors.white))),
    const ProfileSourcesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass_fill),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.play_rectangle_fill),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_crop_circle_fill),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
