import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference get _billsRef =>
      _firestore.collection(AppConstants.billsCollection);

  Future<String> createBill({
    required BillModel bill,
    File? imageFile,
    File? pdfFile,
  }) async {
    final id = _uuid.v4();
    String? imageUrl;
    String? pdfUrl;

    try {
      if (imageFile != null) {
        imageUrl = await _uploadFile(
          file: imageFile,
          path: '${AppConstants.billImagesPath}/${bill.userId}/$id.jpg',
        );
      }
    } catch (e) {
      debugPrint('IMAGE UPLOAD FAILED, SAVING BILL WITHOUT IMAGE: $e');
      imageUrl = null;
    }

    try {
      if (pdfFile != null) {
        pdfUrl = await _uploadFile(
          file: pdfFile,
          path: '${AppConstants.billPdfsPath}/${bill.userId}/$id.pdf',
        );
      }
    } catch (e) {
      debugPrint('PDF UPLOAD FAILED, SAVING BILL WITHOUT PDF: $e');
      pdfUrl = null;
    }

    final billWithId = bill.copyWith(
      id: id,
      imageUrl: imageUrl,
      pdfUrl: pdfUrl,
    );

    await _billsRef.doc(id).set(billWithId.toFirestore());

    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(bill.userId)
          .update({'totalBills': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('USER BILL COUNT UPDATE FAILED: $e');
    }

    return id;
  }

  Future<void> updateBill({
    required BillModel bill,
    File? imageFile,
    File? pdfFile,
  }) async {
    String? imageUrl = bill.imageUrl;
    String? pdfUrl = bill.pdfUrl;

    try {
      if (imageFile != null) {
        imageUrl = await _uploadFile(
          file: imageFile,
          path: '${AppConstants.billImagesPath}/${bill.userId}/${bill.id}.jpg',
        );
      }
    } catch (e) {
      debugPrint('IMAGE UPDATE FAILED, KEEPING OLD IMAGE: $e');
    }

    try {
      if (pdfFile != null) {
        pdfUrl = await _uploadFile(
          file: pdfFile,
          path: '${AppConstants.billPdfsPath}/${bill.userId}/${bill.id}.pdf',
        );
      }
    } catch (e) {
      debugPrint('PDF UPDATE FAILED, KEEPING OLD PDF: $e');
    }

    final updatedBill = bill.copyWith(
      imageUrl: imageUrl,
      pdfUrl: pdfUrl,
      updatedAt: DateTime.now(),
    );

    await _billsRef.doc(bill.id).update(updatedBill.toFirestore());
  }

  Future<void> deleteBill(String billId, String userId) async {
    try {
      await _storage
          .ref('${AppConstants.billImagesPath}/$userId/$billId.jpg')
          .delete();
    } catch (_) {}

    try {
      await _storage
          .ref('${AppConstants.billPdfsPath}/$userId/$billId.pdf')
          .delete();
    } catch (_) {}

    await _billsRef.doc(billId).delete();

    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'totalBills': FieldValue.increment(-1)});
    } catch (e) {
      debugPrint('USER BILL COUNT DECREMENT FAILED: $e');
    }
  }

  Future<BillModel?> getBill(String billId) async {
    final doc = await _billsRef.doc(billId).get();
    if (!doc.exists) return null;
    return BillModel.fromFirestore(doc);
  }

  Stream<List<BillModel>> streamUserBills(String userId) {
    return _billsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<BillModel>> streamBillsByCategory(String userId, String category) {
    return _billsRef
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<BillModel>> streamActiveWarranties(String userId) {
    return _billsRef
        .where('userId', isEqualTo: userId)
        .where('hasWarranty', isEqualTo: true)
        .orderBy('warrantyExpiryDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillModel.fromFirestore(doc))
            .where((bill) =>
                bill.warrantyExpiryDate != null &&
                bill.warrantyExpiryDate!.isAfter(DateTime.now()))
            .toList());
  }

  Stream<List<BillModel>> streamExpiringSoonWarranties(String userId) {
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));

    return _billsRef
        .where('userId', isEqualTo: userId)
        .where('hasWarranty', isEqualTo: true)
        .orderBy('warrantyExpiryDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillModel.fromFirestore(doc))
            .where((bill) =>
                bill.warrantyExpiryDate != null &&
                bill.warrantyExpiryDate!.isAfter(DateTime.now()) &&
                bill.warrantyExpiryDate!.isBefore(thirtyDaysFromNow))
            .toList());
  }

  Future<List<BillModel>> searchBills({
    required String userId,
    required String query,
    String? category,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query q = _billsRef.where('userId', isEqualTo: userId);

    if (category != null) q = q.where('category', isEqualTo: category);

    final snapshot = await q.get();

    List<BillModel> bills =
        snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList();

    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();

      bills = bills.where((bill) {
        return bill.title.toLowerCase().contains(lowerQuery) ||
            bill.storeName.toLowerCase().contains(lowerQuery) ||
            bill.description.toLowerCase().contains(lowerQuery) ||
            bill.tags.any((t) => t.toLowerCase().contains(lowerQuery)) ||
            (bill.productName?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }

    if (minAmount != null) {
      bills = bills.where((b) => b.amount >= minAmount).toList();
    }

    if (maxAmount != null) {
      bills = bills.where((b) => b.amount <= maxAmount).toList();
    }

    if (startDate != null) {
      bills = bills.where((b) => b.purchaseDate.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      bills = bills.where((b) => b.purchaseDate.isBefore(endDate)).toList();
    }

    return bills;
  }

  Future<BillModel?> checkDuplicate({
    required String userId,
    required String ocrText,
    required double amount,
    required DateTime purchaseDate,
  }) async {
    final snapshot = await _billsRef
        .where('userId', isEqualTo: userId)
        .where('amount', isEqualTo: amount)
        .get();

    for (final doc in snapshot.docs) {
      final bill = BillModel.fromFirestore(doc);

      if (bill.purchaseDate.year == purchaseDate.year &&
          bill.purchaseDate.month == purchaseDate.month &&
          bill.purchaseDate.day == purchaseDate.day) {
        return bill;
      }

      if (ocrText.isNotEmpty && (bill.ocrText?.isNotEmpty ?? false)) {
        final similarity = _calculateSimilarity(ocrText, bill.ocrText!);
        if (similarity > 0.8) return bill;
      }
    }

    return null;
  }

  Future<Map<String, double>> getMonthlyExpenses(String userId, int year) async {
    final snapshot = await _billsRef.where('userId', isEqualTo: userId).get();

    final Map<String, double> monthlyExpenses = {};

    for (var i = 1; i <= 12; i++) {
      monthlyExpenses[i.toString()] = 0;
    }

    for (final doc in snapshot.docs) {
      final bill = BillModel.fromFirestore(doc);

      if (bill.purchaseDate.year == year) {
        final month = bill.purchaseDate.month.toString();
        monthlyExpenses[month] = (monthlyExpenses[month] ?? 0) + bill.amount;
      }
    }

    return monthlyExpenses;
  }

  Future<Map<String, double>> getCategoryExpenses(
    String userId,
    int year,
    int month,
  ) async {
    final snapshot = await _billsRef.where('userId', isEqualTo: userId).get();

    final Map<String, double> categoryExpenses = {};

    for (final doc in snapshot.docs) {
      final bill = BillModel.fromFirestore(doc);

      if (bill.purchaseDate.year == year &&
          (month == 0 || bill.purchaseDate.month == month)) {
        categoryExpenses[bill.category] =
            (categoryExpenses[bill.category] ?? 0) + bill.amount;
      }
    }

    return categoryExpenses;
  }

  Future<String> _uploadFile({
    required File file,
    required String path,
  }) async {
    final ref = _storage.ref(path);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  double _calculateSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(' ').toSet();
    final words2 = text2.toLowerCase().split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    if (union.isEmpty) return 0;

    return intersection.length / union.length;
  }
}