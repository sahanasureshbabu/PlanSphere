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
import 'package:plansphere/core/utils/responsive_layout.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final stats = ref.watch(billStatsProvider);
    final recentBills = ref.watch(userBillsProvider);
    final expiringSoon = ref.watch(expiringSoonWarrantiesProvider);
    final documents = ref.watch(userDocumentsProvider);
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 0,
      locale: 'en_IN',
    );

    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.split(' ').first
        : 'Sahana';

    final isWide = ResponsiveLayout.isWide(context);

    if (isWide) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR / HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $name! 👋',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d').format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        // Total Spent Card
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Total Spent: ${currencyFormat.format(stats.totalExpenses)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // STATS GRID (4 Columns instead of 2)
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.8,
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
                          value: '${documents.asData?.value?.length ?? 0}',
                          icon: Icons.folder_rounded,
                          color: AppColors.info,
                          onTap: () => context.go('/documents'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // SPLIT GRID (Recent Bills on Left, Quick Actions & Expiries on Right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Recent Bills)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'Recent Bills'),
                              const SizedBox(height: 12),
                              recentBills.when(
                                data: (bills) {
                                  if (bills.isEmpty) {
                                    return _EmptyState(
                                      icon: Icons.receipt_long_rounded,
                                      title: 'No bills found',
                                      subtitle: 'Tap + to add your first bill',
                                      onAction: () => context.push('/bills/add'),
                                      actionLabel: 'Add Bill',
                                    );
                                  }
                                  return Column(
                                    children: bills
                                        .take(8)
                                        .map((bill) => BillListItem(bill: bill))
                                        .toList(),
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => _EmptyState(
                                  icon: Icons.receipt_long_rounded,
                                  title: 'No bills found',
                                  subtitle: 'Tap + to add your first bill',
                                  onAction: () => context.push('/bills/add'),
                                  actionLabel: 'Add Bill',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Column (Quick Actions & Expiries)
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'Quick Actions'),
                              const SizedBox(height: 12),
                              // Grid for quick actions
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 1.3,
                                children: [
                                  _QuickActionGrid(
                                    icon: Icons.add_rounded,
                                    label: 'Add Bill',
                                    color: AppColors.primary,
                                    onTap: () => context.push('/bills/add'),
                                  ),
                                  _QuickActionGrid(
                                    icon: Icons.document_scanner_rounded,
                                    label: 'Scan Bill',
                                    color: AppColors.secondary,
                                    onTap: () => context.push('/scanner'),
                                  ),
                                  _QuickActionGrid(
                                    icon: Icons.shield_rounded,
                                    label: 'AMC',
                                    color: const Color(0xFFE67E22),
                                    onTap: () => context.push('/amc'),
                                  ),
                                  _QuickActionGrid(
                                    icon: Icons.engineering_rounded,
                                    label: 'Service',
                                    color: const Color(0xFF34495E),
                                    onTap: () => context.push('/service-history'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              expiringSoon.when(
                                data: (bills) {
                                  if (bills.isEmpty) return const SizedBox();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SectionHeader(
                                        title: '⚠️ Expiring Soon',
                                      ),
                                      const SizedBox(height: 12),
                                      ...bills
                                          .take(3)
                                          .map((bill) => _ExpiryWarningCard(bill: bill)),
                                    ],
                                  );
                                },
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

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
            title: Row(
              children: [
                Image.asset(
                  'assets/images/app_logo.png',
                  height: 24,
                  width: 24,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                const Text(
                  'PlanSphere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
                        value: '${documents.asData?.value?.length ?? 0}',
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
                          title: 'No bills found',
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
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: _EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'No bills found',
                        subtitle: 'Tap + to add your first bill',
                        onAction: () => context.push('/bills/add'),
                        actionLabel: 'Add Bill',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF111827),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF374151),
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

class _QuickActionGrid extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionGrid({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final double padding = height < 80 ? 8.0 : 12.0;
          final double iconSize = height < 80 ? 16.0 : 20.0;
          final double iconPadding = height < 80 ? 6.0 : 8.0;
          final double fontSize = height < 80 ? 10.0 : 12.0;
          final double gap = height < 80 ? 4.0 : 8.0;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkDivider : const Color(0xFFE5E7EB),
              ),
            ),
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                ),
                SizedBox(height: gap),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
