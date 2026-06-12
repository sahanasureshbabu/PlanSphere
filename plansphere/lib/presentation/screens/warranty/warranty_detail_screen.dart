import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';

class WarrantyDetailScreen extends ConsumerWidget {
  final String warrantyId;
  const WarrantyDetailScreen({super.key, required this.warrantyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(selectedBillProvider(warrantyId));
    return Scaffold(
      appBar: AppBar(title: const Text('Warranty Details')),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) {
            return const Center(child: Text('Warranty not found'));
          }
          return _WarrantyDetailContent(bill: bill);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _WarrantyDetailContent extends StatelessWidget {
  final BillModel bill;
  const _WarrantyDetailContent({required this.bill});

  @override
  Widget build(BuildContext context) {
    final status = bill.warrantyStatus;
    final days = bill.daysUntilWarrantyExpiry ?? 0;
    final totalDays = (bill.warrantyDurationMonths ?? 12) * 30;
    final remainingPercent =
        days > 0 ? (days / totalDays).clamp(0.0, 1.0) : 0.0;

    Color statusColor;
    String statusText;
    String statusDesc;
    switch (status) {
      case WarrantyStatus.active:
        statusColor = AppColors.success;
        statusText = 'Active';
        statusDesc = 'Your warranty is valid and active.';
        break;
      case WarrantyStatus.expiringSoon:
        statusColor = AppColors.warning;
        statusText = 'Expiring Soon';
        statusDesc =
            'Your warranty expires in $days days. Consider making a claim if needed.';
        break;
      case WarrantyStatus.expired:
        statusColor = AppColors.error;
        statusText = 'Expired';
        statusDesc = 'Your warranty has expired.';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
        statusDesc = '';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircularPercentIndicator(
                  radius: 60,
                  lineWidth: 10,
                  percent: remainingPercent.toDouble(),
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$days',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text('days',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  progressColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  statusDesc,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Product info
          _SectionCard(
            title: 'Product Information',
            children: [
              _InfoRow(label: 'Product', value: bill.title),
              _InfoRow(label: 'Category', value: bill.category),
              _InfoRow(label: 'Store', value: bill.storeName.isNotEmpty ? bill.storeName : 'N/A'),
              _InfoRow(label: 'Purchase Date',
                  value: DateFormat('dd MMM yyyy').format(bill.purchaseDate)),
              _InfoRow(label: 'Amount', value: '₹${bill.amount.toStringAsFixed(0)}'),
            ],
          ),

          const SizedBox(height: 16),

          // Warranty info
          _SectionCard(
            title: 'Warranty Information',
            children: [
              _InfoRow(
                label: 'Duration',
                value: '${bill.warrantyDurationMonths ?? 0} months',
              ),
              if (bill.warrantyExpiryDate != null)
                _InfoRow(
                  label: 'Expiry Date',
                  value: DateFormat('dd MMM yyyy').format(bill.warrantyExpiryDate!),
                ),
              _InfoRow(
                label: 'Status',
                value: statusText,
                valueColor: statusColor,
              ),
              if (days > 0)
                _InfoRow(label: 'Remaining', value: '$days days'),
            ],
          ),

          const SizedBox(height: 16),

          // Claim instructions
          if (status == WarrantyStatus.active ||
              status == WarrantyStatus.expiringSoon) ...[
            const _SectionCard(
              title: '📋 How to Claim Warranty',
              children: [
                _ClaimStep(
                    step: 1,
                    text:
                        'Keep the original bill/receipt ready'),
                _ClaimStep(
                    step: 2,
                    text:
                        'Contact the store/manufacturer support'),
                _ClaimStep(
                    step: 3,
                    text:
                        'Describe the issue clearly with product serial number'),
                _ClaimStep(
                    step: 4,
                    text:
                        'Request for repair/replacement as per warranty terms'),
                _ClaimStep(
                    step: 5,
                    text:
                        'Follow up with a written complaint if needed'),
              ],
            ),

            const SizedBox(height: 16),

            const _SectionCard(
              title: '📎 Required Documents',
              children: [
                _DocItem(text: 'Original purchase bill/receipt'),
                _DocItem(text: 'Warranty card (if provided)'),
                _DocItem(text: 'Product packaging with serial number'),
                _DocItem(text: 'Govt. ID proof (for some brands)'),
                _DocItem(text: 'Photos/videos of the defect'),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/bills/${bill.id}'),
              icon: const Icon(Icons.receipt_long_rounded),
              label: const Text('View Original Bill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimStep extends StatelessWidget {
  final int step;
  final String text;
  const _ClaimStep({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text('$step',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _DocItem extends StatelessWidget {
  final String text;
  const _DocItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
