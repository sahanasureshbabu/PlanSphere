import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/services/ocr_service.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final OcrResult? ocrResult; // Accept OCR result
  const AddBillScreen({super.key, this.ocrResult});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _brandCtrl = TextEditingController(text: 'Generic'); // Brand control
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _selectedCategory = 'Electronics';
  String _selectedRecordType = 'Warranty Bill';
  DateTime _purchaseDate = DateTime.now();
  bool _hasWarranty = false;
  int _warrantyMonths = 12;
  double _ocrConfidenceScore = 1.0; // Track confidence score
  File? _imageFile;
  File? _pdfFile;
  bool _isLoading = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.ocrResult != null) {
      _titleCtrl.text = widget.ocrResult!.productName ?? widget.ocrResult!.storeName ?? '';
      _amountCtrl.text = widget.ocrResult!.amount?.toStringAsFixed(0) ?? '';
      _storeCtrl.text = widget.ocrResult!.storeName ?? '';
      _selectedCategory = widget.ocrResult!.category ?? 'Electronics';
      _hasWarranty = widget.ocrResult!.hasWarranty ?? false;
      _ocrConfidenceScore = widget.ocrResult!.confidenceScore;
      if (widget.ocrResult!.warrantyInfo != null) {
        _descCtrl.text = 'Extracted Warranty Info: ${widget.ocrResult!.warrantyInfo}\n';
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _storeCtrl.dispose();
    _brandCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  DateTime get _warrantyExpiryDate =>
      _purchaseDate.copyWith(month: _purchaseDate.month + _warrantyMonths);

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result?.files.single.path != null) {
      setState(() => _pdfFile = File(result!.files.single.path!));
    }
  }

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
    if (_imageFile == null && _pdfFile == null) {
      AppSnackbar.showError(context, 'Please upload a bill image or PDF');
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser!;
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final bill = BillModel(
      id: '',
      userId: user.uid,
      title: _titleCtrl.text.trim(),
      category: _selectedCategory,
      recordType: _selectedRecordType,
      purchaseDate: _purchaseDate,
      amount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
      storeName: _storeCtrl.text.trim(),
      brand: _brandCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tags: tags,
      hasWarranty: _hasWarranty,
      warrantyDurationMonths: _hasWarranty ? _warrantyMonths : null,
      warrantyExpiryDate: _hasWarranty ? _warrantyExpiryDate : null,
      isDuplicate: false,
      ocrConfidenceScore: _ocrConfidenceScore,
      claimStatus: 'none',
      serviceHistory: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final id = await ref.read(billCrudProvider.notifier).addBill(
          bill: bill,
          imageFile: _imageFile,
          pdfFile: _pdfFile,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (id != null) {
      AppSnackbar.showSuccess(context, 'Bill added successfully!');
      context.pop();
    } else {
      AppSnackbar.showError(context, 'Failed to save bill. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bill'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppConstants.paddingM),
          children: [
            // Record Type
            const _SectionTitle(title: 'Record Type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.recordTypes.map((type) {
                final isSelected = _selectedRecordType == type;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRecordType = type;
                      _hasWarranty = type == 'Warranty Bill';
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Upload Section
            const _SectionTitle(title: 'Upload Bill'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _UploadCard(
                    icon: Icons.image_rounded,
                    label: _imageFile != null ? 'Image Added ✓' : 'Upload Image',
                    color: AppColors.primary,
                    isSelected: _imageFile != null,
                    onTap: () => _showImageSourceDialog(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _UploadCard(
                    icon: Icons.picture_as_pdf_rounded,
                    label: _pdfFile != null ? 'PDF Added ✓' : 'Upload PDF',
                    color: AppColors.accent,
                    isSelected: _pdfFile != null,
                    onTap: _pickPdf,
                  ),
                ),
              ],
            ),

            // Image preview
            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Basic Info
            const _SectionTitle(title: 'Bill Details'),
            const SizedBox(height: 8),

            // OCR Confidence display if available
            if (widget.ocrResult != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _ocrConfidenceScore < 0.80 ? Colors.amber.withOpacity(0.12) : AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _ocrConfidenceScore < 0.80 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                      color: _ocrConfidenceScore < 0.80 ? Colors.orange : AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OCR Confidence Score: ${(_ocrConfidenceScore * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _ocrConfidenceScore < 0.80 ? Colors.orange[800] : AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            CustomTextField(
              controller: _titleCtrl,
              label: 'Title *',
              hint: 'e.g. Samsung TV Purchase',
              prefixIcon: Icons.title_rounded,
              validator: (v) =>
                  v?.isEmpty ?? true ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: AppConstants.billCategories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 12),

            // Amount
            CustomTextField(
              controller: _amountCtrl,
              label: 'Amount (₹) *',
              hint: 'e.g. 45999',
              prefixIcon: Icons.currency_rupee_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v?.isEmpty ?? true) return 'Amount is required';
                if (double.tryParse(v!.replaceAll(',', '')) == null) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Store Name
            CustomTextField(
              controller: _storeCtrl,
              label: 'Store / Merchant Name',
              hint: 'e.g. Croma, Amazon',
              prefixIcon: Icons.store_rounded,
            ),
            const SizedBox(height: 12),

            // Brand Input Field (Added)
            CustomTextField(
              controller: _brandCtrl,
              label: 'Brand Name',
              hint: 'e.g. Samsung, Apple, Sony',
              prefixIcon: Icons.branding_watermark_rounded,
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            // Description
            CustomTextField(
              controller: _descCtrl,
              label: 'Description',
              hint: 'Additional notes about this bill...',
              prefixIcon: Icons.notes_rounded,
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            // Tags
            CustomTextField(
              controller: _tagsCtrl,
              label: 'Tags',
              hint: 'e.g. home, kitchen, gift (comma separated)',
              prefixIcon: Icons.label_outline_rounded,
            ),

            const SizedBox(height: 24),

            // Warranty Section
            const _SectionTitle(title: 'Warranty Details'),
            const SizedBox(height: 8),

            SwitchListTile(
              value: _hasWarranty,
              onChanged: (v) => setState(() => _hasWarranty = v),
              title: const Text('Has Warranty'),
              subtitle: const Text('Enable to track warranty expiry'),
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),

            if (_hasWarranty) ...[
              const SizedBox(height: 12),
              Text('Warranty Duration: $_warrantyMonths months',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Slider(
                value: _warrantyMonths.toDouble(),
                min: 1,
                max: 120,
                divisions: 119,
                label: '$_warrantyMonths months',
                activeColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _warrantyMonths = v.round()),
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
                          color: AppColors.success, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            GradientButton(
              onPressed: _isLoading ? null : _saveBill,
              isLoading: _isLoading,
              text: 'Save Bill',
              icon: Icons.save_rounded,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _UploadCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
