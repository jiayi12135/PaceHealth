import 'package:flutter/material.dart';
import '../../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 18) return '🌤️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('PaceHealth')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Text(_greetingEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 8),
              Expanded(child: Text(_greeting, style: Theme.of(context).textTheme.headlineSmall)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Your health companion for steady progress.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, scheme.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your plan is one tap away', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Personalized around your goals, injuries, and equipment.', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Text('💪', style: TextStyle(fontSize: 40)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Quick access', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _QuickCard(emoji: '🍽️', label: 'Log a meal', color: paceHealthAccents[0]),
              _QuickCard(emoji: '🏋️', label: 'Today\'s plan', color: paceHealthAccents[1]),
              _QuickCard(emoji: '📸', label: 'Scan equipment', color: paceHealthAccents[2]),
              _QuickCard(emoji: '💬', label: 'Ask your coach', color: paceHealthAccents[3]),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  const _QuickCard({required this.emoji, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}
