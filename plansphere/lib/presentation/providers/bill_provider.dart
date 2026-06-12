import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/data/services/bill_service.dart';
import 'package:plansphere/data/models/bill_model.dart';

final billServiceProvider = Provider<BillService>((ref) => BillService());

final userBillsProvider = StreamProvider<List<BillModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.read(billServiceProvider).streamUserBills(user.uid);
});

final activeWarrantiesProvider = StreamProvider<List<BillModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.read(billServiceProvider).streamActiveWarranties(user.uid);
});

final expiringSoonWarrantiesProvider = StreamProvider<List<BillModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.read(billServiceProvider).streamExpiringSoonWarranties(user.uid);
});

final billsByCategory = StreamProviderFamily<List<BillModel>, String>((ref, category) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.read(billServiceProvider).streamBillsByCategory(user.uid, category);
});

final selectedBillProvider = FutureProviderFamily<BillModel?, String>((ref, billId) {
  return ref.read(billServiceProvider).getBill(billId);
});

// Bill Stats
final billStatsProvider = Provider((ref) {
  final bills = ref.watch(userBillsProvider).value ?? [];
  final activeWarranties = ref.watch(activeWarrantiesProvider).value ?? [];
  final expiringSoon = ref.watch(expiringSoonWarrantiesProvider).value ?? [];

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

// Bill CRUD Notifier
class BillCrudNotifier extends StateNotifier<AsyncValue<void>> {
  final BillService _service;
  final String _userId;

  BillCrudNotifier(this._service, this._userId)
      : super(const AsyncValue.data(null));

  Future<String?> addBill({
    required BillModel bill,
    File? imageFile,
    File? pdfFile,
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
    File? imageFile,
    File? pdfFile,
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
    state = const AsyncValue.loading();
    try {
      await _service.deleteBill(billId, _userId);
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
  final user = FirebaseAuth.instance.currentUser;
  return BillCrudNotifier(
    ref.read(billServiceProvider),
    user?.uid ?? '',
  );
});
