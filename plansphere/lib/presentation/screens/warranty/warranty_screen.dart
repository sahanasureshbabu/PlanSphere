import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';

class WarrantyScreen extends ConsumerStatefulWidget {
  const WarrantyScreen({super.key});

  @override
  ConsumerState<WarrantyScreen> createState() => _WarrantyScreenState();
}

class _WarrantyScreenState extends ConsumerState<WarrantyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final allBills = ref.watch(userBillsProvider).asData?.value ?? [];
    final warrantyBills = allBills.where((b) => b.hasWarranty).toList();

    final active = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.active)
        .toList();
    final expiringSoon = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.expiringSoon)
        .toList();
    final expired = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.expired)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranty Tracker'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Active (${active.length})'),
            Tab(text: 'Expiring (${expiringSoon.length})'),
            Tab(text: 'Expired (${expired.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WarrantyList(bills: active, status: WarrantyStatus.active),
          _WarrantyList(
              bills: expiringSoon, status: WarrantyStatus.expiringSoon),
          _WarrantyList(bills: expired, status: WarrantyStatus.expired),
        ],
      ),
    );
  }
}

class _WarrantyList extends StatelessWidget {
  final List<BillModel> bills;
  final WarrantyStatus status;
  const _WarrantyList({required this.bills, required this.status});

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == WarrantyStatus.active
                  ? Icons.verified_rounded
                  : status == WarrantyStatus.expiringSoon
                      ? Icons.warning_amber_rounded
                      : Icons.cancel_rounded,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              status == WarrantyStatus.active
                  ? 'No active warranties'
                  : status == WarrantyStatus.expiringSoon
                      ? 'No warranties expiring soon'
                      : 'No expired warranties',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 650;
    if (isWide) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 500,
              mainAxisExtent: 115,
              crossAxisSpacing: 16,
              mainAxisSpacing: 0,
            ),
            itemCount: bills.length,
            itemBuilder: (ctx, i) =>
                _WarrantyCard(bill: bills[i]).animate().fadeIn(delay: (i * 60).ms),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      itemBuilder: (ctx, i) =>
          _WarrantyCard(bill: bills[i]).animate().fadeIn(delay: (i * 60).ms),
    );
  }
}

class _WarrantyCard extends StatelessWidget {
  final BillModel bill;
  const _WarrantyCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final status = bill.warrantyStatus;
    final days = bill.daysUntilWarrantyExpiry;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case WarrantyStatus.active:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case WarrantyStatus.expiringSoon:
        statusColor = AppColors.warning;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case WarrantyStatus.expired:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
    }

    return GestureDetector(
      onTap: () => context.push('/warranty/${bill.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.storeName.isNotEmpty
                        ? bill.storeName
                        : bill.category,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Progress indicator
                  _WarrantyProgressBar(bill: bill, color: statusColor),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (days != null && days >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$days d',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                if (bill.warrantyExpiryDate != null)
                  Text(
                    DateFormat('dd MMM yy')
                        .format(bill.warrantyExpiryDate!),
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WarrantyProgressBar extends StatelessWidget {
  final BillModel bill;
  final Color color;
  const _WarrantyProgressBar(
      {required this.bill, required this.color});

  @override
  Widget build(BuildContext context) {
    if (bill.warrantyExpiryDate == null ||
        bill.warrantyDurationMonths == null) {
      return const SizedBox();
    }
    final total = bill.warrantyDurationMonths! * 30.0;
    final remaining =
        bill.daysUntilWarrantyExpiry?.clamp(0, total.toInt()) ?? 0;
    final progress = (remaining / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${bill.warrantyDurationMonths}mo warranty',
          style: TextStyle(color: Colors.grey[400], fontSize: 10),
        ),
      ],
    );
  }
}
