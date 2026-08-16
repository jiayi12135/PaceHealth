import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ai_models.dart';
import '../../services/api_service.dart';

/// 拍照/选图识别健身器材。
class EquipmentScanScreen extends StatefulWidget {
  const EquipmentScanScreen({super.key});

  @override
  State<EquipmentScanScreen> createState() => _EquipmentScanScreenState();
}

class _EquipmentScanScreenState extends State<EquipmentScanScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  File? _imageFile;
  bool _loading = false;
  EquipmentResult? _result;
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
      final result = await _api.identifyEquipment(userId: 'demo-user', imageFile: _imageFile!);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = "Couldn't identify the equipment. Please try again.");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Equipment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_imageFile != null)
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_imageFile!, height: 220, width: double.infinity, fit: BoxFit.cover))
          else
            Container(
              height: 220,
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Icon(Icons.fitness_center, size: 56, color: Colors.grey)),
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
          if (_result != null) _EquipmentResultCard(result: _result!),
        ],
      ),
    );
  }
}

class _EquipmentResultCard extends StatelessWidget {
  final EquipmentResult result;
  const _EquipmentResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.recognized) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(child: Text(result.notRecognizedMessage ?? "Couldn't recognize this equipment. Try a clearer photo.")),
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
            Text(result.equipmentName ?? '', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (result.description != null) Text(result.description!),
            if (result.targetMuscles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: result.targetMuscles.map((m) => Chip(label: Text(m))).toList()),
            ],
            if (result.usageInstructions != null) ...[
              const SizedBox(height: 16),
              const Text('How to use', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(result.usageInstructions!),
            ],
            if (result.safetyNotes != null) ...[
              const SizedBox(height: 16),
              const Text('Safety notes', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(result.safetyNotes!),
            ],
            if (result.personalizedWarning != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(result.personalizedWarning!, style: const TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
