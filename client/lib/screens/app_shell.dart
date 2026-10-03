import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'map_screen.dart';
import 'rooms_screen.dart';

// The frame around the app: a bar at the bottom to switch between
// the Rooms list and the Map.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps both screens alive, so the map doesn't reset
      // every time you switch tabs.
      body: IndexedStack(
        index: selectedTab,
        children: const [RoomsScreen(), MapScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        indicatorColor: AppColors.lilac,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
        ],
      ),
    );
  }
}
