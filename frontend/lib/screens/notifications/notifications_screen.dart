import 'package:flutter/material.dart';
import '../../state/profile_store.dart';

class NotificationsScreen extends StatelessWidget {
  final ProfileStore store;
  const NotificationsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final hasPlan = store.plan != null;
    final notifications = <Map<String, dynamic>>[
      if (hasPlan)
        {'icon': Icons.fitness_center, 'title': 'Your fitness plan is ready', 'text': 'Open Plan to view your recommended workouts.'},
      {'icon': Icons.monitor_weight_outlined, 'title': 'Keep tracking your progress', 'text': 'Record your weight regularly to see your progress.'},
      {'icon': Icons.wb_sunny_outlined, 'title': 'Stay consistent', 'text': 'A small step today can help you reach your health goals.'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Icon(item['icon'] as IconData)),
              title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text(item['text'] as String)),
            ),
          );
        },
      ),
    );
  }
}
