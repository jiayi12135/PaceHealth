import 'package:flutter/material.dart';
import '../../state/profile_store.dart';
import '../profile/profile_area_screen.dart';
import '../home/home_screen.dart';
import '../placeholder/placeholder_screen.dart';
class AppShell extends StatefulWidget { final ProfileStore store; const AppShell({super.key, required this.store}); @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> { int index = 2; @override Widget build(BuildContext context) { final pages = [const PlaceholderScreen(title: 'Nutrition', icon: Icons.restaurant), const PlaceholderScreen(title: 'Plan', icon: Icons.fitness_center), const HomeScreen(), ProfileAreaScreen(store: widget.store)]; return Scaffold(body: pages[index], bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: const [NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Nutrition'), NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Plan'), NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'), NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile')])); } }
