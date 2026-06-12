import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/data/services/ocr_service.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final OcrService _ocrService = OcrService();
  final _imagePicker = ImagePicker();

  File? _selectedImage;
  bool _isScanning = false;
  OcrResult? _scanResult;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1500,
    );
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _scanResult = null;
      });
      await _scanImage(File(picked.path));
    }
  }

  Future<void> _scanImage(File imageFile) async {
    setState(() => _isScanning = true);
    try {
      final result = await _ocrService.extractTextFromImage(imageFile);
      setState(() => _scanResult = result);
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Scanning failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _useScannedData() {
    if (_scanResult == null) return;
    // Navigate to Add Bill with pre-filled data passed via extra
    context.push('/bills/add', extra: _scanResult);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Receipt Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.document_scanner_rounded,
                      color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Smart OCR Scanner',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        SizedBox(height: 4),
                        Text(
                          'Automatically extract bill details from images',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.2),

            const SizedBox(height: 24),

            // Image area
            GestureDetector(
              onTap: () => _showSourceDialog(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: _selectedImage != null
                      ? null
                      : Theme.of(context)
                          .cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedImage != null
                        ? AppColors.primary
                        : Colors.grey.withOpacity(0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                          if (_isScanning)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                        color: Colors.white),
                                    SizedBox(height: 12),
                                    Text(
                                      'Scanning receipt...',
                                      style: TextStyle(
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _showSourceDialog(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.refresh_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_photo_alternate_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to scan a receipt',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Camera or Gallery',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // Scan options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Scan results
            if (_scanResult != null) ...[
              const SizedBox(height: 24),
              Text('Extracted Information',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ResultsCard(result: _scanResult!),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: _useScannedData,
                text: 'Create Bill with This Data',
                icon: Icons.receipt_long_rounded,
              ),
            ],

            if (_selectedImage == null) ...[
              const SizedBox(height: 32),
              _HowItWorksSection(),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.secondary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsCard extends StatelessWidget {
  final OcrResult result;
  const _ResultsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isLowConfidence = result.confidenceScore < 0.80;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowConfidence ? Colors.amber.withOpacity(0.5) : AppColors.primary.withOpacity(0.2),
          width: isLowConfidence ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // OCR Confidence Score Widget
          Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: isLowConfidence
        ? Colors.amber.withOpacity(0.1)
        : AppColors.successLight,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    children: [
      Icon(
        isLowConfidence
            ? Icons.warning_amber_rounded
            : Icons.check_circle_rounded,
        color: isLowConfidence
            ? Colors.orange
            : AppColors.success,
        size: 16,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          isLowConfidence
              ? 'Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}% (Low - manual check recommended)'
              : 'OCR Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: isLowConfidence
                ? Colors.orange[800]
                : AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (result.storeName != null)
            _ResultRow(
                label: 'Store',
                value: result.storeName!,
                icon: Icons.store_rounded),
          if (result.productName != null)
            _ResultRow(
                label: 'Product',
                value: result.productName!,
                icon: Icons.inventory_2_rounded),
          if (result.amount != null)
            _ResultRow(
                label: 'Amount',
                value: '₹${result.amount!.toStringAsFixed(2)}',
                icon: Icons.currency_rupee_rounded),
          if (result.date != null)
            _ResultRow(
                label: 'Date',
                value:
                    '${result.date!.day}/${result.date!.month}/${result.date!.year}',
                icon: Icons.calendar_today_rounded),
          if (result.gstNumber != null)
            _ResultRow(
                label: 'GST No.',
                value: result.gstNumber!,
                icon: Icons.numbers_rounded),
          if (result.category != null)
            _ResultRow(
                label: 'Category',
                value: result.category!,
                icon: Icons.category_rounded),
          if (result.hasWarranty == true)
            _ResultRow(
                label: 'Warranty',
                value: result.warrantyInfo ?? 'Yes',
                icon: Icons.verified_rounded),
          const Divider(height: 20),
          _OCRTextSection(text: result.fullText),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ResultRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AppColors.success),
        ],
      ),
    );
  }
}

class _OCRTextSection extends StatefulWidget {
  final String text;
  const _OCRTextSection({required this.text});

  @override
  State<_OCRTextSection> createState() => _OCRTextSectionState();
}

class _OCRTextSectionState extends State<_OCRTextSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text('Raw OCR Text',
                  style: Theme.of(context).textTheme.labelMedium),
              const Spacer(),
              Icon(
                _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                size: 18,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.text,
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.6),
              maxLines: 20,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _HowItWorksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How it works',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...[
          ('📷', 'Take or upload a photo of your receipt'),
          ('🔍', 'AI scans and extracts key information'),
          ('✅', 'Review and confirm the extracted data'),
          ('💾', 'Bill is automatically saved with details'),
        ].map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.$2,
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
