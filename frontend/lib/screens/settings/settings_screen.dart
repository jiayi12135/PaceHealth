import 'package:flutter/material.dart';

import '../../state/profile_store.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ProfileStore store;
  const SettingsScreen({super.key, required this.store});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _reminders = true;
  bool _weeklyProgress = true;
  bool _privateProfile = true;
  bool _metricUnits = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _heading('Notifications'),
            Card(child: Column(children: [
              SwitchListTile(title: const Text('Daily reminders'), subtitle: const Text('Stay on track with your routine'), value: _reminders, onChanged: (value) => setState(() => _reminders = value)),
              const Divider(height: 1, indent: 16),
              SwitchListTile(title: const Text('Weekly progress update'), subtitle: const Text('Receive your weekly health summary'), value: _weeklyProgress, onChanged: (value) => setState(() => _weeklyProgress = value)),
            ])),
            const SizedBox(height: 20),
            _heading('Preferences'),
            Card(child: Column(children: [
              SwitchListTile(title: const Text('Use metric units'), subtitle: Text(_metricUnits ? 'Kilograms and centimetres' : 'Pounds and feet'), value: _metricUnits, onChanged: (value) => setState(() => _metricUnits = value)),
              const Divider(height: 1, indent: 16),
              ListTile(leading: const Icon(Icons.language_outlined), title: const Text('Language'), trailing: const Text('English')),
            ])),
            const SizedBox(height: 20),
            _heading('Privacy & account'),
            Card(child: Column(children: [
              SwitchListTile(title: const Text('Private profile'), subtitle: const Text('Keep your health information private'), value: _privateProfile, onChanged: (value) => setState(() => _privateProfile = value)),
              const Divider(height: 1, indent: 16),
              ListTile(leading: const Icon(Icons.mail_outline), title: const Text('Email'), subtitle: Text(widget.store.email), onTap: () {}),
              const Divider(height: 1, indent: 16),
              ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Sign out', style: TextStyle(color: Colors.red)), onTap: _confirmSignOut),
            ])),
            const SizedBox(height: 16),
            Center(child: Text('PaceHealth v1.0.0', style: TextStyle(color: Colors.grey.shade600))),
          ],
        ),
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      );

  Future<void> _confirmSignOut() async {
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access your health plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (signOut == true && mounted) {
      widget.store.signOut();
      // Explicitly navigate instead of relying only on the reactive home-swap in
      // main.dart — that swap doesn't reliably repaint once routes are pushed on
      // top of the initial route, which is why "Sign out" looked like a no-op.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(store: widget.store)),
        (route) => false,
      );
    }
  }
}
