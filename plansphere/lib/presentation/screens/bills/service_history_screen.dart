import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/models/maintenance_model.dart';

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
          for (final bill in bills) {
            for (final log in bill.serviceHistory) {
              allLogs.add(_ServiceLogItem(bill: bill, log: log));
            }
          }
          
          allLogs.sort((a, b) => b.log.serviceDate.compareTo(a.log.serviceDate));

          if (allLogs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allLogs.length,
            itemBuilder: (context, index) {
              final item = allLogs[index];
              return _ServiceLogCard(item: item, currencyFormat: currencyFormat);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState() {
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

class _ServiceLogCard extends StatelessWidget {
  final _ServiceLogItem item;
  final NumberFormat currencyFormat;

  const _ServiceLogCard({required this.item, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => context.push('/bills/${item.bill.id}', extra: 1), // Open with Services tab
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: const Icon(Icons.build_circle_rounded, color: AppColors.primary),
        ),
        title: Text(
          item.bill.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.log.technicianName} • ${DateFormat('dd MMM yyyy').format(item.log.serviceDate)}'),
            const SizedBox(height: 2),
            Text(
              item.log.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Text(
          currencyFormat.format(item.log.cost),
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
    );
  }
}
