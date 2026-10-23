import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_car_wash_outlined),
            selectedIcon: Icon(Icons.local_car_wash),
            label: 'Moji zahtevi',
          ),
          NavigationDestination(icon: Icon(Icons.sell_outlined), selectedIcon: Icon(Icons.sell), label: 'Cenovnik'),
        ],
      ),
    );
  }
}
