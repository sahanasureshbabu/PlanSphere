import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/models/maintenance_model.dart';
import 'package:plansphere/data/services/ai_service.dart';
import 'package:plansphere/data/services/warranty_claim_service.dart';
import 'package:plansphere/core/utils/responsive_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'package:plansphere/core/utils/file_saver_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BillDetailScreen extends ConsumerStatefulWidget {
  final String billId;
  final int? initialTab;
  const BillDetailScreen({super.key, required this.billId, this.initialTab});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AiService _aiService = AiService();
  final WarrantyClaimService _claimService = WarrantyClaimService();

  // Dialog controllers for Service Log
  final _serviceDateCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
  final _serviceCostCtrl = TextEditingController();
  final _serviceTechCtrl = TextEditingController();
  final _serviceDescCtrl = TextEditingController();

  // Dialog controllers for AMC Details
  final _amcProviderCtrl = TextEditingController();
  final _amcPhoneCtrl = TextEditingController();
  final _amcCostCtrl = TextEditingController();
  final _amcPolicyCtrl = TextEditingController();
  final DateTime _amcStart = DateTime.now();
  final DateTime _amcEnd = DateTime.now().add(const Duration(days: 365));

  final _claimDefectCtrl = TextEditingController();
  final _claimResolutionCtrl = TextEditingController(text: 'Replacement or repair of the defective components at zero cost.');
  final _serviceCenterNameCtrl = TextEditingController();
  final _serviceCenterEmailCtrl = TextEditingController();
  final _serviceCenterPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab ?? 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serviceDateCtrl.dispose();
    _serviceCostCtrl.dispose();
    _serviceTechCtrl.dispose();
    _serviceDescCtrl.dispose();
    _amcProviderCtrl.dispose();
    _amcPhoneCtrl.dispose();
    _amcCostCtrl.dispose();
    _amcPolicyCtrl.dispose();
    _claimDefectCtrl.dispose();
    _claimResolutionCtrl.dispose();
    _serviceCenterNameCtrl.dispose();
    _serviceCenterEmailCtrl.dispose();
    _serviceCenterPhoneCtrl.dispose();
    super.dispose();
  }

  void _downloadServiceInvoice(ServiceRecord log) async {
    try {
      final bytes = base64Decode(log.receiptUrl!);
      final dateStr = DateFormat('yyyyMMdd').format(log.serviceDate);
      final sanitizedTech = log.technicianName.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'PlanSphere_Service_Invoice_${sanitizedTech}_$dateStr.pdf';

      await FileSaverHelper.saveFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
      
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Invoice PDF download started');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to download invoice: $e');
      }
    }
  }

  void _showDeleteConfirmationDialog(ServiceRecord log, BillModel bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service Record'),
        content: const Text('Are you sure you want to delete this service record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedLogs = List<ServiceRecord>.from(bill.serviceHistory)..removeWhere((r) => r.id == log.id);
              final updatedBill = bill.copyWith(serviceHistory: updatedLogs);

              final success = await ref.read(billCrudProvider.notifier).updateBill(bill: updatedBill);
              if (mounted) {
                Navigator.pop(ctx);
                if (success) {
                  ref.invalidate(selectedBillProvider(bill.id));
                  AppSnackbar.showSuccess(context, 'Service record deleted successfully');
                } else {
                  AppSnackbar.showError(context, 'Failed to delete service record.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String base64Image) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      base64Decode(base64Image),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadAsImage(BuildContext context, BillModel bill) async {
    if (bill.imageBase64 == null || bill.imageBase64!.isEmpty) {
      AppSnackbar.showError(context, 'No bill image available to download');
      return;
    }

    try {
      final bytes = base64Decode(bill.imageBase64!);
      final dateStr = DateFormat('yyyyMMdd').format(bill.purchaseDate);
      final sanitizedTitle = bill.title.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'PlanSphere_Bill_${sanitizedTitle}_$dateStr.png';

      await FileSaverHelper.saveFile(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'image/png',
      );
      if (mounted) {
        if (!kIsWeb) {
          AppSnackbar.showSuccess(context, 'Bill image shared successfully');
        } else {
          AppSnackbar.showSuccess(context, 'Bill image download started');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to download image: $e');
      }
    }
  }

  Future<void> _downloadAsPdf(BuildContext context, BillModel bill) async {
    if (bill.imageBase64 == null || bill.imageBase64!.isEmpty) {
      AppSnackbar.showError(context, 'No bill image available to download');
      return;
    }

    try {
      final pdf = pw.Document();
      final image = pw.MemoryImage(base64Decode(bill.imageBase64!));

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(
                    level: 0,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('PlanSphere Bill Invoice',
                            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            DateFormat('dd MMM yyyy').format(DateTime.now()),
                            style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Bill Details',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Title:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(bill.title),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rs. ${bill.amount.toStringAsFixed(2)}'),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Purchase Date:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd MMM yyyy').format(bill.purchaseDate)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Store Name:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(bill.storeName),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Brand:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(bill.brand),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Invoice Number:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(bill.id.substring(0, 8).toUpperCase()),
                    ],
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Uploaded Bill Image',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Container(
                      constraints: const pw.BoxConstraints(maxHeight: 350),
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final dateStr = DateFormat('yyyyMMdd').format(bill.purchaseDate);
      final sanitizedTitle = bill.title.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'PlanSphere_Bill_${sanitizedTitle}_$dateStr.pdf';

      await FileSaverHelper.saveFile(
        bytes: pdfBytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        if (!kIsWeb) {
          AppSnackbar.showSuccess(context, 'Bill PDF shared successfully');
        } else {
          AppSnackbar.showSuccess(context, 'Bill PDF download started');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to download PDF: $e');
      }
    }
  }

  Future<void> _shareBill(BuildContext context, BillModel bill) async {
    if (bill.imageBase64 == null || bill.imageBase64!.isEmpty) {
      AppSnackbar.showError(context, 'No bill image available to download');
      return;
    }

    try {
      final bytes = base64Decode(bill.imageBase64!);
      final dateStr = DateFormat('yyyyMMdd').format(bill.purchaseDate);
      final sanitizedTitle = bill.title.replaceAll(RegExp(r'[^\w\-_]'), '_');
      final fileName = 'PlanSphere_Bill_${sanitizedTitle}_$dateStr.png';

      if (kIsWeb) {
        final shareText = 'PlanSphere Bill: ${bill.title}\n'
            'Amount: ₹${bill.amount}\n'
            'Store: ${bill.storeName}\n'
            'Brand: ${bill.brand}\n'
            'Purchase Date: ${DateFormat('dd MMM yyyy').format(bill.purchaseDate)}';
        
        try {
          await Share.share(shareText, subject: 'PlanSphere Bill: ${bill.title}');
        } catch (e) {
          if (mounted) {
            AppSnackbar.showError(context, 'Sharing not supported on this browser');
          }
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'PlanSphere Bill: ${bill.title} (₹${bill.amount})',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to share bill: $e');
      }
    }
  }

  Future<void> _shareBillLink(BuildContext context, BillModel bill) async {
    try {
      final billService = ref.read(billServiceProvider);
      await billService.shareBillPublicly(bill);

      final baseUrl = kIsWeb ? Uri.base.origin : 'https://plansphere.web.app';
      final shareLink = '$baseUrl/#/shared-bill/${bill.id}';

      final shareText = 'PlanSphere Bill: ${bill.title}\n'
          'Amount: ₹${bill.amount}\n'
          'Open Bill: $shareLink';

      await Share.share(shareText, subject: 'Shared Bill: ${bill.title}');
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Shareable bill link copied and shared!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to share bill link: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billAsync = ref.watch(selectedBillProvider(widget.billId));
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Scaffold(
      body: billAsync.when(
        data: (bill) {
          if (bill == null) {
            return const Center(child: Text('Bill not found'));
          }
          print('imageBase64 length: ${bill.imageBase64?.length}');
          print('imageUrl: ${bill.imageUrl}');
          return _buildDetailContent(bill, currencyFormat);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () => context.pop(),
                  ),
                ),
                const Spacer(),
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
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailContent(BillModel bill, NumberFormat currencyFormat) {
    final healthScore = _aiService.calculateHealthScore(bill);
    final isWide = ResponsiveLayout.isWide(context);

    Color healthColor = AppColors.success;
    if (healthScore < 40) {
      healthColor = AppColors.error;
    } else if (healthScore < 75) {
      healthColor = AppColors.warning;
    }

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (40% width) - File/Image preview & Actions
                Expanded(
                  flex: 4,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 1.2,
                          child: (bill.imageBase64 != null && bill.imageBase64!.isNotEmpty)
                              ? GestureDetector(
                                  onTap: () => _showFullScreenImage(context, bill.imageBase64!),
                                  child: Image.memory(
                                    base64Decode(bill.imageBase64!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, error, stackTrace) => Container(
                                      color: AppColors.primary.withOpacity(0.1),
                                      child: const Icon(Icons.receipt_long_rounded,
                                          size: 64, color: AppColors.primary),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.receipt_long_rounded,
                                        size: 64, color: Colors.white),
                                  ),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actions',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => context.push('/bills/${bill.id}/edit'),
                                      icon: const Icon(Icons.edit_rounded),
                                      label: const Text('Edit Details'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _handleAction(ref, bill, 'delete'),
                                      icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                                      label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.error),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text(
                                'Downloads & Sharing',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _downloadAsImage(context, bill),
                                      icon: const Icon(Icons.image_rounded),
                                      label: const Text('Download Image'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _downloadAsPdf(context, bill),
                                      icon: const Icon(Icons.picture_as_pdf_rounded),
                                      label: const Text('Download PDF'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _shareBill(context, bill),
                                      icon: const Icon(Icons.share_rounded),
                                      label: const Text('Share Bill'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _shareBillLink(context, bill),
                                      icon: const Icon(Icons.link_rounded),
                                      label: const Text('Share Link'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                // Right Column (60% width) - Details, health, tabs
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bill.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _CategoryChip(category: bill.category),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          bill.brand,
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(bill.amount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd MMM yyyy').format(bill.purchaseDate),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Health Score Widget
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: healthColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: healthColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              CircularPercentIndicator(
                                radius: 28,
                                lineWidth: 5,
                                percent: (healthScore / 100).clamp(0.0, 1.0),
                                center: Text(
                                  '$healthScore',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: healthColor,
                                  ),
                                ),
                                progressColor: healthColor,
                                backgroundColor: healthColor.withOpacity(0.15),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Product Health Score',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      healthScore >= 75
                                          ? 'Excellent! Assets under active coverage.'
                                          : healthScore >= 40
                                              ? 'Moderate. Warranty elapsing soon, servicing suggested.'
                                              : 'Critical support health. Schedule maintenance checkups!',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Tab Bar
                        TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: AppColors.primary,
                          tabs: const [
                            Tab(text: 'Details'),
                            Tab(text: 'Services'),
                            Tab(text: 'AMC'),
                            Tab(text: 'Claim'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Tab Contents
                        SizedBox(
                          height: 450,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildDetailsTab(bill, currencyFormat),
                              _buildServicesTab(bill, currencyFormat),
                              _buildAmcTab(bill, currencyFormat),
                              _buildClaimTab(bill),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: (bill.imageBase64 != null && bill.imageBase64!.isNotEmpty) ? 240 : 120,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => context.push('/bills/${bill.id}/edit'),
            ),
            PopupMenuButton(
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppColors.error))
                  ]),
                ),
              ],
              onSelected: (value) => _handleAction(ref, bill, value.toString()),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: (bill.imageBase64 != null && bill.imageBase64!.isNotEmpty)
                ? GestureDetector(
                    onTap: () => _showFullScreenImage(context, bill.imageBase64!),
                    child: Image.memory(
                      base64Decode(bill.imageBase64!),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stackTrace) => Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.receipt_long_rounded,
                            size: 64, color: AppColors.primary),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Center(
                      child: Icon(Icons.receipt_long_rounded,
                          size: 64, color: Colors.white),
                    ),
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.paddingM, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _CategoryChip(category: bill.category),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  bill.brand,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(bill.amount),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700),
                        ),
                        Text(
                          DateFormat('dd MMM yyyy').format(bill.purchaseDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Health Score Widget
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: healthColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: healthColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      CircularPercentIndicator(
                        radius: 28,
                        lineWidth: 5,
                        percent: (healthScore / 100).clamp(0.0, 1.0),
                        center: Text(
                          '$healthScore',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: healthColor,
                          ),
                        ),
                        progressColor: healthColor,
                        backgroundColor: healthColor.withOpacity(0.15),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Health Score',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              healthScore >= 75
                                  ? 'Excellent! Assets under active coverage.'
                                  : healthScore >= 40
                                      ? 'Moderate. Warranty elapsing soon, servicing suggested.'
                                      : 'Critical support health. Schedule maintenance checkups!',
                              style: TextStyle(color: Colors.grey[600], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Downloads & Sharing',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _downloadAsImage(context, bill),
                                icon: const Icon(Icons.image_rounded, size: 14),
                                label: const Text('Image', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _downloadAsPdf(context, bill),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                                label: const Text('PDF', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareBill(context, bill),
                                icon: const Icon(Icons.share_rounded, size: 14),
                                label: const Text('Share', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _shareBillLink(context, bill),
                                icon: const Icon(Icons.link_rounded, size: 14),
                                label: const Text('Link', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Details'),
                    Tab(text: 'Services'),
                    Tab(text: 'AMC'),
                    Tab(text: 'Claim'),
                  ],
                ),
                const SizedBox(height: 16),

                // Tab Contents
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDetailsTab(bill, currencyFormat),
                      _buildServicesTab(bill, currencyFormat),
                      _buildAmcTab(bill, currencyFormat),
                      _buildClaimTab(bill),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsTab(BillModel bill, NumberFormat currencyFormat) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _DetailRow(icon: Icons.store_rounded, label: 'Store Name', value: bill.storeName),
        _DetailRow(icon: Icons.branding_watermark_rounded, label: 'Product Brand', value: bill.brand),
        _DetailRow(icon: Icons.numbers_rounded, label: 'Invoice reference', value: bill.id.substring(0, 8).toUpperCase()),
        if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty)
          _DetailRow(icon: Icons.percent_rounded, label: 'GST Number', value: bill.gstNumber!),
        if (bill.ocrConfidenceScore < 1.0)
          _DetailRow(
            icon: Icons.document_scanner_rounded, 
            label: 'OCR Confidence', 
            value: '${(bill.ocrConfidenceScore * 100).toStringAsFixed(1)}%',
          ),
        if (bill.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Description / Notes', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(bill.description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ],
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'repair':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'installation':
        return Icons.add_to_photos_rounded;
      case 'inspection':
        return Icons.manage_search_rounded;
      case 'upgrade':
        return Icons.upgrade_rounded;
      default:
        return Icons.engineering_rounded;
    }
  }

  Widget _buildServicesTab(BillModel bill, NumberFormat currencyFormat) {
    final sortedHistory = List<ServiceRecord>.from(bill.serviceHistory)
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

    // Reminder Support: Check if any service log has an upcoming next service due date
    final upcomingServices = bill.serviceHistory
        .where((log) => log.nextServiceDate != null && log.nextServiceDate!.isAfter(DateTime.now()))
        .toList();
    if (upcomingServices.isNotEmpty) {
      upcomingServices.sort((a, b) => a.nextServiceDate!.compareTo(b.nextServiceDate!));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Maintenance Logs (${bill.serviceHistory.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => _showAddServiceDialog(bill),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Log', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        if (upcomingServices.isNotEmpty) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12, top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  radius: 18,
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Maintenance Reminder',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${upcomingServices.first.serviceType} is scheduled on ${DateFormat('dd MMM yyyy').format(upcomingServices.first.nextServiceDate!)} with ${upcomingServices.first.technicianName}.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: sortedHistory.isEmpty
              ? _buildEmptyState(
                  icon: Icons.engineering_rounded,
                  title: 'No maintenance logged',
                  subtitle: 'Keep service records to boost product health scores!',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: sortedHistory.length,
                  itemBuilder: (ctx, idx) {
                    final log = sortedHistory[idx];
                    final isOverdue = log.nextServiceDate != null && log.nextServiceDate!.isBefore(DateTime.now());

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getServiceIcon(log.serviceType),
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      log.serviceType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      currencyFormat.format(log.cost),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _showAddServiceDialog(bill, existingRecord: log);
                                        } else if (val == 'delete') {
                                          _showDeleteConfirmationDialog(log, bill);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_rounded, size: 16),
                                              SizedBox(width: 8),
                                              Text('Edit', style: TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_rounded, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Service Date: ${DateFormat('dd MMM yyyy').format(log.serviceDate)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.engineering_rounded, size: 12, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Provider: ${log.technicianName}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2.0),
                                  child: Icon(Icons.description_rounded, size: 12, color: Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Notes: ${log.description}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            if (log.nextServiceDate != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? Colors.red.withOpacity(isDark ? 0.15 : 0.08)
                                      : Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isOverdue
                                        ? Colors.red.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOverdue ? Icons.warning_amber_rounded : Icons.alarm_on_rounded,
                                      size: 12,
                                      color: isOverdue ? Colors.red : Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Next Service Due: ${DateFormat('dd MMM yyyy').format(log.nextServiceDate!)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isOverdue ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isOverdue ? Colors.red : Colors.green,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isOverdue ? 'OVERDUE' : 'UPCOMING',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (log.receiptUrl != null && log.receiptUrl!.isNotEmpty) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      final isPdf = log.receiptUrl!.startsWith('JVBERi0');
                                      if (isPdf) {
                                        _downloadServiceInvoice(log);
                                      } else {
                                        _showFullScreenImage(context, log.receiptUrl!);
                                      }
                                    },
                                    icon: Icon(
                                      log.receiptUrl!.startsWith('JVBERi0')
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.image_rounded,
                                      size: 14,
                                      color: AppColors.primaryLight,
                                    ),
                                    label: Text(
                                      log.receiptUrl!.startsWith('JVBERi0')
                                          ? 'Download Invoice'
                                          : 'View Invoice',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.primaryLight,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAmcTab(BillModel bill, NumberFormat currencyFormat) {
    final amc = bill.amcDetails;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Annual Maintenance Contract',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextButton.icon(
              onPressed: () => _showUpdateAmcDialog(bill),
              icon: Icon(amc != null ? Icons.edit_rounded : Icons.add_rounded, size: 16),
              label: Text(amc != null ? 'Edit AMC' : 'Link AMC', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
        Expanded(
          child: amc == null
              ? _buildEmptyState(
                  icon: Icons.shield_rounded,
                  title: 'No active AMC contract',
                  subtitle: 'Link Annual Maintenance details to protect items post-warranty.',
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DetailRow(icon: Icons.business_rounded, label: 'AMC Provider', value: amc.providerName),
                    if (amc.contactPhone != null && amc.contactPhone!.isNotEmpty)
                      _DetailRow(icon: Icons.phone_rounded, label: 'Support Phone', value: amc.contactPhone!),
                    if (amc.policyNumber != null && amc.policyNumber!.isNotEmpty)
                      _DetailRow(icon: Icons.policy_rounded, label: 'Policy Number', value: amc.policyNumber!),
                    _DetailRow(
                      icon: Icons.date_range_rounded, 
                      label: 'Validity Period', 
                      value: '${DateFormat('dd/MM/yy').format(amc.startDate)} - ${DateFormat('dd/MM/yy').format(amc.endDate)}',
                    ),
                    _DetailRow(
                      icon: Icons.payment_rounded, 
                      label: 'Contract Cost', 
                      value: currencyFormat.format(amc.cost),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildClaimTab(BillModel bill) {
    final bool hasClaimed = bill.claimStatus != 'none';

    Color claimColor = Colors.grey;
    String claimText = 'Not Filed';
    switch (bill.claimStatus) {
      case 'submitted':
        claimColor = AppColors.info;
        claimText = 'Submitted';
        break;
      case 'under_review':
        claimColor = AppColors.warning;
        claimText = 'Under Review';
        break;
      case 'approved':
        claimColor = AppColors.success;
        claimText = 'Approved';
        break;
      case 'rejected':
        claimColor = AppColors.error;
        claimText = 'Rejected';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Warranty Claim Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: claimColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                claimText,
                style: TextStyle(color: claimColor, fontWeight: FontWeight.w600, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (!hasClaimed) ...[
                const Text(
                  'Need to file a warranty claim? Let\'s compile a highly professional claim request letter automatically.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _claimDefectCtrl,
                  label: 'Describe Defect / Deficiencies',
                  hint: 'e.g. Device does not turn on and gets excessively hot when charging.',
                  prefixIcon: Icons.report_problem_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _claimResolutionCtrl,
                  label: 'Resolution Sought',
                  hint: 'e.g. Full replacement or zero-cost repairs.',
                  prefixIcon: Icons.handshake_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _serviceCenterNameCtrl,
                  label: 'Service Center Name (Optional)',
                  hint: 'e.g. Samsung Support Hub',
                  prefixIcon: Icons.business_rounded,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _serviceCenterEmailCtrl,
                  label: 'Support Email (Optional)',
                  hint: 'e.g. support@brand.com',
                  prefixIcon: Icons.email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _serviceCenterPhoneCtrl,
                  label: 'Customer Care Number (Optional)',
                  hint: 'e.g. 1800-123-4567',
                  prefixIcon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _generateClaimLetter(bill),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Generate Claim Letter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else ...[
                Card(
                  color: claimColor.withOpacity(0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, color: claimColor, size: 20),
                            const SizedBox(width: 8),
                            const Text('Active Claim Status Details', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Current Status: $claimText', style: TextStyle(color: claimColor, fontWeight: FontWeight.w600, fontSize: 13)),
                        if (bill.claimNotes != null) ...[
                          const SizedBox(height: 6),
                          Text('Remarks: ${bill.claimNotes!}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateClaimStatusInDb(bill.id, 'none'),
                        child: const Text('Reset Claim Wizard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showStatusUpdateDialog(bill),
                        child: const Text('Update Status'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadClaimLetterPdf(BuildContext context, BillModel bill, String toName, String toContact) async {
    try {
      final pdf = pw.Document();
      final purchaseDateFormatted = '${bill.purchaseDate.day}/${bill.purchaseDate.month}/${bill.purchaseDate.year}';
      final expiryDateFormatted = bill.warrantyExpiryDate != null
          ? '${bill.warrantyExpiryDate!.day}/${bill.warrantyExpiryDate!.month}/${bill.warrantyExpiryDate!.year}'
          : 'N/A';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Formal Warranty Claim Request',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                  pw.SizedBox(height: 15),
                  pw.Text('To,\nCustomer Support Services / Warranty Claims Division\n$toName$toContact',
                      style: pw.TextStyle(lineSpacing: 1.2)),
                  pw.SizedBox(height: 15),
                  pw.Text('Subject: Warranty Claim Request for ${bill.brand} ${bill.title}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 15),
                  pw.Text('Dear Sir/Madam,', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                      'I am writing this letter to formally register a warranty repair/replacement claim for my purchase of a ${bill.brand} ${bill.title}, bought on $purchaseDateFormatted from ${bill.storeName} for an amount of Rs. ${bill.amount.toStringAsFixed(2)}. Details of the product and invoice are outlined below:',
                      style: const pw.TextStyle(lineSpacing: 1.3)),
                  pw.SizedBox(height: 12),
                  pw.Bullet(text: 'Product Name: ${bill.title}'),
                  pw.Bullet(text: 'Manufacturer Brand: ${bill.brand}'),
                  pw.Bullet(text: 'Purchase Date: $purchaseDateFormatted'),
                  pw.Bullet(text: 'Active Warranty Period Expires: $expiryDateFormatted'),
                  pw.Bullet(text: 'Purchase Invoice Reference: ${bill.id.substring(0, 8).toUpperCase()}'),
                  pw.SizedBox(height: 15),
                  pw.Text('Description of Issue / Defect Detected:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_claimDefectCtrl.text, style: const pw.TextStyle(lineSpacing: 1.2)),
                  pw.SizedBox(height: 12),
                  pw.Text('Resolution Sought:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_claimResolutionCtrl.text, style: const pw.TextStyle(lineSpacing: 1.2)),
                  pw.SizedBox(height: 20),
                  pw.Text('Sincerely,'),
                  pw.SizedBox(height: 15),
                  pw.Text('Sahan R'),
                  pw.Text('Email: sahan@example.com'),
                ],
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'Warranty_Claim_Letter_${bill.title.replaceAll(RegExp(r"[^\w\-_]"), "_")}.pdf';
      await FileSaverHelper.saveFile(
        bytes: pdfBytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        if (!kIsWeb) {
          AppSnackbar.showSuccess(context, 'Claim Letter PDF shared successfully');
        } else {
          AppSnackbar.showSuccess(context, 'Claim Letter PDF download started');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to download PDF: $e');
      }
    }
  }

  Future<void> _shareClaimLetterPdf(BuildContext context, BillModel bill, String letterText, String toName, String toContact) async {
    try {
      if (kIsWeb) {
        await Share.share(
          letterText,
          subject: 'Warranty Claim Request for ${bill.brand} ${bill.title}',
        );
      } else {
        final pdf = pw.Document();
        final purchaseDateFormatted = '${bill.purchaseDate.day}/${bill.purchaseDate.month}/${bill.purchaseDate.year}';
        final expiryDateFormatted = bill.warrantyExpiryDate != null
            ? '${bill.warrantyExpiryDate!.day}/${bill.warrantyExpiryDate!.month}/${bill.warrantyExpiryDate!.year}'
            : 'N/A';

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Formal Warranty Claim Request',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                    pw.SizedBox(height: 15),
                    pw.Text('To,\nCustomer Support Services / Warranty Claims Division\n$toName$toContact',
                        style: pw.TextStyle(lineSpacing: 1.2)),
                    pw.SizedBox(height: 15),
                    pw.Text('Subject: Warranty Claim Request for ${bill.brand} ${bill.title}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 15),
                    pw.Text('Dear Sir/Madam,', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text(
                        'I am writing this letter to formally register a warranty repair/replacement claim for my purchase of a ${bill.brand} ${bill.title}, bought on $purchaseDateFormatted from ${bill.storeName} for an amount of Rs. ${bill.amount.toStringAsFixed(2)}. Details of the product and invoice are outlined below:',
                        style: const pw.TextStyle(lineSpacing: 1.3)),
                    pw.SizedBox(height: 12),
                    pw.Bullet(text: 'Product Name: ${bill.title}'),
                    pw.Bullet(text: 'Manufacturer Brand: ${bill.brand}'),
                    pw.Bullet(text: 'Purchase Date: $purchaseDateFormatted'),
                    pw.Bullet(text: 'Active Warranty Period Expires: $expiryDateFormatted'),
                    pw.Bullet(text: 'Purchase Invoice Reference: ${bill.id.substring(0, 8).toUpperCase()}'),
                    pw.SizedBox(height: 15),
                    pw.Text('Description of Issue / Defect Detected:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_claimDefectCtrl.text, style: const pw.TextStyle(lineSpacing: 1.2)),
                    pw.SizedBox(height: 12),
                    pw.Text('Resolution Sought:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_claimResolutionCtrl.text, style: const pw.TextStyle(lineSpacing: 1.2)),
                    pw.SizedBox(height: 20),
                    pw.Text('Sincerely,'),
                    pw.SizedBox(height: 15),
                    pw.Text('Sahan R'),
                    pw.Text('Email: sahan@example.com'),
                  ],
                ),
              );
            },
          ),
        );

        final pdfBytes = await pdf.save();
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/Warranty_Claim_Letter_${bill.id.substring(0, 8)}.pdf');
        await file.writeAsBytes(pdfBytes);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Warranty Claim Request for ${bill.brand} ${bill.title}',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to share claim letter PDF: $e');
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _emailClaimLetter(BuildContext context, BillModel bill, String letterText) async {
    try {
      final email = _serviceCenterEmailCtrl.text.trim();
      final emailLaunchUri = Uri(
        scheme: 'mailto',
        path: email,
        query: _encodeQueryParameters(<String, String>{
          'subject': 'Warranty Claim Request for ${bill.brand} ${bill.title}',
          'body': letterText,
        }),
      );
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (mounted) {
          AppSnackbar.showError(context, 'Could not launch default email app');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to send email: $e');
      }
    }
  }

  Future<void> _whatsappClaimLetter(BuildContext context, BillModel bill, String letterText) async {
    try {
      final whatsappText = Uri.encodeComponent(letterText);
      final whatsappUrl = Uri.parse('https://api.whatsapp.com/send?text=$whatsappText');
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppSnackbar.showError(context, 'Could not launch WhatsApp');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to open WhatsApp: $e');
      }
    }
  }

  void _generateClaimLetter(BillModel bill) {
    if (_claimDefectCtrl.text.isEmpty) {
      AppSnackbar.showError(context, 'Please describe the defect to compile the letter');
      return;
    }

    final letterText = _claimService.compileClaimRequestLetter(
      bill: bill,
      userName: 'Sahan R',
      userEmail: 'sahan@example.com',
      defectDescription: _claimDefectCtrl.text,
      resolutionSought: _claimResolutionCtrl.text,
      serviceCenterName: _serviceCenterNameCtrl.text.trim(),
      supportEmail: _serviceCenterEmailCtrl.text.trim(),
      customerCareNumber: _serviceCenterPhoneCtrl.text.trim(),
    );

    final toName = _serviceCenterNameCtrl.text.isNotEmpty
        ? _serviceCenterNameCtrl.text.trim()
        : '${bill.storeName} / ${bill.brand} Care Center';
    final toContact = (_serviceCenterEmailCtrl.text.isNotEmpty || _serviceCenterPhoneCtrl.text.isNotEmpty)
        ? '\nContact: ${_serviceCenterPhoneCtrl.text.trim()} ${_serviceCenterEmailCtrl.text.isNotEmpty ? "(${_serviceCenterEmailCtrl.text.trim()})" : ""}'
        : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Formal Claim Request Letter'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    letterText,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _downloadClaimLetterPdf(context, bill, toName, toContact);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('Download PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _shareClaimLetterPdf(context, bill, letterText, toName, toContact);
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Share PDF', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _emailClaimLetter(context, bill, letterText);
                      },
                      icon: const Icon(Icons.email_rounded, size: 16),
                      label: const Text('Email Claim', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _whatsappClaimLetter(context, bill, letterText);
                      },
                      icon: const Icon(Icons.message_rounded, size: 16),
                      label: const Text('Send via WhatsApp', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: letterText));
              Navigator.pop(ctx);
              AppSnackbar.showSuccess(context, 'Claim Letter copied to clipboard!');
              _updateClaimStatusInDb(bill.id, 'submitted');
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy & File Claim'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _updateClaimStatusInDb(String billId, String status) async {
    await _claimService.updateClaimStatus(billId: billId, status: status);
    ref.invalidate(selectedBillProvider(billId)); // Refresh DB UI State
  }

  void _showStatusUpdateDialog(BillModel bill) {
    String currentSelectedStatus = bill.claimStatus;
    final notesController = TextEditingController(text: bill.claimNotes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Claim Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: currentSelectedStatus,
              items: const [
                DropdownMenuItem(value: 'submitted', child: Text('Submitted')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (v) => currentSelectedStatus = v!,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: notesController,
              label: 'Claim Remarks / Updates',
              hint: 'e.g. Approved replacement order #9921',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _claimService.updateClaimStatus(
                billId: bill.id, 
                status: currentSelectedStatus,
                claimNotes: notesController.text.trim(),
              );
              if (mounted) {
                Navigator.pop(ctx);
                ref.invalidate(selectedBillProvider(bill.id));
                AppSnackbar.showSuccess(context, 'Claim status updated!');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAddServiceDialog(BillModel bill, {ServiceRecord? existingRecord}) {
    _serviceCostCtrl.text = existingRecord?.cost.toStringAsFixed(0) ?? '';
    _serviceTechCtrl.text = existingRecord?.technicianName ?? '';
    _serviceDescCtrl.text = existingRecord?.description ?? '';

    DateTime selectedServiceDate = existingRecord?.serviceDate ?? DateTime.now();
    DateTime? selectedNextServiceDate = existingRecord?.nextServiceDate;
    String selectedServiceType = existingRecord?.serviceType ?? 'General Maintenance';

    String? base64Invoice = existingRecord?.receiptUrl;
    String? selectedFileName = (existingRecord?.receiptUrl != null && existingRecord!.receiptUrl!.isNotEmpty)
        ? (existingRecord.receiptUrl!.startsWith('JVBERi0') ? 'invoice.pdf' : 'invoice.png')
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingRecord != null ? 'Edit Maintenance Log' : 'Add Maintenance Log'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedServiceType,
                    decoration: const InputDecoration(
                      labelText: 'Service Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'General Maintenance', child: Text('General Maintenance')),
                      DropdownMenuItem(value: 'Repair', child: Text('Repair')),
                      DropdownMenuItem(value: 'Installation', child: Text('Installation')),
                      DropdownMenuItem(value: 'Cleaning', child: Text('Cleaning')),
                      DropdownMenuItem(value: 'Inspection', child: Text('Inspection')),
                      DropdownMenuItem(value: 'Upgrade', child: Text('Upgrade')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedServiceType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedServiceDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: AppColors.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedServiceDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Service Date *',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(selectedServiceDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _serviceTechCtrl,
                    label: 'Technician / Service Provider *',
                    hint: 'e.g. Urban Company, Samsung ResQ',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _serviceCostCtrl,
                    label: 'Service Cost (₹) *',
                    hint: 'e.g. 1500',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _serviceDescCtrl,
                    label: 'Service Description *',
                    hint: 'e.g. Periodic filter replacement & coil cleaning',
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedNextServiceDate ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: const ColorScheme.light(primary: AppColors.primary),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedNextServiceDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Next Service Due Date (Optional)',
                        border: const OutlineInputBorder(),
                        suffixIcon: selectedNextServiceDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedNextServiceDate = null;
                                  });
                                },
                              )
                            : const Icon(Icons.calendar_today_rounded),
                      ),
                      child: Text(
                        selectedNextServiceDate != null
                            ? DateFormat('dd MMM yyyy').format(selectedNextServiceDate!)
                            : 'Tap to select due date',
                        style: TextStyle(
                          color: selectedNextServiceDate != null ? null : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final file = result.files.single;
                                Uint8List bytes;
                                if (kIsWeb) {
                                  bytes = file.bytes!;
                                } else {
                                  if (file.bytes != null) {
                                    bytes = file.bytes!;
                                  } else if (file.path != null) {
                                    bytes = await File(file.path!).readAsBytes();
                                  } else {
                                    throw Exception('File contains no data');
                                  }
                                }
                                setDialogState(() {
                                  base64Invoice = base64Encode(bytes);
                                  selectedFileName = file.name;
                                });
                              }
                            } catch (e) {
                              AppSnackbar.showError(context, 'Failed to pick file: $e');
                            }
                          },
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload Invoice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            foregroundColor: AppColors.primaryLight,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedFileName!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                          onPressed: () {
                            setDialogState(() {
                              base64Invoice = null;
                              selectedFileName = null;
                            });
                          },
                        )
                      ],
                    )
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (_serviceTechCtrl.text.isEmpty || _serviceCostCtrl.text.isEmpty || _serviceDescCtrl.text.isEmpty) {
                    AppSnackbar.showError(ctx, 'Please fill in all required fields');
                    return;
                  }

                  final newLog = ServiceRecord(
                    id: existingRecord?.id ?? const Uuid().v4(),
                    serviceDate: selectedServiceDate,
                    cost: double.tryParse(_serviceCostCtrl.text) ?? 0.0,
                    technicianName: _serviceTechCtrl.text.trim(),
                    description: _serviceDescCtrl.text.trim(),
                    serviceType: selectedServiceType,
                    nextServiceDate: selectedNextServiceDate,
                    receiptUrl: base64Invoice,
                  );

                  List<ServiceRecord> updatedLogs;
                  if (existingRecord != null) {
                    updatedLogs = bill.serviceHistory.map((r) {
                      return r.id == existingRecord.id ? newLog : r;
                    }).toList();
                  } else {
                    updatedLogs = List<ServiceRecord>.from(bill.serviceHistory)..add(newLog);
                  }
                  final updatedBill = bill.copyWith(serviceHistory: updatedLogs);

                  await ref.read(billCrudProvider.notifier).updateBill(bill: updatedBill);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(selectedBillProvider(bill.id));
                    AppSnackbar.showSuccess(
                      context,
                      existingRecord != null
                          ? 'Service record updated successfully'
                          : 'Maintenance log added successfully!',
                    );
                  }
                },
                child: Text(existingRecord != null ? 'Update Record' : 'Add Log'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpdateAmcDialog(BillModel bill) {
    final amc = bill.amcDetails;
    if (amc != null) {
      _amcProviderCtrl.text = amc.providerName;
      _amcPhoneCtrl.text = amc.contactPhone ?? '';
      _amcCostCtrl.text = amc.cost.toStringAsFixed(0);
      _amcPolicyCtrl.text = amc.policyNumber ?? '';
    } else {
      _amcProviderCtrl.clear();
      _amcPhoneCtrl.clear();
      _amcCostCtrl.clear();
      _amcPolicyCtrl.clear();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(amc != null ? 'Update AMC Contract' : 'Add AMC Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: _amcProviderCtrl,
                label: 'AMC Provider Name *',
                hint: 'e.g. OnsiteGo Extended Care',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _amcPhoneCtrl,
                label: 'Support Contact Phone',
                hint: 'e.g. 1800-xxx-xxxx',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _amcPolicyCtrl,
                label: 'Policy / Certificate Number',
                hint: 'e.g. AMC-992188',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _amcCostCtrl,
                label: 'Contract Cost (₹) *',
                hint: 'e.g. 2499',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_amcProviderCtrl.text.isEmpty || _amcCostCtrl.text.isEmpty) {
                AppSnackbar.showError(ctx, 'Please fill in required fields');
                return;
              }

              final newAmc = AmcRecord(
                providerName: _amcProviderCtrl.text.trim(),
                contactPhone: _amcPhoneCtrl.text.trim(),
                startDate: _amcStart,
                endDate: _amcEnd,
                cost: double.tryParse(_amcCostCtrl.text) ?? 0.0,
                policyNumber: _amcPolicyCtrl.text.trim(),
              );

              final updatedBill = bill.copyWith(amcDetails: newAmc);
              await ref.read(billCrudProvider.notifier).updateBill(bill: updatedBill);
              if (mounted) {
                Navigator.pop(ctx);
                ref.invalidate(selectedBillProvider(bill.id));
                AppSnackbar.showSuccess(context, 'AMC contract linked successfully!');
              }
            },
            child: const Text('Save AMC'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            subtitle, 
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _handleAction(WidgetRef ref, BillModel bill, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Bill'),
          content: const Text('Are you sure? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(billCrudProvider.notifier).deleteBill(bill.id);
        if (mounted) {
          ref.invalidate(userBillsProvider);
          ref.invalidate(activeWarrantiesProvider);
          ref.invalidate(expiringSoonWarrantiesProvider);
          AppSnackbar.showSuccess(context, 'Bill deleted successfully');
          context.pop();
        }
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColors[category] ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        category,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
