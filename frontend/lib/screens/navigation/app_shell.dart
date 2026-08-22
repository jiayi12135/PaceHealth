import 'package:flutter/material.dart';
import '../../state/profile_store.dart';
import '../../state/ai_assistant_store.dart';
import '../../widgets/ai_bubble.dart';
import '../profile/profile_area_screen.dart';
import '../home/home_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../plan/plan_screen.dart';

class AppShell extends StatefulWidget {
  final ProfileStore store;
  // 默认停在Home(index 2)。问卷刚填完那次想直接停在Plan tab(index 1),
  // 让用户一进来就看到刚生成好的计划,不用自己再点一次。
  final int initialIndex;
  const AppShell({super.key, required this.store, this.initialIndex = 2});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index = widget.initialIndex;
  final AiAssistantStore _aiStore = AiAssistantStore();

  @override
  void initState() {
    super.initState();
    _aiStore.load(); // 读取上次保存的AI名字/头像(本地存储)
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      NutritionScreen(store: widget.store),
      PlanScreen(store: widget.store),
      const HomeScreen(),
      ProfileAreaScreen(store: widget.store, aiStore: _aiStore),
    ];

    return AnimatedBuilder(
      animation: _aiStore,
      builder: (context, _) => Stack(
        children: [
          Scaffold(
            body: pages[index],
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => index = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.restaurant_outlined), selectedIcon: Icon(Icons.restaurant), label: 'Nutrition'),
                NavigationDestination(icon: Icon(Icons.fitness_center_outlined), selectedIcon: Icon(Icons.fitness_center), label: 'Plan'),
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
              ],
            ),
          ),
          // 悬浮气泡,盖在所有tab上面,长按可以打开自定义设置,点一下打开聊天
          AiBubble(aiStore: _aiStore, profileStore: widget.store),
        ],
      ),
    );
  }
}
