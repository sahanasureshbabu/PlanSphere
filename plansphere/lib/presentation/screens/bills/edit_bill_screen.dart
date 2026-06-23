import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/core/utils/responsive_layout.dart';

class EditBillScreen extends ConsumerStatefulWidget {
  final String billId;
  const EditBillScreen({super.key, required this.billId});

  @override
  ConsumerState<EditBillScreen> createState() => _EditBillScreenState();
}

class _EditBillScreenState extends ConsumerState<EditBillScreen> {
  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(selectedBillProvider(widget.billId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) return const Center(child: Text('Bill not found'));
          return _AddBillForm(bill: bill);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 72,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load bill details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(selectedBillProvider(widget.billId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddBillForm extends ConsumerStatefulWidget {
  final BillModel bill;
  const _AddBillForm({required this.bill});

  @override
  ConsumerState<_AddBillForm> createState() => _AddBillFormState();
}

class _AddBillFormState extends ConsumerState<_AddBillForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _storeCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagsCtrl;

  late String _selectedCategory;
  late String _selectedRecordType;
  late DateTime _purchaseDate;
  late bool _hasWarranty;
  late int _warrantyMonths;
  
  XFile? _imageFile;
  PlatformFile? _pdfFile;
  bool _isLoading = false;

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.bill.title);
    _amountCtrl = TextEditingController(text: widget.bill.amount.toStringAsFixed(0));
    _storeCtrl = TextEditingController(text: widget.bill.storeName);
    _brandCtrl = TextEditingController(text: widget.bill.brand);
    _descCtrl = TextEditingController(text: widget.bill.description);
    _tagsCtrl = TextEditingController(text: widget.bill.tags.join(', '));

    _selectedCategory = widget.bill.category;
    _selectedRecordType = widget.bill.recordType;
    _purchaseDate = widget.bill.purchaseDate;
    _hasWarranty = widget.bill.hasWarranty;
    _warrantyMonths = widget.bill.warrantyDurationMonths ?? 12;
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
      setState(() => _imageFile = picked);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pdfFile = result.files.single);
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

  Future<void> _updateBill() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final updatedBill = widget.bill.copyWith(
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
      updatedAt: DateTime.now(),
    );

    final success = await ref.read(billCrudProvider.notifier).updateBill(
          bill: updatedBill,
          imageFile: _imageFile,
          pdfFile: _pdfFile,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ref.invalidate(userBillsProvider);
      ref.invalidate(activeWarrantiesProvider);
      ref.invalidate(expiringSoonWarrantiesProvider);
      ref.invalidate(selectedBillProvider(widget.bill.id));
      AppSnackbar.showSuccess(context, 'Bill updated successfully');
      context.pop();
    } else {
      final state = ref.read(billCrudProvider);
      final errorMsg = state.hasError ? state.error.toString() : 'Please try again.';
      AppSnackbar.showError(context, 'Failed to update bill: $errorMsg');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isWide(context);

    final formBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _titleCtrl,
          label: 'Title *',
          hint: 'e.g. Samsung TV Purchase',
          prefixIcon: Icons.title_rounded,
          validator: (v) =>
              v?.isEmpty ?? true ? 'Title is required' : null,
        ),
        const SizedBox(height: 14),

        // Category
        DropdownButtonFormField<String>(
          value: _selectedCategory,
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
        const SizedBox(height: 14),

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
        const SizedBox(height: 14),

        // Store Name
        CustomTextField(
          controller: _storeCtrl,
          label: 'Store / Merchant Name',
          hint: 'e.g. Croma, Amazon',
          prefixIcon: Icons.store_rounded,
        ),
        const SizedBox(height: 14),

        // Brand Name
        CustomTextField(
          controller: _brandCtrl,
          label: 'Brand Name',
          hint: 'e.g. Sony, Samsung',
          prefixIcon: Icons.branding_watermark_rounded,
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

        // Description
        CustomTextField(
          controller: _descCtrl,
          label: 'Description',
          hint: 'Additional notes about this bill...',
          prefixIcon: Icons.notes_rounded,
          maxLines: 3,
        ),
        const SizedBox(height: 14),

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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
                      color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),

        GradientButton(
          onPressed: _isLoading ? null : _updateBill,
          isLoading: _isLoading,
          text: 'Update Bill Details',
          icon: Icons.save_rounded,
        ),
      ],
    );

    return Form(
      key: _formKey,
      child: isWide
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1150),
                padding: const EdgeInsets.all(AppConstants.paddingL),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Uploads & Previews)
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            const _SectionTitle(title: 'Update Bill Files'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _UploadCard(
                                    icon: Icons.image_rounded,
                                    label: _imageFile != null
                                        ? 'New Image ✓'
                                        : ((widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty) || (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty))
                                            ? 'Replace Image'
                                            : 'Upload Image',
                                    color: AppColors.primary,
                                    isSelected: _imageFile != null || (widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty) || (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty),
                                    onTap: () => _showImageSourceDialog(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _UploadCard(
                                    icon: Icons.picture_as_pdf_rounded,
                                    label: _pdfFile != null
                                        ? 'New PDF ✓'
                                        : widget.bill.pdfUrl != null
                                            ? 'Replace PDF'
                                            : 'Upload PDF',
                                    color: AppColors.accent,
                                    isSelected: _pdfFile != null || widget.bill.pdfUrl != null,
                                    onTap: _pickPdf,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_imageFile != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(
                                        _imageFile!.path,
                                        height: 240,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_imageFile!.path),
                                        height: 240,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                              )
                            else if (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(widget.bill.imageBase64!),
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else if (widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  widget.bill.imageUrl!,
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            if (_pdfFile != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _pdfFile!.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (widget.bill.pdfUrl != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accent.withOpacity(0.15)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Existing Bill PDF',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right Column (Form fields)
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        child: formBody,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              children: [
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
                const _SectionTitle(title: 'Update Bill Files'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _UploadCard(
                        icon: Icons.image_rounded,
                        label: _imageFile != null
                            ? 'New Image ✓'
                            : ((widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty) || (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty))
                                ? 'Replace Image'
                                : 'Upload Image',
                        color: AppColors.primary,
                        isSelected: _imageFile != null || (widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty) || (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty),
                        onTap: () => _showImageSourceDialog(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UploadCard(
                        icon: Icons.picture_as_pdf_rounded,
                        label: _pdfFile != null
                            ? 'New PDF ✓'
                            : widget.bill.pdfUrl != null
                                ? 'Replace PDF'
                                : 'Upload PDF',
                        color: AppColors.accent,
                        isSelected: _pdfFile != null || widget.bill.pdfUrl != null,
                        onTap: _pickPdf,
                      ),
                    ),
                  ],
                ),
                if (_imageFile != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _imageFile!.path,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_imageFile!.path),
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ] else if (widget.bill.imageBase64 != null && widget.bill.imageBase64!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(widget.bill.imageBase64!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ] else if (widget.bill.imageUrl != null && widget.bill.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.bill.imageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (_pdfFile != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pdfFile!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (widget.bill.pdfUrl != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accent),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Existing Bill PDF',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                formBody,
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  void _showImageSourceDialog() {
    if (kIsWeb) {
      _pickImage(ImageSource.gallery);
      return;
    }
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
            fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
