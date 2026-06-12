import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/data/services/document_service.dart';
import 'package:plansphere/data/models/document_model.dart';

final documentServiceProvider =
    Provider<DocumentService>((ref) => DocumentService());

final userDocumentsProvider = StreamProvider<List<DocumentModel>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref.read(documentServiceProvider).streamUserDocuments(user.uid);
});

final documentsByCategoryProvider =
    StreamProviderFamily<List<DocumentModel>, String>((ref, category) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream.empty();
  return ref
      .read(documentServiceProvider)
      .streamDocumentsByCategory(user.uid, category);
});

final selectedDocumentProvider =
    FutureProviderFamily<DocumentModel?, String>((ref, docId) {
  return ref.read(documentServiceProvider).getDocument(docId);
});

class DocumentCrudNotifier extends StateNotifier<AsyncValue<void>> {
  final DocumentService _service;
  final String _userId;

  DocumentCrudNotifier(this._service, this._userId)
      : super(const AsyncValue.data(null));

  Future<String?> uploadDocument({
    required DocumentModel document,
    required File file,
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
    state = const AsyncValue.loading();
    try {
      await _service.deleteDocument(docId, _userId);
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
  final user = FirebaseAuth.instance.currentUser;
  return DocumentCrudNotifier(
    ref.read(documentServiceProvider),
    user?.uid ?? '',
  );
});
