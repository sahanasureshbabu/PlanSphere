import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:plansphere/core/constants/app_colors.dart';

/// Calculates and displays a "Bill Health Score" based on:
/// - Warranty coverage
/// - Document completeness
/// - Backup status
/// - Spending trends
class BillHealthScore extends StatelessWidget {
  final int totalBills;
  final int billsWithWarranty;
  final int billsWithImages;
  final bool hasBackup;
  final double monthlySpendChange; // % change vs last month

  const BillHealthScore({
    super.key,
    required this.totalBills,
    required this.billsWithWarranty,
    required this.billsWithImages,
    required this.hasBackup,
    required this.monthlySpendChange,
  });

  double get score {
    if (totalBills == 0) return 0;
    double s = 0;
    // 40% weight: warranty coverage
    s += (billsWithWarranty / totalBills).clamp(0, 1) * 40;
    // 30% weight: image/PDF coverage
    s += (billsWithImages / totalBills).clamp(0, 1) * 30;
    // 20% weight: backup
    s += hasBackup ? 20 : 0;
    // 10% weight: spend control
    s += monthlySpendChange <= 0 ? 10 : (monthlySpendChange <= 20 ? 5 : 0);
    return s.clamp(0, 100);
  }

  String get grade {
    if (score >= 85) return 'A+';
    if (score >= 75) return 'A';
    if (score >= 65) return 'B+';
    if (score >= 55) return 'B';
    if (score >= 45) return 'C';
    return 'D';
  }

  Color get gradeColor {
    if (score >= 75) return AppColors.success;
    if (score >= 55) return AppColors.warning;
    return AppColors.error;
  }

  String get description {
    if (score >= 85) return 'Excellent! Your bills are well managed.';
    if (score >= 75) return 'Good! Keep tracking your warranties.';
    if (score >= 55) return 'Fair. Consider adding more bill images.';
    return 'Needs attention. Start adding your bills.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Bill Health Score',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(grade,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: gradeColor)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircularPercentIndicator(
                radius: 48,
                lineWidth: 8,
                percent: score / 100,
                center: Text(
                  '${score.round()}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: gradeColor,
                  ),
                ),
                progressColor: gradeColor,
                backgroundColor: gradeColor.withOpacity(0.15),
                circularStrokeCap: CircularStrokeCap.round,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    _ScoreFactor(
                        label: 'Warranty Coverage',
                        value: totalBills > 0
                            ? (billsWithWarranty / totalBills * 100)
                                .round()
                            : 0,
                        color: AppColors.success),
                    _ScoreFactor(
                        label: 'Document Coverage',
                        value: totalBills > 0
                            ? (billsWithImages / totalBills * 100)
                                .round()
                            : 0,
                        color: AppColors.info),
                    _ScoreFactor(
                        label: 'Backup Status',
                        value: hasBackup ? 100 : 0,
                        color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreFactor extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _ScoreFactor(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Text('$value%',
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
