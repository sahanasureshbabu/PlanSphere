import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';

class ClaimAssistantScreen extends ConsumerWidget {
  const ClaimAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(userBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim Assistant'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: billsAsync.when(
        data: (bills) {
          final claimBills = bills.where((b) => b.hasWarranty).toList();
          if (claimBills.isEmpty) {
            return _buildEmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: claimBills.length,
            itemBuilder: (context, index) {
              final bill = claimBills[index];
              return _ClaimCard(bill: bill);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'Unable to load claims',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(userBillsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Warranty Items Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add bills with warranty to use the\nClaim Assistant.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ClaimCard extends StatelessWidget {
  final BillModel bill;
  const _ClaimCard({required this.bill});

  @override
  Widget build(BuildContext context) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => context.push('/bills/${bill.id}', extra: 3), // Open with Claim tab
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: claimColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.assignment_rounded, color: claimColor, size: 24),
        ),
        title: Text(
          bill.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Status: $claimText'),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
