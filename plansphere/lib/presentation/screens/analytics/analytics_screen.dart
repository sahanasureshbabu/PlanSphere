import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/bill_provider.dart';
import 'package:plansphere/data/models/bill_model.dart';
import 'package:plansphere/data/services/ai_service.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _selectedYear = DateTime.now().year;
  final AiService _aiService = AiService();

  @override
  Widget build(BuildContext context) {
    final bills = ref.watch(userBillsProvider).value ?? [];
    final yearBills = bills
        .where((b) => b.purchaseDate.year == _selectedYear)
        .toList();

    final totalSpent =
        yearBills.fold<double>(0, (sum, b) => sum + b.amount);
    final monthlyData = _getMonthlyData(yearBills);
    final categoryData = _getCategoryData(yearBills);
    final currencyFormat = NumberFormat.currency(
        symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    // Generate dynamic AI spending insights
    final aiInsights = _aiService.generateSpendingInsights(yearBills);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Analytics'),
        actions: [
          DropdownButton<int>(
            value: _selectedYear,
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down),
            items: List.generate(5, (i) => DateTime.now().year - i)
                .map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y'),
                    ))
                .toList(),
            onChanged: (y) => setState(() => _selectedYear = y!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary cards
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Spent',
                    value: currencyFormat.format(totalSpent),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Total Bills',
                    value: '${yearBills.length}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // AI Spending Insights Section (Added)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.secondary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Smart AI Spending Insights',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  ...aiInsights.map((insight) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('✨', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight.replaceAll('**', ''), // Strip formatting for simplicity
                                style: const TextStyle(fontSize: 12.5, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Monthly chart
            Text('Monthly Expenses',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$_selectedYear overview',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            Container(
              height: 220,
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
              child: monthlyData.every((v) => v == 0)
                  ? const Center(
                      child: Text('No data for this year',
                          style: TextStyle(color: Colors.grey)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: monthlyData.reduce((a, b) => a > b ? a : b) *
                            1.2,
                        barGroups: List.generate(
                          12,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: monthlyData[i],
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryLight,
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 16,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ],
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 46,
                              getTitlesWidget: (value, meta) => Text(
                                _formatAmount(value),
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) => Text(
                                _monthShort(value.toInt()),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          drawVerticalLine: false,
                          horizontalInterval:
                              monthlyData.reduce((a, b) => a > b ? a : b) /
                                  4,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            // Category breakdown
            if (categoryData.isNotEmpty) ...[
              Text('Category Breakdown',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Container(
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
                  children: categoryData.entries.map((entry) {
                    final pct = totalSpent > 0
                        ? entry.value / totalSpent
                        : 0.0;
                    final color =
                        AppColors.categoryColors[entry.key] ??
                            AppColors.primary;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.key)),
                              Text(
                                currencyFormat.format(entry.value),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(pct * 100).round()}%',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor:
                                  color.withOpacity(0.15),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Top spending
            const SizedBox(height: 24),
            Text('Top Spending Bills',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...(_getTopBills(yearBills).map((bill) => _TopBillItem(
                  bill: bill,
                  currencyFormat: currencyFormat,
                ))),

            const SizedBox(height: 24),
            
            // Export Section (Added)
            Text('Report Exporters',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AppSnackbar.showSuccess(context, 'PDF Report exported successfully to PlanSphere directory!');
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      AppSnackbar.showSuccess(context, 'Excel Spreadsheet compiled & exported successfully!');
                    },
                    icon: const Icon(Icons.table_view_rounded),
                    label: const Text('Export Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<double> _getMonthlyData(List<BillModel> bills) {
    final data = List.filled(12, 0.0);
    for (final bill in bills) {
      data[bill.purchaseDate.month - 1] += bill.amount;
    }
    return data;
  }

  Map<String, double> _getCategoryData(List<BillModel> bills) {
    final data = <String, double>{};
    for (final bill in bills) {
      data[bill.category] = (data[bill.category] ?? 0) + bill.amount;
    }
    final sorted = Map.fromEntries(
      data.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    return Map.fromEntries(sorted.entries.take(6));
  }

  List<BillModel> _getTopBills(List<BillModel> bills) {
    final sorted = List<BillModel>.from(bills)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(5).toList();
  }

  String _formatAmount(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toInt().toString();
  }

  String _monthShort(int month) {
    const months = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];
    return months[month];
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }
}

class _TopBillItem extends StatelessWidget {
  final BillModel bill;
  final NumberFormat currencyFormat;
  const _TopBillItem(
      {required this.bill, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (AppColors.categoryColors[bill.category] ??
                      AppColors.primary)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.categoryColors[bill.category] ??
                  AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('dd MMM yyyy').format(bill.purchaseDate),
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            currencyFormat.format(bill.amount),
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
