import 'dart:async';

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'alerts_screen.dart';
import 'media_screen.dart';
import 'sports_screen.dart';
import 'rider_mode_screen.dart';
import 'account_screen.dart';
import '../services/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isRider = false;
  StreamSubscription? _authSubscription;

  final List<Widget> _baseScreens = const [
    HomeScreen(),
    MarketplaceScreen(),
    MediaScreen(),
    SportsScreen(),
    AlertsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadRiderStatus();

    // Keep the guest shell alive after logout. Never replace the whole app
    // with a login screen; only account-required actions should request login.
    _authSubscription = AuthService.instance.authStateChanges.listen((_) {
      _loadRiderStatus(resetToHome: true);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadRiderStatus({bool resetToHome = false}) async {
    final isRider = await AuthService.instance.isOkadaRider();
    if (mounted) {
      setState(() {
        _isRider = isRider;
        if (resetToHome) _currentIndex = 0;
        if (_currentIndex >= (_isRider ? _baseScreens.length + 2 : _baseScreens.length + 1)) {
          _currentIndex = 0;
        }
      });
    }
  }

  List<Widget> get _screens => [
    ..._baseScreens,
    if (_isRider) const RiderModeScreen(),
    const AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final maxIndex = _screens.length - 1;
    final safeIndex = _currentIndex.clamp(0, maxIndex);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: _screens,
      ),
      // ⚠️ REDLINE: if _isRider ever flips false→true→false again while
      // _currentIndex == 5 (user sitting on the Rider tab), _screens
      // shrinks back to 5 items but _currentIndex stays 5 → IndexedStack
      // throws RangeError('index'). In release mode that renders as a
      // blank/grey box with no crash log — exactly the symptom you
      // described. Cheap guard:
      //
      // if (!_isRider && _currentIndex >= _baseScreens.length) {
      //   _currentIndex = 0;
      // }
      //
      // ...called at the top of build(), or clamp it inside setState in
      // _loadRiderStatus. Low-probability trigger (rider status usually
      // only goes false→true), but it's the one path in this file that
      // can actually blow up silently.
      floatingActionButton: _isRider
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RiderModeScreen()),
          );
        },
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.motorcycle),
        label: const Text('Rider Mode'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Directory',
          ),
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Market',
          ),
          const NavigationDestination(
            icon: Icon(Icons.music_video_outlined),
            selectedIcon: Icon(Icons.music_video),
            label: 'Talent',
          ),
          const NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Sports',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          if (_isRider)
            const NavigationDestination(
              icon: Icon(Icons.motorcycle_outlined),
              selectedIcon: Icon(Icons.motorcycle),
              label: 'Rider',
            ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}