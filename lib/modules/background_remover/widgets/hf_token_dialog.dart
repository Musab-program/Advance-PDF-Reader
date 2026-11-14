import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/storage_service.dart';
import '../services/hugging_face_bg_remover_service.dart';

class HfTokenDialog extends StatefulWidget {
  const HfTokenDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const HfTokenDialog(),
    );
  }

  @override
  State<HfTokenDialog> createState() => _HfTokenDialogState();
}

class _HfTokenDialogState extends State<HfTokenDialog> {
  final StorageService _storageService = Get.find<StorageService>();
  late final TextEditingController _tokenController;
  bool _isTesting = false;
  HfTokenTestResult? _testResult;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(
      text: _storageService.getHuggingFaceToken(),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      Get.snackbar('error'.tr, 'token_hint'.tr);
      return;
    }
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await HuggingFaceBgRemoverService.testToken(token);
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult = res;
    });
  }

  void _saveToken() {
    final token = _tokenController.text.trim();
    _storageService.saveHuggingFaceToken(token);
    Get.back();
    Get.snackbar(
      'success'.tr,
      'token_save_success'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade800,
      colorText: Colors.white,
    );
  }

  Future<void> _openTokenSettings() async {
    final uri = Uri.parse('https://huggingface.co/settings/tokens');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardBg,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB020).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key_rounded, color: Color(0xFFFFB020), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'token_settings'.tr,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Token TextField
              TextField(
                controller: _tokenController,
                obscureText: false,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Hugging Face Access Token',
                  hintText: 'hf_xxxxxxxxxxxxxxxxxxxx',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons: Test & Settings Link
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: _isTesting ? null : _runTest,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_outlined, size: 16),
                      label: Text('test_token'.tr, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    ),
                    onPressed: _openTokenSettings,
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('موقع التوكن', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),

              // Test Result Feedback Card
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult!.isValid
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _testResult!.isValid
                          ? Colors.green.shade600
                          : Colors.redAccent,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _testResult!.isValid
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: _testResult!.isValid
                                ? Colors.green
                                : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!.isValid
                                  ? 'token_valid'.tr
                                  : (_testResult!.errorMessage ?? 'تعذر التحقق من المفتاح'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _testResult!.isValid
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_testResult!.isValid && _testResult!.username != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الحساب المتصل: ${_testResult!.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Save Button
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _saveToken,
                child: Text('apply'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
