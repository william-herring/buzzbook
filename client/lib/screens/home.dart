import 'package:client/screens/map_screen.dart';
import 'package:client/screens/rooms_screen.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Replace these placeholders with your real pages.
  late final List<Widget> _tabs = const [
    RoomsScreen(),
    MapScreen(),
    _PlaceholderTab(label: 'Me', icon: Icons.person),
  ];

  void _onScanQr() {
    // TODO: open QR scanner (e.g. with the mobile_scanner package).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR scanner coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset('assets/images/logo.png', height: 40),
      ),
      // IndexedStack keeps each tab's state when switching between them.
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _onScanQr,
        tooltip: 'Scan QR code',
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'List',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}