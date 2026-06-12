import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
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
  final DateTime _serviceDate = DateTime.now();

  // Dialog controllers for AMC Details
  final _amcProviderCtrl = TextEditingController();
  final _amcPhoneCtrl = TextEditingController();
  final _amcCostCtrl = TextEditingController();
  final _amcPolicyCtrl = TextEditingController();
  final DateTime _amcStart = DateTime.now();
  final DateTime _amcEnd = DateTime.now().add(const Duration(days: 365));

  // Claim wizard controllers
  final _claimDefectCtrl = TextEditingController();
  final _claimResolutionCtrl = TextEditingController(text: 'Replacement or repair of the defective components at zero cost.');

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
    super.dispose();
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
          return _buildDetailContent(bill, currencyFormat);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildDetailContent(BillModel bill, NumberFormat currencyFormat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthScore = _aiService.calculateHealthScore(bill);

    Color healthColor = AppColors.success;
    if (healthScore < 40) {
      healthColor = AppColors.error;
    } else if (healthScore < 75) {
      healthColor = AppColors.warning;
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: bill.imageUrl != null ? 240 : 120,
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
            background: bill.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: bill.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (ctx, url, e) => Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: const Icon(Icons.receipt_long_rounded,
                          size: 64, color: AppColors.primary),
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

  Widget _buildServicesTab(BillModel bill, NumberFormat currencyFormat) {
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
        Expanded(
          child: bill.serviceHistory.isEmpty
              ? _buildEmptyState(
                  icon: Icons.engineering_rounded,
                  title: 'No maintenance logged',
                  subtitle: 'Keep service records to boost product health scores!',
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: bill.serviceHistory.length,
                  itemBuilder: (ctx, idx) {
                    final log = bill.serviceHistory[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.build_circle_rounded, color: AppColors.primary),
                        ),
                        title: Text(log.technicianName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${DateFormat('dd MMM yy').format(log.serviceDate)}: ${log.description}', style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          currencyFormat.format(log.cost),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
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
    );

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

  void _showAddServiceDialog(BillModel bill) {
    _serviceCostCtrl.clear();
    _serviceTechCtrl.clear();
    _serviceDescCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Maintenance Log'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                id: const Uuid().v4(),
                serviceDate: DateTime.now(),
                cost: double.tryParse(_serviceCostCtrl.text) ?? 0.0,
                technicianName: _serviceTechCtrl.text.trim(),
                description: _serviceDescCtrl.text.trim(),
              );

              final updatedLogs = List<ServiceRecord>.from(bill.serviceHistory)..add(newLog);
              final updatedBill = bill.copyWith(serviceHistory: updatedLogs);

              await ref.read(billCrudProvider.notifier).updateBill(bill: updatedBill);
              if (mounted) {
                Navigator.pop(ctx);
                ref.invalidate(selectedBillProvider(bill.id));
                AppSnackbar.showSuccess(context, 'Maintenance log added successfully!');
              }
            },
            child: const Text('Add Log'),
          ),
        ],
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
          AppSnackbar.showSuccess(context, 'Bill deleted');
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
