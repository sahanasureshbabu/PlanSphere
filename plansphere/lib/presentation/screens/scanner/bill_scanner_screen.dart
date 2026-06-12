import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/glass_card.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/services/ocr_service.dart';

class BillScannerScreen extends ConsumerStatefulWidget {
  const BillScannerScreen({super.key});

  @override
  ConsumerState<BillScannerScreen> createState() => _BillScannerScreenState();
}

class _BillScannerScreenState extends ConsumerState<BillScannerScreen> {
  final OcrService _ocrService = OcrService();
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  File? _selectedImage;
  bool _isScanning = false;
  OcrResult? _scanResult;

  // Review Form Controllers
  final _productNameCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _billNumberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _brandCtrl = TextEditingController(text: 'Generic');
  final _descCtrl = TextEditingController();
  final _emiAmountCtrl = TextEditingController();
  final _emiDurationCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  DateTime _purchaseDate = DateTime.now();
  bool _hasWarranty = false;
  int _warrantyMonths = 12;

  bool _emiEnabled = false;
  double _ocrConfidenceScore = 1.0;
  bool _isSaving = false;

  @override
  void dispose() {
    _ocrService.dispose();
    _productNameCtrl.dispose();
    _storeNameCtrl.dispose();
    _billNumberCtrl.dispose();
    _amountCtrl.dispose();
    _taxCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _emiAmountCtrl.dispose();
    _emiDurationCtrl.dispose();
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
      setState(() {
        _scanResult = result;
        _ocrConfidenceScore = result.confidenceScore;

        // Populate controllers
        _productNameCtrl.text = result.productName ?? '';
        _storeNameCtrl.text = result.storeName ?? '';
        _billNumberCtrl.text = result.billNumber ?? '';
        _amountCtrl.text = result.amount?.toStringAsFixed(0) ?? '';
        _taxCtrl.text = result.taxAmount?.toStringAsFixed(0) ?? '';
        _selectedCategory = result.category ?? 'Electronics';
        _purchaseDate = result.date ?? DateTime.now();
        _hasWarranty = result.hasWarranty ?? false;
        if (result.warrantyMonths != null) {
          _warrantyMonths = result.warrantyMonths!;
        }
        _emiEnabled = result.emiEnabled;
        _emiAmountCtrl.text = result.emiAmount > 0 ? result.emiAmount.toStringAsFixed(0) : '';
        _emiDurationCtrl.text = result.emiDuration;

        if (result.warrantyInfo != null) {
          _descCtrl.text = 'Warranty: ${result.warrantyInfo}';
        } else {
          _descCtrl.clear();
        }
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Scanning failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  DateTime get _warrantyExpiryDate =>
      _purchaseDate.copyWith(month: _purchaseDate.month + _warrantyMonths);

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      AppSnackbar.showError(context, 'No scanned receipt image selected.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      final bill = BillModel(
        id: '',
        userId: user.uid,
        title: _productNameCtrl.text.trim().isNotEmpty 
            ? _productNameCtrl.text.trim() 
            : (_storeNameCtrl.text.trim().isNotEmpty ? '${_storeNameCtrl.text.trim()} Purchase' : 'Scanned Bill'),
        category: _selectedCategory,
        recordType: _hasWarranty ? 'Warranty Bill' : 'Standard Bill',
        purchaseDate: _purchaseDate,
        amount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0,
        storeName: _storeNameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        tags: ['scanned', _selectedCategory.toLowerCase()],
        hasWarranty: _hasWarranty,
        warrantyDurationMonths: _hasWarranty ? _warrantyMonths : null,
        warrantyExpiryDate: _hasWarranty ? _warrantyExpiryDate : null,
        isDuplicate: false,
        ocrConfidenceScore: _ocrConfidenceScore,
        claimStatus: 'none',
        serviceHistory: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // New Fields
        billNumber: _billNumberCtrl.text.trim(),
        taxAmount: double.tryParse(_taxCtrl.text.replaceAll(',', '')),
        emiEnabled: _emiEnabled,
        emiAmount: _emiEnabled ? (double.tryParse(_emiAmountCtrl.text.replaceAll(',', '')) ?? 0.0) : 0.0,
        emiDuration: _emiEnabled ? _emiDurationCtrl.text.trim() : 'No EMI',
      );

      final id = await ref.read(billCrudProvider.notifier).addBill(
        bill: bill,
        imageFile: _selectedImage,
      );

      if (id != null) {
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Bill saved successfully!');
          context.pop();
        }
      } else {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to save bill. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error saving bill: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetScanner() {
    setState(() {
      _selectedImage = null;
      _scanResult = null;
      _isScanning = false;
      _isSaving = false;
      _productNameCtrl.clear();
      _storeNameCtrl.clear();
      _billNumberCtrl.clear();
      _amountCtrl.clear();
      _taxCtrl.clear();
      _brandCtrl.text = 'Generic';
      _descCtrl.clear();
      _emiAmountCtrl.clear();
      _emiDurationCtrl.clear();
      _emiEnabled = false;
      _hasWarranty = false;
      _warrantyMonths = 12;
      _ocrConfidenceScore = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Automatic Bill Scanner'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F0E1A), const Color(0xFF1E1C38)]
                : [const Color(0xFFF3F5FA), const Color(0xFFE2E7F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedImage == null) ...[
                // Welcome / Info header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.psychology_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Bill Extractor',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Snap a photo or upload a receipt to automatically scan product, store, dates, prices, tax, and EMI info.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().slideY(begin: -0.1),
                const SizedBox(height: 32),

                // Selection Box
                Center(
                  child: GestureDetector(
                    onTap: () => _showSourceBottomSheet(),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.document_scanner_rounded,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Click to Scan Receipt',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports Camera capture or Gallery uploads',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 32),
              ] else ...[
                // Image preview & scanning status
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (_isScanning)
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Reading bill content with AI OCR...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_isScanning && _scanResult != null) ...[
                  // OCR Confidence badge
                  _buildConfidenceBadge(),
                  const SizedBox(height: 16),

                  // Review Form
                  Form(
                    key: _formKey,
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Review Extracted Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Divider(height: 24),

                          // Product Name
                          CustomTextField(
                            controller: _productNameCtrl,
                            label: 'Product / Item Name *',
                            hint: 'e.g. iPhone 15 Pro Max',
                            prefixIcon: Icons.shopping_bag_rounded,
                            validator: (v) => v?.isEmpty ?? true ? 'Product name is required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Store Name
                          CustomTextField(
                            controller: _storeNameCtrl,
                            label: 'Store / Merchant *',
                            hint: 'e.g. Apple Store, Amazon',
                            prefixIcon: Icons.store_rounded,
                            validator: (v) => v?.isEmpty ?? true ? 'Store name is required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Bill Number / Invoice Number
                          CustomTextField(
                            controller: _billNumberCtrl,
                            label: 'Bill / Invoice Number',
                            hint: 'e.g. INV-99821-X',
                            prefixIcon: Icons.tag_rounded,
                          ),
                          const SizedBox(height: 14),

                          // Purchase Date
                          GestureDetector(
                            onTap: _selectDate,
                            child: AbsorbPointer(
                              child: CustomTextField(
                                controller: TextEditingController(
                                  text: DateFormat('dd MMM yyyy').format(_purchaseDate),
                                ),
                                label: 'Purchase Date *',
                                hint: 'Select date',
                                prefixIcon: Icons.calendar_today_rounded,
                                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              // Amount
                              Expanded(
                                child: CustomTextField(
                                  controller: _amountCtrl,
                                  label: 'Total Amount (₹) *',
                                  hint: 'e.g. 129900',
                                  prefixIcon: Icons.currency_rupee_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    if (v?.isEmpty ?? true) return 'Required';
                                    if (double.tryParse(v!.replaceAll(',', '')) == null) {
                                      return 'Invalid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Tax Amount
                              Expanded(
                                child: CustomTextField(
                                  controller: _taxCtrl,
                                  label: 'Tax Amount (₹)',
                                  hint: 'e.g. 23382',
                                  prefixIcon: Icons.percent_rounded,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Brand
                          CustomTextField(
                            controller: _brandCtrl,
                            label: 'Brand Name',
                            hint: 'e.g. Apple',
                            prefixIcon: Icons.branding_watermark_rounded,
                          ),
                          const SizedBox(height: 14),

                          // Category
                          DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: [
                              'Electronics',
                              'Furniture',
                              'Home Appliances',
                              'Fashion',
                              'Grocery',
                              'Vehicle',
                              'Medical',
                              'Others'
                            ].map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat),
                                ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedCategory = v!),
                          ),
                          const SizedBox(height: 14),

                          // Description / Notes
                          CustomTextField(
                            controller: _descCtrl,
                            label: 'Notes / Remarks',
                            hint: 'Additional notes about this purchase...',
                            prefixIcon: Icons.notes_rounded,
                            maxLines: 2,
                          ),

                          const Divider(height: 32),

                          // EMI Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EMI installment',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Check if this purchase is on EMI',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _emiEnabled,
                                activeColor: AppColors.primary,
                                onChanged: (v) => setState(() => _emiEnabled = v),
                              ),
                            ],
                          ),

                          if (_emiEnabled) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _emiAmountCtrl,
                                    label: 'EMI Monthly Cost (₹) *',
                                    hint: 'e.g. 5000',
                                    prefixIcon: Icons.payments_rounded,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (v) {
                                      if (_emiEnabled && (v?.isEmpty ?? true)) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _emiDurationCtrl,
                                    label: 'Tenure (e.g. 12 months) *',
                                    hint: 'e.g. 12 months',
                                    prefixIcon: Icons.timelapse_rounded,
                                    validator: (v) {
                                      if (_emiEnabled && (v?.isEmpty ?? true)) return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Divider(height: 32),

                          // Warranty Section
                          SwitchListTile(
                            value: _hasWarranty,
                            onChanged: (v) => setState(() => _hasWarranty = v),
                            title: const Text(
                              'Track Warranty',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: const Text('Enable to track warranty expiry reminders', style: TextStyle(fontSize: 11)),
                            activeThumbColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ),

                          if (_hasWarranty) ...[
                            const SizedBox(height: 12),
                            Text('Warranty Period: $_warrantyMonths months',
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            Slider(
                              value: _warrantyMonths.toDouble(),
                              min: 1,
                              max: 120,
                              divisions: 119,
                              label: '$_warrantyMonths months',
                              activeColor: AppColors.primary,
                              onChanged: (v) => setState(() => _warrantyMonths = v.round()),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: AppColors.success, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Warranty expires on ${DateFormat('dd MMM yyyy').format(_warrantyExpiryDate)}',
                                    style: const TextStyle(
                                        color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _resetScanner,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Scan Again'),
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
                        child: GradientButton(
                          onPressed: _isSaving ? null : _saveBill,
                          isLoading: _isSaving,
                          text: 'Save Bill',
                          icon: Icons.check_circle_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    final lowConfidence = _ocrConfidenceScore < 0.80;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lowConfidence
            ? Colors.orange.withOpacity(0.12)
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lowConfidence ? Colors.orange.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            lowConfidence ? Icons.warning_amber_rounded : Icons.verified_rounded,
            color: lowConfidence ? Colors.orange[800] : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lowConfidence ? 'Low OCR Confidence' : 'OCR Scan Confirmed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: lowConfidence ? Colors.orange[900] : AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lowConfidence
                      ? 'AI confidence score is ${(ocrConfidencePercentage)}%. Please double-check fields manually.'
                      : 'AI confidence score is ${(ocrConfidencePercentage)}%. Fields populated successfully.',
                  style: TextStyle(
                    fontSize: 11,
                    color: lowConfidence ? Colors.orange[800] : Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get ocrConfidencePercentage => (_ocrConfidenceScore * 100).toStringAsFixed(1);

  void _showSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Capture with Camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
              title: const Text('Select from Gallery'),
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
