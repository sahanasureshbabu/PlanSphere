import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getUserAnalytics(String userId) async {
    QuerySnapshot billsSnap;
    try {
      billsSnap = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .get();

      debugPrint('Firestore query: ${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}');
      debugPrint('Description: Get User Bills for Analytics');
      debugPrint('Firestore result count: ${billsSnap.docs.length}');
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}');
      debugPrint('Description: Get User Bills for Analytics');
      debugPrint('Exception: $e');
      rethrow;
    }

    final bills =
        billsSnap.docs.map((d) => BillModel.fromFirestore(d)).toList();

    final now = DateTime.now();
    final thisMonth =
        bills.where((b) => b.purchaseDate.month == now.month &&
            b.purchaseDate.year == now.year);
    final thisYear =
        bills.where((b) => b.purchaseDate.year == now.year);

    double thisMonthSpend =
        thisMonth.fold(0, (amountSum, b) => amountSum + b.amount);
    double thisYearSpend =
        thisYear.fold(0, (amountSum, b) => amountSum + b.amount);
    double totalSpend = bills.fold(0, (amountSum, b) => amountSum + b.amount);

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
    try {
      await _firestore
          .collection(AppConstants.analyticsCollection)
          .doc(userId)
          .set(data, SetOptions(merge: true));

      debugPrint('Firestore query: ${AppConstants.analyticsCollection}/$userId');
      debugPrint('Description: Update User Analytics');
      debugPrint('Firestore result: Success');
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.analyticsCollection}/$userId');
      debugPrint('Description: Update User Analytics');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCachedAnalytics(
      String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.analyticsCollection)
          .doc(userId)
          .get();

      debugPrint('Firestore query: ${AppConstants.analyticsCollection}/$userId');
      debugPrint('Description: Get Cached Analytics');
      debugPrint('Firestore result: ${doc.exists ? "Document exists" : "Document does not exist"}');

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.analyticsCollection}/$userId');
      debugPrint('Description: Get Cached Analytics');
      debugPrint('Exception: $e');
      rethrow;
    }
  }
}

