import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/data/services/bill_service.dart';
import 'package:plansphere/data/models/bill_model.dart';

final billServiceProvider = Provider<BillService>((ref) => BillService());

final firebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userBillsProvider = StreamProvider<List<BillModel>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Stream.value([]);
  }

  return ref.read(billServiceProvider).streamUserBills(user.uid);
});

final activeWarrantiesProvider = StreamProvider<List<BillModel>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Stream.value([]);
  }

  return ref.read(billServiceProvider).streamActiveWarranties(user.uid);
});

final expiringSoonWarrantiesProvider = StreamProvider<List<BillModel>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Stream.value([]);
  }

  return ref.read(billServiceProvider).streamExpiringSoonWarranties(user.uid);
});

final billsByCategory =
    StreamProviderFamily<List<BillModel>, String>((ref, category) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Stream.value([]);
  }

  return ref.read(billServiceProvider).streamBillsByCategory(
        user.uid,
        category,
      );
});

final selectedBillProvider =
    FutureProviderFamily<BillModel?, String>((ref, billId) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Future.value(null);
  }

  return ref.read(billServiceProvider).getBill(billId);
});

final sharedBillProvider =
    FutureProviderFamily<BillModel?, String>((ref, shareId) {
  return ref.read(billServiceProvider).getSharedBill(shareId);
});

final billStatsProvider = Provider((ref) {
  final bills = ref.watch(userBillsProvider).asData?.value ?? [];
  final activeWarranties =
      ref.watch(activeWarrantiesProvider).asData?.value ?? [];
  final expiringSoon =
      ref.watch(expiringSoonWarrantiesProvider).asData?.value ?? [];

  double totalExpenses = 0;

  for (final bill in bills) {
    totalExpenses += bill.amount;
  }

  return BillStats(
    totalBills: bills.length,
    activeWarranties: activeWarranties.length,
    expiringSoon: expiringSoon.length,
    totalExpenses: totalExpenses,
  );
});

class BillStats {
  final int totalBills;
  final int activeWarranties;
  final int expiringSoon;
  final double totalExpenses;

  const BillStats({
    required this.totalBills,
    required this.activeWarranties,
    required this.expiringSoon,
    required this.totalExpenses,
  });
}

class BillCrudNotifier extends StateNotifier<AsyncValue<void>> {
  final BillService _service;

  BillCrudNotifier(this._service) : super(const AsyncValue.data(null));

  Future<String?> addBill({
    required BillModel bill,
    dynamic imageFile,
    dynamic pdfFile,
  }) async {
    state = const AsyncValue.loading();

    try {
      final id = await _service.createBill(
        bill: bill,
        imageFile: imageFile,
        pdfFile: pdfFile,
      );

      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> updateBill({
    required BillModel bill,
    dynamic imageFile,
    dynamic pdfFile,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _service.updateBill(
        bill: bill,
        imageFile: imageFile,
        pdfFile: pdfFile,
      );

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteBill(String billId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    state = const AsyncValue.loading();

    try {
      await _service.deleteBill(billId, user.uid);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final billCrudProvider =
    StateNotifierProvider<BillCrudNotifier, AsyncValue<void>>((ref) {
  return BillCrudNotifier(
    ref.read(billServiceProvider),
  );
});