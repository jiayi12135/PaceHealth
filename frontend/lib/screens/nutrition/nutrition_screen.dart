import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _openScanSheet,
        icon: _scanning ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.camera_alt),
        label: Text(_scanning ? 'Estimating…' : 'Scan food'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadLog,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            _TotalCaloriesCard(totalCalories: _log.totalCalories, loading: _loadingLog),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text(_error!))]),
              ),
            ],
            const SizedBox(height: 20),
            Text("Today's scans", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingLog)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
            else if (_log.scans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No food scanned yet today. Tap "Scan food" to log a meal.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))),
              )
            else
              ..._log.scans.map((scan) => _FoodScanTile(scan: scan)),
          ],
        ),
      ),
    );
  }
}

class _TotalCaloriesCard extends StatelessWidget {
  final int totalCalories;
  final bool loading;
  const _TotalCaloriesCard({required this.totalCalories, required this.loading});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s calories', style: Theme.of(context).textTheme.bodyMedium),
                  Text(loading ? '…' : '$totalCalories kcal', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      );
}

class _FoodScanTile extends StatelessWidget {
  final FoodScanResult scan;
  const _FoodScanTile({required this.scan});

  @override
  Widget build(BuildContext context) => Card(
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
      );
}
