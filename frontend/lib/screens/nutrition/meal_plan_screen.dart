import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';
import '../../widgets/app_toast.dart';

/// "Get meal ideas":输入(或拍照识别)现有食材+忌口,AI给几道食谱建议。跟Plan/Report
/// 不一样,这里刻意不落库——每次都是按当下手头食材现生成的建议,吃完/食材变了就该
/// 重新生成,不是一份要长期保留的"计划"。
class MealPlanScreen extends StatefulWidget {
  final ProfileStore store;
  const MealPlanScreen({super.key, required this.store});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _ingredientController = TextEditingController();
  final _restrictionController = TextEditingController();
  final List<String> _ingredients = [];
  final List<String> _restrictions = [];
  bool _includeProgress = true;
  bool _scanning = false;
  bool _generating = false;
  String? _error;
  MealPlanResult? _result;

  @override
  void dispose() {
    _ingredientController.dispose();
    _restrictionController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_ingredients.contains(text)) _ingredients.add(text);
      _ingredientController.clear();
    });
  }

  void _addRestriction() {
    final text = _restrictionController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_restrictions.contains(text)) _restrictions.add(text);
      _restrictionController.clear();
    });
  }

  Future<void> _scanIngredients(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;
    setState(() => _scanning = true);
    try {
      final result = await _api.identifyIngredients(imageFile: File(picked.path), accessToken: widget.store.accessToken);
      if (!result.recognized || result.ingredients.isEmpty) {
        if (mounted) showAppToast(context, result.notRecognizedMessage ?? "Couldn't recognize any ingredients.", isError: true);
      } else {
        var added = 0;
        setState(() {
          for (final ing in result.ingredients) {
            if (!_ingredients.contains(ing.name)) {
              _ingredients.add(ing.name);
              added++;
            }
          }
        });
        if (mounted) showAppToast(context, 'Added $added ingredient${added == 1 ? '' : 's'} from the photo.');
      }
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't scan that photo. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _openScanSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanIngredients(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanIngredients(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final result = await _api.generateMealPlan(
        availableIngredients: _ingredients,
        dietaryRestrictions: _restrictions,
        includeRecentProgress: _includeProgress,
        accessToken: widget.store.accessToken,
      );
      if (mounted) setState(() => _result = result);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't get meal ideas. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal ideas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text('Ingredients you have', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text("Optional — leave empty and we'll suggest common healthy ingredients.", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 10),
          if (_ingredients.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final ing in _ingredients) Chip(label: Text(ing), onDeleted: () => setState(() => _ingredients.remove(ing)))],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredientController,
                  decoration: const InputDecoration(hintText: 'e.g. chicken breast'),
                  onSubmitted: (_) => _addIngredient(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addIngredient, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scanning ? null : _openScanSheet,
            icon: _scanning
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt_outlined),
            label: Text(_scanning ? 'Scanning…' : 'Scan ingredients instead'),
          ),
          const SizedBox(height: 24),
          Text('Dietary restrictions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (_restrictions.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final r in _restrictions) Chip(label: Text(r), onDeleted: () => setState(() => _restrictions.remove(r)))],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _restrictionController,
                  decoration: const InputDecoration(hintText: 'e.g. vegetarian, no shellfish'),
                  onSubmitted: (_) => _addRestriction(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addRestriction, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Adjust for my recent progress'),
            subtitle: Text("Uses this week's weight trend to fine-tune calories", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            value: _includeProgress,
            onChanged: (v) => setState(() => _includeProgress = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Thinking…' : (_result == null ? 'Get meal ideas' : 'Get new ideas')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text(_error!))]),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 28),
            _MealPlanResultView(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _MealPlanResultView extends StatelessWidget {
  final MealPlanResult result;
  const _MealPlanResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(result.planName, style: Theme.of(context).textTheme.titleLarge),
        if (result.dailyCalorieTarget != null) ...[
          const SizedBox(height: 4),
          Text('~${result.dailyCalorieTarget} kcal/day target', style: TextStyle(color: Colors.grey.shade600)),
        ],
        if (result.adjustmentNote != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(result.adjustmentNote!, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        ...result.recipes.map((r) => _RecipeCard(recipe: r)),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  const _RecipeCard({required this.recipe});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(recipe.mealType, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.secondary)),
                  ),
                  const Spacer(),
                  if (recipe.estimatedCalories != null) Text('${recipe.estimatedCalories} kcal', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(recipe.recipeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (recipe.ingredientsUsed.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(recipe.ingredientsUsed.join(', '), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Text(recipe.instructions, style: const TextStyle(height: 1.4)),
              if (recipe.estimatedProteinG != null) ...[
                const SizedBox(height: 6),
                Text('~${recipe.estimatedProteinG!.toStringAsFixed(0)}g protein', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
              if (recipe.reason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(recipe.reason, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 12)),
              ],
            ],
          ),
        ),
      );
}
