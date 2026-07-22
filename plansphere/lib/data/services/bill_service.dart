import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/bill_model.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  void _logQuery(String action, String path) {
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('[Firestore Query] Action: $action');
    debugPrint('[Firestore Query] Path: $path');
    debugPrint('[Firestore Query] Current UID: ${user?.uid}');
    debugPrint('[Firestore Query] Current Email: ${user?.email}');
  }

  Future<String> createBill({
    required BillModel bill,
    dynamic imageFile,
    dynamic pdfFile,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final uid = user.uid;
      final projectId = _firestore.app.options.projectId;
      final email = user.email;
      final userDocPath = 'users/$uid';

      debugPrint('Firebase projectId: $projectId');
      debugPrint('Current UID: $uid');
      debugPrint('Current Email: $email');
      debugPrint('User doc path: $userDocPath');

      final id = _uuid.v4();
      String? imageUrl;
      String? pdfUrl;
      String? imageBase64;

      if (imageFile != null) {
        debugPrint('[Debug Log] Uploaded image storage path: (Bypassed: Firebase Storage disabled, using Base64)');
        imageUrl = null;
        debugPrint('[Debug Log] Download URL: (Bypassed: Firebase Storage disabled, using Base64)');

        imageBase64 = await _convertFileToBase64(imageFile);
        if (imageBase64 != null) {
          print("imageBase64 length: ${imageBase64.length}");
        }
      }

      // PDF upload is bypassed, metadata only
      pdfUrl = null;

      final billWithId = bill.copyWith(
        id: id,
        imageUrl: imageUrl,
        pdfUrl: pdfUrl,
        imageBase64: imageBase64,
        userId: uid, // Use auth guard uid
      );

      debugPrint('[Debug Log] Firestore saved imageUrl: ${billWithId.imageUrl}');
      debugPrint('[Debug Log] Firestore saved imageBase64: ${billWithId.imageBase64 != null ? (billWithId.imageBase64!.substring(0, billWithId.imageBase64!.length > 100 ? 100 : billWithId.imageBase64!.length)) : null}');

      try {
        await _firestore.collection('users').doc(uid).set({
          'email': user.email,
          'name': user.displayName ?? 'User',
          'totalBills': FieldValue.increment(0),
          'storageUsedMB': 0,
          'notificationsEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('User document exists or created successfully.');
      } catch (e) {
        debugPrint('Firestore error: $e');
        rethrow;
      }

      final billPath = '${AppConstants.usersCollection}/$uid/${AppConstants.billsCollection}';
      debugPrint('Bill save path: $billPath/$id');

      try {
        _logQuery('SET (Create Bill)', '$billPath/$id');
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('bills')
            .doc(id)
            .set(billWithId.toFirestore());

        debugPrint('Firestore query: $billPath/$id');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore result: Success');
      } catch (e) {
        debugPrint('Firestore query: $billPath/$id');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore error: $e');
        rethrow;
      }

      if (bill.hasWarranty) {
        final warrantyPath = '${AppConstants.usersCollection}/$uid/warranties';
        try {
          _logQuery('SET (Create Warranty)', '$warrantyPath/$id');
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .collection('warranties')
              .doc(id)
              .set(billWithId.toFirestore());

          debugPrint('Firestore query: $warrantyPath/$id');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore result: Success');
        } catch (e) {
          debugPrint('Firestore query: $warrantyPath/$id');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore exception: $e');
        }
      }

      try {
        _logQuery('UPDATE (Increment stats)', '${AppConstants.usersCollection}/$uid');
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({'totalBills': FieldValue.increment(1)});

        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore result: Success');
      } catch (e) {
        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore exception: $e');
      }

      return id;
    } catch (e, st) {
      debugPrint('CREATE BILL EXCEPTION: $e');
      debugPrint('STACKTRACE: $st');
      rethrow;
    }
  }

  Future<void> updateBill({
    required BillModel bill,
    dynamic imageFile,
    dynamic pdfFile,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Cannot update bill. User is not authenticated.',
        );
      }

      String? imageUrl = null;
      String? pdfUrl = null;
      String? imageBase64 = bill.imageBase64;

      if (imageFile != null) {
        debugPrint('[Debug Log] Uploaded image storage path: (Bypassed: Firebase Storage disabled, using Base64)');
        imageUrl = null;
        debugPrint('[Debug Log] Download URL: (Bypassed: Firebase Storage disabled, using Base64)');

        imageBase64 = await _convertFileToBase64(imageFile);
        if (imageBase64 != null) {
          print("imageBase64 length: ${imageBase64.length}");
        }
      }

      // PDF upload is bypassed, metadata only
      pdfUrl = null;

      final updatedBill = bill.copyWith(
        imageUrl: imageUrl,
        pdfUrl: pdfUrl,
        imageBase64: imageBase64,
        updatedAt: DateTime.now(),
        userId: uid, // Use auth guard uid
      );

      debugPrint('[Debug Log] Firestore saved imageUrl: ${updatedBill.imageUrl}');
      debugPrint('[Debug Log] Firestore saved imageBase64: ${updatedBill.imageBase64 != null ? (updatedBill.imageBase64!.substring(0, updatedBill.imageBase64!.length > 100 ? 100 : updatedBill.imageBase64!.length)) : null}');

      final billPath = '${AppConstants.usersCollection}/$uid/${AppConstants.billsCollection}';

      try {
        _logQuery('UPDATE (Update Bill)', '$billPath/${bill.id}');
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .collection(AppConstants.billsCollection)
            .doc(bill.id)
            .update(updatedBill.toFirestore());

        debugPrint('Firestore query: $billPath/${bill.id}');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore result: Success');
      } catch (e) {
        debugPrint('Firestore query: $billPath/${bill.id}');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore exception: $e');
        rethrow;
      }

      if (updatedBill.hasWarranty) {
        final warrantyPath = '${AppConstants.usersCollection}/$uid/warranties';
        try {
          _logQuery('SET (Create/Update Warranty)', '$warrantyPath/${bill.id}');
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .collection('warranties')
              .doc(bill.id)
              .set(updatedBill.toFirestore());

          debugPrint('Firestore query: $warrantyPath/${bill.id}');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore result: Success');
        } catch (e) {
          debugPrint('Firestore query: $warrantyPath/${bill.id}');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore exception: $e');
        }
      } else {
        final warrantyPath = '${AppConstants.usersCollection}/$uid/warranties';
        try {
          _logQuery('DELETE (Delete Warranty)', '$warrantyPath/${bill.id}');
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(uid)
              .collection('warranties')
              .doc(bill.id)
              .delete();

          debugPrint('Firestore query: $warrantyPath/${bill.id}');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore result: Success');
        } catch (e) {
          debugPrint('Firestore query: $warrantyPath/${bill.id}');
          debugPrint('Current UID: $uid');
          debugPrint('Firestore exception: $e');
        }
      }
    } catch (e, st) {
      debugPrint('UPDATE BILL EXCEPTION: $e');
      debugPrint('STACKTRACE: $st');
      rethrow;
    }
  }

  Future<void> deleteBill(String billId, String userId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('Delete failed: User not logged in');
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot delete bill. User is not authenticated.',
      );
    }

    final billPath = '${AppConstants.usersCollection}/$uid/${AppConstants.billsCollection}';

    debugPrint('Current UID: $uid');
    debugPrint('Bill ID: $billId');
    debugPrint('Firestore delete path: $billPath/$billId');

    // Run Storage deletes in the background without blocking UI
    _deleteStorageFilesBackground(uid, billId);

    Future<void> performFirestoreDeletes() async {
      // 1. Delete Firestore bill first
      _logQuery('DELETE (Delete Bill)', '$billPath/$billId');
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('bills')
          .doc(billId)
          .delete();

      debugPrint('Delete success: Bill document deleted successfully.');

      // 2. Delete Firestore warranty second
      final warrantyPath = '${AppConstants.usersCollection}/$uid/warranties';
      try {
        _logQuery('DELETE (Delete Warranty)', '$warrantyPath/$billId');
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('warranties')
            .doc(billId)
            .delete();

        debugPrint('Delete success: Warranty document deleted/checked.');
      } catch (e) {
        debugPrint('Delete error: Failed to delete warranty document: $e');
      }

      try {
        _logQuery('UPDATE (Decrement stats)', '${AppConstants.usersCollection}/$uid');
        await _firestore
            .collection('users')
            .doc(uid)
            .update({'totalBills': FieldValue.increment(-1)});

        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore result: Success');
      } catch (e) {
        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Current UID: $uid');
        debugPrint('Firestore exception: $e');
      }
    }

    try {
      await performFirestoreDeletes().timeout(const Duration(seconds: 5));
    } on TimeoutException catch (e) {
      debugPrint('Firestore delete timed out: $e');
      throw TimeoutException('Delete operation timed out');
    } catch (e) {
      debugPrint('Firestore delete error: $e');
      rethrow;
    }
  }

  void _deleteStorageFilesBackground(String uid, String billId) {
    _storage
        .ref('${AppConstants.billImagesPath}/$uid/$billId.jpg')
        .delete()
        .then((_) => debugPrint('Background Storage delete success: Image'))
        .catchError((e) => debugPrint('Background Storage delete failed: Image: $e'));

    _storage
        .ref('${AppConstants.billPdfsPath}/$uid/$billId.pdf')
        .delete()
        .then((_) => debugPrint('Background Storage delete success: PDF'))
        .catchError((e) => debugPrint('Background Storage delete failed: PDF: $e'));
  }

  Future<BillModel?> getBill(String billId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('Firestore query: ' + ('${AppConstants.usersCollection}/NULL/${AppConstants.billsCollection}').toString());
      debugPrint('Document: ' + (billId).toString());
      debugPrint('Description: ' + ('Get Bill Detail').toString());
      debugPrint('Firestore exception: ' + ('User is not authenticated (UID is null).').toString());
      return null;
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';

    try {
      _logQuery('GET (Get Bill)', '$billPath/$billId');
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .doc(billId)
          .get();

      debugPrint('Firestore query: $billPath/$billId');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result: ${doc.exists ? "Document exists" : "Document does not exist"}');

      if (!doc.exists) return null;
      return BillModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Firestore query error: $billPath/$billId');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Stream<List<BillModel>> streamUserBills(String userId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}');
      debugPrint('Current UID: $uid');
      debugPrint('Exception: Security guard triggered. authenticated uid: $uid, requested userId: $userId');
      return Stream.value([]);
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';
    _logQuery('STREAM (User Bills)', billPath);

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.billsCollection)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      final bills =
          snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList();

      bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bills;
    }).handleError((error) {
      debugPrint('Firestore query error: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Stream<List<BillModel>> streamBillsByCategory(String userId, String category) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return Stream.value([]);
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';
    _logQuery('STREAM (Bills By Category)', '$billPath?category=$category');

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.billsCollection)
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $billPath?category=$category');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      final bills =
          snapshot.docs.map((doc) => BillModel.fromFirestore(doc)).toList();

      bills.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return bills;
    }).handleError((error) {
      debugPrint('Firestore query error: $billPath?category=$category');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Stream<List<BillModel>> streamActiveWarranties(String userId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return Stream.value([]);
    }

    final warrantyPath = '${AppConstants.usersCollection}/$userId/warranties';
    _logQuery('STREAM (Active Warranties)', warrantyPath);

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('warranties')
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $warrantyPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      final bills = snapshot.docs
          .map((doc) => BillModel.fromFirestore(doc))
          .where(
            (bill) =>
                bill.warrantyExpiryDate != null &&
                bill.warrantyExpiryDate!.isAfter(DateTime.now()),
          )
          .toList();

      bills.sort(
        (a, b) => a.warrantyExpiryDate!.compareTo(b.warrantyExpiryDate!),
      );

      return bills;
    }).handleError((error) {
      debugPrint('Firestore query error: $warrantyPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Stream<List<BillModel>> streamExpiringSoonWarranties(String userId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return Stream.value([]);
    }

    final warrantyPath = '${AppConstants.usersCollection}/$userId/warranties';
    _logQuery('STREAM (Expiring Soon Warranties)', warrantyPath);
    final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection('warranties')
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $warrantyPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      final bills = snapshot.docs
          .map((doc) => BillModel.fromFirestore(doc))
          .where(
            (bill) =>
                bill.warrantyExpiryDate != null &&
                bill.warrantyExpiryDate!.isAfter(DateTime.now()) &&
                bill.warrantyExpiryDate!.isBefore(thirtyDaysFromNow),
          )
          .toList();

      bills.sort(
        (a, b) => a.warrantyExpiryDate!.compareTo(b.warrantyExpiryDate!),
      );

      return bills;
    }).handleError((error) {
      debugPrint('Firestore query error: $warrantyPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $error');
      throw error;
    });
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return [];
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';

    try {
      _logQuery('GET (Search Bills)', billPath);
      Query q = _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection);

      if (category != null) {
        q = q.where('category', isEqualTo: category);
      }

      final snapshot = await q.get();

      debugPrint('Firestore query: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');

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
    } catch (e) {
      debugPrint('Firestore query error: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<BillModel?> checkDuplicate({
    required String userId,
    required String ocrText,
    required double amount,
    required DateTime purchaseDate,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return null;
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';

    try {
      _logQuery('GET (Check Duplicate)', billPath);
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .where('amount', isEqualTo: amount)
          .get();

      debugPrint('Firestore query: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');

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
    } catch (e) {
      debugPrint('Firestore query error: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, double>> getMonthlyExpenses(String userId, int year) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return {};
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';

    try {
      _logQuery('GET (Monthly Expenses)', billPath);
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .get();

      debugPrint('Firestore query: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');

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
    } catch (e) {
      debugPrint('Firestore query error: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, double>> getCategoryExpenses(
    String userId,
    int year,
    int month,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      return {};
    }

    final billPath = '${AppConstants.usersCollection}/$userId/${AppConstants.billsCollection}';

    try {
      _logQuery('GET (Category Expenses)', billPath);
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.billsCollection)
          .get();

      debugPrint('Firestore query: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');

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
    } catch (e) {
      debugPrint('Firestore query error: $billPath');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<String?> _convertFileToBase64(dynamic file) async {
    if (file == null) return null;
    try {
      Uint8List bytes;
      if (file is XFile) {
        bytes = await file.readAsBytes();
      } else if (file is PlatformFile) {
        if (kIsWeb) {
          bytes = file.bytes!;
        } else {
          if (file.bytes != null) {
            bytes = file.bytes!;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          } else {
            throw ArgumentError('PlatformFile has no bytes or path');
          }
        }
      } else if (file is Uint8List) {
        bytes = file;
      } else if (file is File) {
        bytes = await file.readAsBytes();
      } else {
        throw ArgumentError('Unsupported file type');
      }
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting file to Base64: $e');
      rethrow;
    }
  }

  Future<String> _uploadFile({
    required dynamic file,
    required String path,
  }) async {
    final ref = _storage.ref(path);
    const timeoutDuration = Duration(seconds: 8);

    final extension = path.split('.').last.toLowerCase();
    final contentType = extension == 'pdf' ? 'application/pdf' : 'image/jpeg';
    final metadata = SettableMetadata(contentType: contentType);

    try {
      if (kIsWeb) {
        if (file is XFile) {
          await ref.putData(await file.readAsBytes(), metadata).timeout(timeoutDuration);
        } else if (file is PlatformFile) {
          await ref.putData(file.bytes!, metadata).timeout(timeoutDuration);
        } else if (file is Uint8List) {
          await ref.putData(file, metadata).timeout(timeoutDuration);
        } else {
          throw ArgumentError('Unsupported file type on Web');
        }
      } else {
        if (file is File) {
          await ref.putFile(file, metadata).timeout(timeoutDuration);
        } else if (file is XFile) {
          await ref.putFile(File(file.path), metadata).timeout(timeoutDuration);
        } else if (file is PlatformFile && file.path != null) {
          await ref.putFile(File(file.path!), metadata).timeout(timeoutDuration);
        } else if (file is Uint8List) {
          await ref.putData(file, metadata).timeout(timeoutDuration);
        } else {
          throw ArgumentError('Unsupported file type on Mobile');
        }
      }

      return await ref.getDownloadURL().timeout(timeoutDuration);
    } catch (storageError) {
      debugPrint('Bill file storage upload failed: $storageError. Falling back to placeholder.');
      return extension == 'pdf'
          ? 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf-test.pdf'
          : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1000';
    }
  }

  double _calculateSimilarity(String text1, String text2) {
    final words1 = text1.toLowerCase().split(' ').toSet();
    final words2 = text2.toLowerCase().split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    if (union.isEmpty) return 0;

    return intersection.length / union.length;
  }

  Future<void> shareBillPublicly(BillModel bill) async {
    try {
      _logQuery('SET (Share Bill Publicly)', 'shared_bills/${bill.id}');
      await _firestore
          .collection('shared_bills')
          .doc(bill.id)
          .set(bill.toFirestore());
    } catch (e) {
      debugPrint('Error sharing bill publicly: $e');
      rethrow;
    }
  }

  Future<BillModel?> getSharedBill(String shareId) async {
    try {
      _logQuery('GET (Get Shared Bill)', 'shared_bills/$shareId');
      final doc = await _firestore
          .collection('shared_bills')
          .doc(shareId)
          .get();

      if (!doc.exists) return null;
      return BillModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting shared bill: $e');
      rethrow;
    }
  }
}