import 'package:flutter/material.dart';
import 'package:pathpilot/screens/navigation.dart';
import 'package:pathpilot/screens/settings.dart';
import 'package:pathpilot/screens/onboarding.dart';
import 'package:pathpilot/screens/home.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  // Allows child widgets to access MainNav and call goToPage()
  static _MainNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavState>();

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    NavigationPage(),
    SettingsPage(),
    OnboardingPage(),
  ];

  /// External function that child widgets can call:
  /// MainNav.of(context)?.goToPage(1);
  void goToPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// For tapping nav bar icons
  void _onItemTapped(int index) {
    goToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF1566EB),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: const Color(0xFF232323),
        type: BottomNavigationBarType.fixed,
        elevation: 5,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            activeIcon: Icon(Icons.info),
            label: 'Onboarding',
          ),
        ],
      ),
    );
  }
}
