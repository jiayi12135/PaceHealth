import 'package:flutter/material.dart';

import '../../state/ai_assistant_store.dart';
import '../../state/profile_store.dart';
import '../ai/ai_customize_screen.dart';
import '../equipment/equipment_scan_screen.dart';
import '../personal_information/personal_information_screen.dart';
import '../settings/settings_screen.dart';

class ProfileAreaScreen extends StatelessWidget {
  final ProfileStore store;
  final AiAssistantStore aiStore;
  const ProfileAreaScreen({super.key, required this.store, required this.aiStore});

  @override
  Widget build(BuildContext context) {
    final name = store.profile.name.isEmpty ? 'PaceHealth member' : store.profile.name;
    final subtitle = store.email.isEmpty ? 'Complete your profile to personalize your plan' : store.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Your health', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(icon: Icons.person_outline, title: 'Personal information', subtitle: 'Your health and fitness details', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PersonalInformationScreen(store: store)))),
            _MenuItem(icon: Icons.camera_alt_outlined, title: 'Scan equipment', subtitle: 'Identify gym equipment from a photo', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EquipmentScanScreen(store: store)))),
          ]),
          const SizedBox(height: 20),
          Text('Preferences', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _MenuCard(children: [
            _MenuItem(icon: Icons.smart_toy_outlined, title: 'Customize AI assistant', subtitle: 'Give your AI a name and icon', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiCustomizeScreen(aiStore: aiStore)))),
            _MenuItem(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Notifications, privacy, and account', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(store: store)))),
          ]),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> children;
  const _MenuCard({required this.children});
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: List.generate(children.length, (index) => Column(children: [children[index], if (index < children.length - 1) const Divider(height: 1, indent: 64)]))),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap);
}
