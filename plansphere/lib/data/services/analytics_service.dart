import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    final billsSnap = await _firestore
        .collection(AppConstants.billsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final bills =
        billsSnap.docs.map((d) => BillModel.fromFirestore(d)).toList();

    final now = DateTime.now();
    final thisMonth =
        bills.where((b) => b.purchaseDate.month == now.month &&
            b.purchaseDate.year == now.year);
    final thisYear =
        bills.where((b) => b.purchaseDate.year == now.year);

    double thisMonthSpend =
        thisMonth.fold(0, (sum, b) => sum + b.amount);
    double thisYearSpend =
        thisYear.fold(0, (sum, b) => sum + b.amount);
    double totalSpend = bills.fold(0, (sum, b) => sum + b.amount);

    // Category breakdown
    final categoryMap = <String, double>{};
    for (final bill in bills) {
      categoryMap[bill.category] =
          (categoryMap[bill.category] ?? 0) + bill.amount;
    }

    // Monthly breakdown for current year
    final monthlyMap = List.filled(12, 0.0);
    for (final bill in thisYear) {
      monthlyMap[bill.purchaseDate.month - 1] += bill.amount;
    }

    // Warranty stats
    final warrantyBills = bills.where((b) => b.hasWarranty);
    final activeWarranties = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.active)
        .length;
    final expiringSoon = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.expiringSoon)
        .length;
    final expired = warrantyBills
        .where((b) => b.warrantyStatus == WarrantyStatus.expired)
        .length;

    return {
      'totalBills': bills.length,
      'totalSpend': totalSpend,
      'thisMonthSpend': thisMonthSpend,
      'thisYearSpend': thisYearSpend,
      'categoryBreakdown': categoryMap,
      'monthlyBreakdown': monthlyMap,
      'activeWarranties': activeWarranties,
      'expiringSoon': expiringSoon,
      'expiredWarranties': expired,
      'avgBillAmount':
          bills.isNotEmpty ? totalSpend / bills.length : 0,
    };
  }

  Future<void> updateUserAnalytics(
      String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection(AppConstants.analyticsCollection)
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getCachedAnalytics(
      String userId) async {
    final doc = await _firestore
        .collection(AppConstants.analyticsCollection)
        .doc(userId)
        .get();
    return doc.exists ? doc.data() : null;
  }
}
