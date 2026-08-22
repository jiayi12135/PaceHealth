import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';
import '../../state/profile_store.dart';

/// 拍照/选图识别食材(冰箱/菜篮子)。跟EquipmentScanScreen是同样的结构。
class IngredientScanScreen extends StatefulWidget {
  final ProfileStore? store;
  const IngredientScanScreen({super.key, this.store});

  @override
  State<IngredientScanScreen> createState() => _IngredientScanScreenState();
}

class _IngredientScanScreenState extends State<IngredientScanScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  File? _imageFile;
  bool _loading = false;
  IngredientScanResult? _result;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1600);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _result = null;
      _error = null;
      _loading = true;
    });

    try {
      final result = await _api.identifyIngredients(imageFile: _imageFile!, accessToken: widget.store?.accessToken);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = "Couldn't identify the ingredients. Please try again.");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Ingredients')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_imageFile != null)
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, height: 220, width: double.infinity, fit: BoxFit.cover))
          else
            Container(
              height: 220,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.kitchen_outlined, size: 56, color: Colors.grey)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: _loading ? null : () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Take photo'))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _loading ? null : () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Choose photo'))),
            ],
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_result != null) _IngredientResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _IngredientResultCard extends StatelessWidget {
  final IngredientScanResult result;
  const _IngredientResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.recognized || result.ingredients.isEmpty) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(result.notRecognizedMessage ?? "Couldn't recognize any ingredients. Try a clearer photo.")),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detected ingredients', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...result.ingredients.map((i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.name)),
                      if (i.quantity != null) Text(i.quantity!, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Text(
              'These can be used as available ingredients when generating a meal plan.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
