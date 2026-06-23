import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';

class SharedBillView extends ConsumerWidget {
  final String shareId;
  const SharedBillView({super.key, required this.shareId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sharedBillAsync = ref.watch(sharedBillProvider(shareId));
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Shared Bill - PlanSphere'),
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: sharedBillAsync.when(
        data: (bill) {
          if (bill == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                    SizedBox(height: 16),
                    Text(
                      'Shared Bill Not Found',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The link might have expired or the bill is no longer shared.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildContent(context, bill, currencyFormat);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading shared bill',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BillModel bill, NumberFormat currencyFormat) {
    final isWide = MediaQuery.of(context).size.width > 800;

    final imageWidget = (bill.imageBase64 != null && bill.imageBase64!.isNotEmpty)
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                base64Decode(bill.imageBase64!),
                fit: BoxFit.contain,
              ),
            ),
          )
        : Container(
            height: 250,
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No receipt image available', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );

    final detailsCard = Card(
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _CategoryChip(category: bill.category),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bill.brand,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white),
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(bill.purchaseDate),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.darkDivider),
            _DetailRow(icon: Icons.store_rounded, label: 'Store Name', value: bill.storeName),
            _DetailRow(icon: Icons.branding_watermark_rounded, label: 'Product Brand', value: bill.brand),
            _DetailRow(icon: Icons.numbers_rounded, label: 'Invoice reference', value: bill.id.substring(0, 8).toUpperCase()),
            if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty)
              _DetailRow(icon: Icons.percent_rounded, label: 'GST Number', value: bill.gstNumber!),
            if (bill.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Description / Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(bill.description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ],
            if (bill.hasWarranty) ...[
              const Divider(height: 32, color: AppColors.darkDivider),
              const Text('Warranty Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.security_rounded,
                label: 'Warranty Status',
                value: bill.warrantyStatus == WarrantyStatus.active
                    ? 'Active'
                    : bill.warrantyStatus == WarrantyStatus.expiringSoon
                        ? 'Expiring Soon'
                        : bill.warrantyStatus == WarrantyStatus.expired
                            ? 'Expired'
                            : 'No Warranty',
              ),
              if (bill.warrantyDurationMonths != null)
                _DetailRow(
                  icon: Icons.av_timer_rounded,
                  label: 'Duration',
                  value: '${bill.warrantyDurationMonths} Months',
                ),
              if (bill.warrantyExpiryDate != null)
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Expiry Date',
                  value: DateFormat('dd MMM yyyy').format(bill.warrantyExpiryDate!),
                ),
            ],
          ],
        ),
      ),
    );

    if (isWide) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: imageWidget,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: detailsCard,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          detailsCard,
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Bill Image',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Center(child: imageWidget),
        ],
      ),
    );
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
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
