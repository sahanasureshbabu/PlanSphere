import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  CollectionReference get _docsRef =>
      _firestore.collection(AppConstants.documentsCollection);

  Future<String> uploadDocument({
    required DocumentModel document,
    required File file,
  }) async {
    final id = _uuid.v4();
    final ext = file.path.split('.').last;
    final path =
        '${AppConstants.documentFilesPath}/${document.userId}/$id.$ext';

    final ref = _storage.ref(path);
    final metadata = SettableMetadata(
      contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
    );
    await ref.putFile(file, metadata);
    final fileUrl = await ref.getDownloadURL();

    final fileStat = await file.stat();
    final fileSizeMB = fileStat.size / (1024 * 1024);

    final docWithUrl = DocumentModel(
      id: id,
      userId: document.userId,
      title: document.title,
      category: document.category,
      description: document.description,
      tags: document.tags,
      fileUrl: fileUrl,
      fileType: ext,
      fileSizeMB: fileSizeMB,
      expiryDate: document.expiryDate,
      hasReminder: document.hasReminder,
      familyGroupId: document.familyGroupId,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    );

    await _docsRef.doc(id).set(docWithUrl.toFirestore());

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(document.userId)
        .update({
      'totalDocuments': FieldValue.increment(1),
      'storageUsedMB': FieldValue.increment(fileSizeMB),
    });

    return id;
  }

  Future<void> deleteDocument(String docId, String userId) async {
    final doc = await _docsRef.doc(docId).get();
    if (!doc.exists) return;

    final docModel = DocumentModel.fromFirestore(doc);

    // Delete from Storage
    if (docModel.fileUrl != null) {
      try {
        final ref = _storage.refFromURL(docModel.fileUrl!);
        await ref.delete();
      } catch (_) {}
    }

    await _docsRef.doc(docId).delete();

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'totalDocuments': FieldValue.increment(-1),
      'storageUsedMB': FieldValue.increment(-(docModel.fileSizeMB ?? 0)),
    });
  }

  Stream<List<DocumentModel>> streamUserDocuments(String userId) {
    return _docsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DocumentModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<DocumentModel>> streamDocumentsByCategory(
      String userId, String category) {
    return _docsRef
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DocumentModel.fromFirestore(doc))
            .toList());
  }

  Future<DocumentModel?> getDocument(String docId) async {
    final doc = await _docsRef.doc(docId).get();
    if (!doc.exists) return null;
    return DocumentModel.fromFirestore(doc);
  }

  Future<void> updateDocument(DocumentModel document) async {
    await _docsRef.doc(document.id).update(document.toFirestore());
  }
}
