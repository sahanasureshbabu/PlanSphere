import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/models/maintenance_model.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/core/utils/file_saver_helper.dart';

class ServiceHistoryScreen extends ConsumerWidget {
  const ServiceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(userBillsProvider);
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: billsAsync.when(
        data: (bills) {
          final allLogs = <_ServiceLogItem>[];
          double totalSpend = 0.0;
          for (final bill in bills) {
            for (final log in bill.serviceHistory) {
              allLogs.add(_ServiceLogItem(bill: bill, log: log));
              totalSpend += log.cost;
            }
          }
          
          allLogs.sort((a, b) => b.log.serviceDate.compareTo(a.log.serviceDate));

          final now = DateTime.now();
          final upcomingLogs = allLogs.where((item) {
            if (item.log.nextServiceDate == null) return false;
            final diff = item.log.nextServiceDate!.difference(now).inDays;
            return diff >= 0 && diff <= 30;
          }).toList();

          if (allLogs.isEmpty) {
            return _buildEmptyState(context, ref, bills);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _buildStatsCard(totalSpend, allLogs.length, currencyFormat, Theme.of(context).brightness == Brightness.dark),
                    if (upcomingLogs.isNotEmpty)
                      _buildReminderBanner(upcomingLogs),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: allLogs.length,
                  itemBuilder: (context, index) {
                    final item = allLogs[index];
                    return _ServiceLogCard(item: item, currencyFormat: currencyFormat, bills: bills);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildEmptyState(context, ref, const []),
      ),
      floatingActionButton: billsAsync.when(
        data: (bills) => bills.isEmpty
            ? null
            : FloatingActionButton(
                onPressed: () => _showAddServiceDialog(context, ref, bills),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add_rounded),
              ),
        loading: () => null,
        error: (e, _) => null,
      ),
    );
  }

  Widget _buildStatsCard(double totalSpend, int totalRecords, NumberFormat currencyFormat, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 1),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Spent on Maintenance',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(totalSpend),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Service Logs',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalRecords Logs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderBanner(List<_ServiceLogItem> upcomingLogs) {
    final billsDue = upcomingLogs.map((item) => item.bill.title).toSet().toList();
    final billNamesStr = billsDue.join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.amber.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upcoming Maintenance Due',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Maintenance due within 30 days for: $billNamesStr.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, List<BillModel> bills) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Service History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep track of your appliance services\nand repairs here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          if (bills.isNotEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddServiceDialog(context, ref, bills),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Service Record'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceLogItem {
  final BillModel bill;
  final ServiceRecord log;
  _ServiceLogItem({required this.bill, required this.log});
}

class _ServiceLogCard extends ConsumerWidget {
  final _ServiceLogItem item;
  final NumberFormat currencyFormat;
  final List<BillModel> bills;

  const _ServiceLogCard({required this.item, required this.currencyFormat, required this.bills});

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

  Future<void> _downloadInvoice(BuildContext context, ServiceRecord log) async {
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
      
      AppSnackbar.showSuccess(context, 'Invoice PDF download started');
    } catch (e) {
      AppSnackbar.showError(context, 'Failed to download invoice: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = item.log;
    final isOverdue = log.nextServiceDate != null && log.nextServiceDate!.isBefore(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final productTotalSpend = item.bill.serviceHistory.fold<double>(0.0, (sum, record) => sum + record.cost);

    final hasInvoice = log.receiptUrl != null && log.receiptUrl!.isNotEmpty;
    final isPdf = hasInvoice && log.receiptUrl!.startsWith('JVBERi0');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.bill.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _getServiceIcon(log.serviceType),
                            color: AppColors.primary,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            log.serviceType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      currencyFormat.format(log.cost),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showAddServiceDialog(context, ref, bills, existingRecord: log, associatedBill: item.bill);
                        } else if (val == 'delete') {
                          _showDeleteConfirmationDialog(context, ref, log, item.bill);
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
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.black87),
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
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.black87),
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
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.black87),
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
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Total Product Spend: ',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                    ),
                    Text(
                      currencyFormat.format(productTotalSpend),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
                if (hasInvoice)
                  TextButton.icon(
                    onPressed: () {
                      if (isPdf) {
                        _downloadInvoice(context, log);
                      } else {
                        _showFullScreenImage(context, log.receiptUrl!);
                      }
                    },
                    icon: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      size: 14,
                      color: AppColors.primaryLight,
                    ),
                    label: Text(
                      isPdf ? 'Download Invoice' : 'View Invoice',
                      style: const TextStyle(fontSize: 10, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
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
        ),
      ),
    );
  }
}

void _showAddServiceDialog(BuildContext context, WidgetRef ref, List<BillModel> bills, {ServiceRecord? existingRecord, BillModel? associatedBill}) {
  if (bills.isEmpty) {
    AppSnackbar.showError(context, 'Please add a product/bill first');
    return;
  }

  final formKey = GlobalKey<FormState>();
  final serviceCostCtrl = TextEditingController(text: existingRecord?.cost.toStringAsFixed(0) ?? '');
  final serviceTechCtrl = TextEditingController(text: existingRecord?.technicianName ?? '');
  final serviceDescCtrl = TextEditingController(text: existingRecord?.description ?? '');

  DateTime selectedServiceDate = existingRecord?.serviceDate ?? DateTime.now();
  DateTime? selectedNextServiceDate = existingRecord?.nextServiceDate;
  String selectedServiceType = existingRecord?.serviceType ?? 'General Maintenance';
  BillModel selectedBill = associatedBill ?? bills.first;

  String? base64Invoice = existingRecord?.receiptUrl;
  String? selectedFileName = (existingRecord?.receiptUrl != null && existingRecord!.receiptUrl!.isNotEmpty)
      ? (existingRecord.receiptUrl!.startsWith('JVBERi0') ? 'invoice.pdf' : 'invoice.png')
      : null;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> pickInvoice() async {
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
        }

        return AlertDialog(
          title: Text(existingRecord != null ? 'Edit Service Record' : 'Add Service Record'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<BillModel>(
                      value: bills.firstWhere((b) => b.id == selectedBill.id, orElse: () => selectedBill),
                      decoration: const InputDecoration(
                        labelText: 'Select Product/Bill *',
                        border: OutlineInputBorder(),
                      ),
                      items: bills.map((bill) {
                        return DropdownMenuItem<BillModel>(
                          value: bill,
                          child: Text(
                            bill.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedBill = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
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
                      controller: serviceTechCtrl,
                      label: 'Technician / Service Provider *',
                      hint: 'e.g. Urban Company, Samsung ResQ',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: serviceCostCtrl,
                      label: 'Service Cost (₹) *',
                      hint: 'e.g. 1500',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: serviceDescCtrl,
                      label: 'Service Description / Notes *',
                      hint: 'e.g. Filter cleaning and repair',
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
                            onPressed: pickInvoice,
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (serviceTechCtrl.text.isEmpty ||
                    serviceCostCtrl.text.isEmpty ||
                    serviceDescCtrl.text.isEmpty) {
                  AppSnackbar.showError(ctx, 'Please fill in all required fields');
                  return;
                }

                final updatedLog = ServiceRecord(
                  id: existingRecord?.id ?? const Uuid().v4(),
                  serviceDate: selectedServiceDate,
                  cost: double.tryParse(serviceCostCtrl.text) ?? 0.0,
                  technicianName: serviceTechCtrl.text.trim(),
                  description: serviceDescCtrl.text.trim(),
                  serviceType: selectedServiceType,
                  nextServiceDate: selectedNextServiceDate,
                  receiptUrl: base64Invoice,
                );

                bool success = false;
                if (existingRecord != null && associatedBill != null) {
                  // EDIT MODE
                  if (selectedBill.id != associatedBill.id) {
                    // Remove from original bill
                    final originalLogs = List<ServiceRecord>.from(associatedBill.serviceHistory)
                      ..removeWhere((r) => r.id == existingRecord.id);
                    final originalBill = associatedBill.copyWith(serviceHistory: originalLogs);
                    await ref.read(billCrudProvider.notifier).updateBill(bill: originalBill);

                    // Add to selected bill
                    final targetLogs = List<ServiceRecord>.from(selectedBill.serviceHistory)..add(updatedLog);
                    final targetBill = selectedBill.copyWith(serviceHistory: targetLogs);
                    success = await ref.read(billCrudProvider.notifier).updateBill(bill: targetBill);
                  } else {
                    // Update in same bill
                    final updatedLogs = associatedBill.serviceHistory.map((r) {
                      return r.id == existingRecord.id ? updatedLog : r;
                    }).toList();
                    final targetBill = associatedBill.copyWith(serviceHistory: updatedLogs);
                    success = await ref.read(billCrudProvider.notifier).updateBill(bill: targetBill);
                  }
                } else {
                  // ADD MODE
                  final updatedLogs = List<ServiceRecord>.from(selectedBill.serviceHistory)..add(updatedLog);
                  final targetBill = selectedBill.copyWith(serviceHistory: updatedLogs);
                  success = await ref.read(billCrudProvider.notifier).updateBill(bill: targetBill);
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    AppSnackbar.showSuccess(
                      context,
                      existingRecord != null
                          ? 'Service record updated successfully'
                          : 'Service record added successfully!',
                    );
                  } else {
                    AppSnackbar.showError(context, 'Failed to save service record.');
                  }
                }
              },
              child: Text(existingRecord != null ? 'Update Record' : 'Add Record'),
            ),
          ],
        );
      },
    ),
  );
}

void _showDeleteConfirmationDialog(BuildContext context, WidgetRef ref, ServiceRecord log, BillModel bill) {
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
            if (context.mounted) {
              Navigator.pop(ctx);
              if (success) {
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
