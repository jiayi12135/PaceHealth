import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';
import 'meal_plan_screen.dart';

/// Nutrition tab: 拍照/上传一份食物的照片,AI估算大概的热量和营养成分,
/// 累计成今日已记录的食物列表+总热量。
class NutritionScreen extends StatefulWidget {
  final ProfileStore store;
  const NutritionScreen({super.key, required this.store});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  bool _loadingLog = true;
  bool _scanning = false;
  String? _error;
  DailyFoodLog _log = const DailyFoodLog(date: '', totalCalories: 0, scans: []);

  @override
  void initState() {
    super.initState();
    _loadLog();
  }

  Future<void> _loadLog() async {
    setState(() => _loadingLog = true);
    try {
      final log = await _api.fetchTodayFoodLog(accessToken: widget.store.accessToken);
      if (mounted) setState(() => _log = log);
    } catch (_) {
      // 加载历史记录失败不阻断页面使用,用户还是可以扫新的食物,只是看不到之前的记录
    } finally {
      if (mounted) setState(() => _loadingLog = false);
    }
  }

  Future<void> _scanFood(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;

    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final result = await _api.scanFood(imageFile: File(picked.path), accessToken: widget.store.accessToken);
      if (!result.recognized) {
        setState(() => _error = result.notRecognizedMessage ?? "Couldn't recognize this food. Try a clearer photo.");
        return;
      }
      // 扫描成功后直接把新记录加到列表最前面、更新总热量,不用重新拉一次今日日志。
      setState(() {
        _log = DailyFoodLog(
          date: _log.date,
          totalCalories: _log.totalCalories + (result.estimatedCalories ?? 0),
          scans: [result, ..._log.scans],
        );
      });
    } catch (e) {
      setState(() => _error = "Couldn't estimate this food. Please try again.");
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  /// 删掉扫错/重复的一条记录。先打backend确认删成功了再更新本地列表和总热量——
  /// 不用Dismissible那种"先移除再万一失败要塞回去"的写法,直接确认过了再改状态更简单。
  Future<bool> _deleteScan(FoodScanResult scan) async {
    if (scan.scanId == null) return false;
    try {
      await _api.deleteFoodScan(scanId: scan.scanId!, accessToken: widget.store.accessToken);
      if (mounted) {
        setState(() {
          _log = DailyFoodLog(
            date: _log.date,
            totalCalories: _log.totalCalories - (scan.estimatedCalories ?? 0),
            scans: _log.scans.where((s) => s.scanId != scan.scanId).toList(),
          );
        });
      }
      return true;
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't delete that entry. Please try again.", isError: true);
      return false;
    }
  }

  void _openMealIdeas() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MealPlanScreen(store: widget.store)));
  }

  void _openScanSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _scanFood(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _scanFood(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      body: RefreshIndicator(
        onRefresh: _loadLog,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _TotalCaloriesCard(totalCalories: _log.totalCalories, mealCount: _log.scans.length, loading: _loadingLog),
            if (!_loadingLog && _log.scans.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MacroTotalsRow(scans: _log.scans),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text(_error!))]),
              ),
            ],
            const SizedBox(height: 16),
            Text(_log.scans.isEmpty ? 'Get started' : 'Food tools', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _FoodActionCard(
                    onTap: _scanning ? null : _openScanSheet,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                    accentColor: Theme.of(context).colorScheme.primary,
                    leading: _scanning
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                    title: _scanning ? 'Scanning…' : 'Scan meal',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FoodActionCard(
                    onTap: _openMealIdeas,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
                    accentColor: Theme.of(context).colorScheme.primary,
                    leading: const Icon(Icons.menu_book_outlined, size: 18),
                    title: 'Meal planner',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text("Today's meals", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingLog)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
            else if (_log.scans.isEmpty)
              Card(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                  child: Column(
                    children: [
                      Text('No meals logged today', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 5),
                      Text(
                        'Scan a meal to start building your daily summary.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._log.scans.map((scan) => _FoodScanTile(key: ValueKey(scan.scanId ?? scan.foodName), scan: scan, onDelete: () => _deleteScan(scan))),
          ],
        ),
      ),
    );
  }
}

class _FoodActionCard extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color accentColor;
  final Widget leading;
  final String title;

  const _FoodActionCard({
    required this.onTap,
    required this.backgroundColor,
    required this.accentColor,
    required this.leading,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(data: IconThemeData(color: accentColor), child: leading),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _TotalCaloriesCard extends StatelessWidget {
  final int totalCalories;
  final int mealCount;
  final bool loading;
  const _TotalCaloriesCard({required this.totalCalories, required this.mealCount, required this.loading});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TODAY\'S INTAKE', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(loading ? '…' : '$totalCalories', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1)),
                        const SizedBox(width: 5),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('kcal', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(16)),
                child: Text(
                  loading ? '…' : '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
}
class _MacroTotalsRow extends StatelessWidget {
  final List<FoodScanResult> scans;
  const _MacroTotalsRow({required this.scans});

  @override
  Widget build(BuildContext context) {
    // 纯前端把已经拿到的每条scan的macro加起来,不是另外问AI要一个"今日总营养"——
    // 跟整个app"数字由代码算"的原则一致。
    final protein = scans.fold<double>(0, (sum, s) => sum + (s.estimatedProteinG ?? 0));
    final carbs = scans.fold<double>(0, (sum, s) => sum + (s.estimatedCarbsG ?? 0));
    final fat = scans.fold<double>(0, (sum, s) => sum + (s.estimatedFatG ?? 0));
    return Row(
      children: [
        Expanded(child: _MacroChip(label: 'Protein', value: protein, color: Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _MacroChip(label: 'Carbs', value: carbs, color: Colors.amber.shade800)),
        const SizedBox(width: 8),
        Expanded(child: _MacroChip(label: 'Fat', value: fat, color: Colors.purple)),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('${value.round()}g', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );
}

class _FoodScanTile extends StatelessWidget {
  final FoodScanResult scan;
  final Future<bool> Function() onDelete;
  const _FoodScanTile({super.key, required this.scan, required this.onDelete});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: key!,
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.restaurant, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scan.foodName ?? 'Unknown food', style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (scan.portionEstimate != null) Text(scan.portionEstimate!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (scan.estimatedProteinG != null || scan.estimatedCarbsG != null || scan.estimatedFatG != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'P ${scan.estimatedProteinG?.toStringAsFixed(0) ?? '–'}g · C ${scan.estimatedCarbsG?.toStringAsFixed(0) ?? '–'}g · F ${scan.estimatedFatG?.toStringAsFixed(0) ?? '–'}g',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              if (scan.estimatedCalories != null)
                Text('${scan.estimatedCalories} kcal', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        ),
      );
}
