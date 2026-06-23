import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/data/services/document_service.dart';
import 'package:plansphere/data/models/document_model.dart';

final documentServiceProvider =
    Provider<DocumentService>((ref) => DocumentService());

final firebaseUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userDocumentsProvider = StreamProvider<List<DocumentModel>>((ref) {
  final userAsync = ref.watch(firebaseUserProvider);

  final user = userAsync.value;
  if (user == null) {
    return Stream.value([]);
  }

  return ref.read(documentServiceProvider).streamUserDocuments(user.uid);
});

final documentsByCategoryProvider =
    StreamProviderFamily<List<DocumentModel>, String>((ref, category) {
  final userAsync = ref.watch(firebaseUserProvider);

  final user = userAsync.value;
  if (user == null) {
    return Stream.value([]);
  }

  return ref
      .read(documentServiceProvider)
      .streamDocumentsByCategory(user.uid, category);
});

final selectedDocumentProvider =
    FutureProviderFamily<DocumentModel?, String>((ref, docId) {
  final userAsync = ref.watch(firebaseUserProvider);
  final user = userAsync.value;

  if (user == null) {
    return Future.value(null);
  }

  return ref.read(documentServiceProvider).getDocument(docId);
});

class DocumentCrudNotifier extends StateNotifier<AsyncValue<void>> {
  final DocumentService _service;

  DocumentCrudNotifier(this._service) : super(const AsyncValue.data(null));

  Future<String?> uploadDocument({
    required DocumentModel document,
    required dynamic file,
  }) async {
    state = const AsyncValue.loading();

    try {
      final id = await _service.uploadDocument(
        document: document,
        file: file,
      );

      state = const AsyncValue.data(null);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deleteDocument(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    state = const AsyncValue.loading();

    try {
      await _service.deleteDocument(docId, user.uid);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final documentCrudProvider =
    StateNotifierProvider<DocumentCrudNotifier, AsyncValue<void>>((ref) {
  return DocumentCrudNotifier(
    ref.read(documentServiceProvider),
  );
});