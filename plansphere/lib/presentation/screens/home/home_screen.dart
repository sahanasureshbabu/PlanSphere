import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/stat_card.dart';
import 'package:plansphere/core/widgets/bill_list_item.dart';
import 'package:plansphere/core/widgets/section_header.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/presentation/providers/document_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final stats = ref.watch(billStatsProvider);
    final recentBills = ref.watch(userBillsProvider);
    final expiringSoon = ref.watch(expiringSoonWarrantiesProvider);
    final documents = ref.watch(userDocumentsProvider);
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );

    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.split(' ').first
        : 'Sahana';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            pinned: true,
            floating: false,
            elevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            title: const Text(
              'PlanSphere',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              _IconBtn(
                icon: Icons.search_rounded,
                onTap: () => context.push('/search'),
              ),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.notifications_outlined,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(width: 8),
              _ProfileBtn(user: user),
              const SizedBox(width: 8),
              _IconBtn(
                icon: Icons.settings_outlined,
                onTap: () => context.push('/settings'),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $name! 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(45),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Total Spent: ${currencyFormat.format(stats.totalExpenses)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        title: 'Total Bills',
                        value: '${stats.totalBills}',
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        onTap: () => context.go('/bills'),
                      ),
                      StatCard(
                        title: 'Active Warranties',
                        value: '${stats.activeWarranties}',
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                        onTap: () => context.go('/warranty'),
                      ),
                      StatCard(
                        title: 'Expiring Soon',
                        value: '${stats.expiringSoon}',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        onTap: () => context.go('/warranty'),
                      ),
                      StatCard(
                        title: 'Documents',
                        value: '${documents.value?.length ?? 0}',
                        icon: Icons.folder_rounded,
                        color: AppColors.info,
                        onTap: () => context.go('/documents'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  const SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _QuickAction(
                          icon: Icons.add_rounded,
                          label: 'Add Bill',
                          color: AppColors.primary,
                          onTap: () => context.push('/bills/add'),
                        ),
                        _QuickAction(
                          icon: Icons.document_scanner_rounded,
                          label: 'Scan Bill',
                          color: AppColors.secondary,
                          onTap: () => context.push('/scanner'),
                        ),
                        _QuickAction(
                          icon: Icons.receipt_long_rounded,
                          label: 'My Bills',
                          color: AppColors.accent,
                          onTap: () => context.go('/bills'),
                        ),
                        _QuickAction(
                          icon: Icons.verified_rounded,
                          label: 'Warranty',
                          color: AppColors.success,
                          onTap: () => context.go('/warranty'),
                        ),
                        _QuickAction(
                          icon: Icons.shield_rounded,
                          label: 'AMC',
                          color: const Color(0xFFE67E22),
                          onTap: () => context.push('/amc'),
                        ),
                        _QuickAction(
                          icon: Icons.engineering_rounded,
                          label: 'Service',
                          color: const Color(0xFF34495E),
                          onTap: () => context.push('/service-history'),
                        ),
                        _QuickAction(
                          icon: Icons.assignment_turned_in_rounded,
                          label: 'Claims',
                          color: const Color(0xFFE74C3C),
                          onTap: () => context.push('/claim-assistant'),
                        ),
                        _QuickAction(
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          color: AppColors.warning,
                          onTap: () => context.go('/analytics'),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  expiringSoon.when(
                    data: (bills) {
                      if (bills.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: '⚠️ Expiring Soon',
                            actionLabel: 'View All',
                            onAction: () => context.go('/warranty'),
                          ),
                          const SizedBox(height: 12),
                          ...bills
                              .take(2)
                              .map((bill) => _ExpiryWarningCard(bill: bill)),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),

                  SectionHeader(
                    title: 'Recent Bills',
                    actionLabel: 'View All',
                    onAction: () => context.go('/bills'),
                  ),
                  const SizedBox(height: 12),

                  recentBills.when(
                    data: (bills) {
                      if (bills.isEmpty) {
                        return _EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'No bills yet',
                          subtitle: 'Tap + to add your first bill',
                          onAction: () => context.push('/bills/add'),
                          actionLabel: 'Add Bill',
                        );
                      }

                      return Column(
                        children: bills
                            .take(5)
                            .map((bill) => BillListItem(bill: bill))
                            .toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error: $e',
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(45),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 19,
        ),
      ),
    );
  }
}

class _ProfileBtn extends StatelessWidget {
  final User? user;

  const _ProfileBtn({required this.user});

  @override
  Widget build(BuildContext context) {
    final letter = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.substring(0, 1).toUpperCase()
        : 'S';

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => context.push('/profile'),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(45),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: user?.photoURL != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.network(
                  user!.photoURL!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              )
            : Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(28),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiryWarningCard extends StatelessWidget {
  final dynamic bill;

  const _ExpiryWarningCard({required this.bill});

  @override
  Widget build(BuildContext context) {
    final days = bill.daysUntilWarrantyExpiry ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bill.title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Expires in $days days',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).push('/warranty/${bill.id}'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}