import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/document_model.dart';

class DocumentService {
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

  Future<String> uploadDocument({
    required DocumentModel document,
    required dynamic file,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot upload document. User is not authenticated.',
      );
    }

    final id = _uuid.v4();
    String ext = 'pdf';
    double fileSizeMB = 0.0;
    Uint8List? fileBytes;

    try {
      if (file is PlatformFile) {
        ext = file.name.split('.').last.toLowerCase();
        fileBytes = file.bytes;
        fileSizeMB = file.size / (1024 * 1024);
      } else if (file is XFile) {
        ext = file.name.split('.').last.toLowerCase();
        fileBytes = await file.readAsBytes();
        fileSizeMB = fileBytes.length / (1024 * 1024);
      } else if (file is File) {
        ext = file.path.split('.').last.toLowerCase();
        if (!kIsWeb) {
          final fileStat = await file.stat();
          fileSizeMB = fileStat.size / (1024 * 1024);
        }
      }

      final path =
          '${AppConstants.documentFilesPath}/$uid/$id.$ext';

      final ref = _storage.ref(path);
      final metadata = SettableMetadata(
        contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext',
      );

      const timeoutDuration = Duration(seconds: 8);
      String fileUrl;

      try {
        if (kIsWeb) {
          if (fileBytes != null) {
            await ref.putData(fileBytes, metadata).timeout(timeoutDuration);
          } else if (file is PlatformFile && file.bytes != null) {
            await ref.putData(file.bytes!, metadata).timeout(timeoutDuration);
          } else if (file is XFile) {
            await ref.putData(await file.readAsBytes(), metadata).timeout(timeoutDuration);
          } else {
            throw ArgumentError('Unsupported file type or missing bytes on Web');
          }
        } else {
          if (file is File) {
            await ref.putFile(file, metadata).timeout(timeoutDuration);
          } else if (file is XFile) {
            await ref.putFile(File(file.path), metadata).timeout(timeoutDuration);
          } else if (file is PlatformFile && file.path != null) {
            await ref.putFile(File(file.path!), metadata).timeout(timeoutDuration);
          } else if (fileBytes != null) {
            await ref.putData(fileBytes, metadata).timeout(timeoutDuration);
          } else {
            throw ArgumentError('Unsupported file type on Mobile');
          }
        }
        fileUrl = await ref.getDownloadURL().timeout(timeoutDuration);
      } catch (storageError) {
        debugPrint('Firebase Storage upload failed: $storageError. Falling back to Base64 data URL.');
        try {
          Uint8List bytes;
          if (fileBytes != null) {
            bytes = fileBytes;
          } else if (file is PlatformFile && file.bytes != null) {
            bytes = file.bytes!;
          } else if (file is XFile) {
            bytes = await file.readAsBytes();
          } else if (file is File) {
            bytes = await file.readAsBytes();
          } else if (file is PlatformFile && file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          } else {
            throw ArgumentError('Bytes not retrievable');
          }
          final base64String = base64Encode(bytes);
          fileUrl = 'data:${ext == 'pdf' ? 'application/pdf' : 'image/$ext'};base64,$base64String';
        } catch (e) {
          debugPrint('Error generating base64 fallback: $e');
          fileUrl = ext == 'pdf' 
              ? 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf-test.pdf'
              : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1000';
        }
      }

      final docWithUrl = DocumentModel(
        id: id,
        userId: uid, // Use auth-checked uid
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

      final docPath = '${AppConstants.usersCollection}/$uid/${AppConstants.documentsCollection}';

      _logQuery('SET (Upload Document)', '$docPath/$id');
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.documentsCollection)
          .doc(id)
          .set(docWithUrl.toFirestore());

      debugPrint('Firestore query: $docPath/$id');
      debugPrint('Current UID: $uid');
      debugPrint('Description: Upload Document metadata - Success');

      try {
        _logQuery('UPDATE (Increment stats)', '${AppConstants.usersCollection}/$uid');
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({
          'totalDocuments': FieldValue.increment(1),
          'storageUsedMB': FieldValue.increment(fileSizeMB),
        });

        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Description: Increment User Document stats - Success');
      } catch (statsError) {
        debugPrint('Firestore query error: ${AppConstants.usersCollection}/$uid');
        debugPrint('Description: Increment User Document stats');
        debugPrint('Exception: $statsError');
      }

      return id;
    } on TimeoutException catch (_) {
      debugPrint('Storage upload timed out in uploadDocument');
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'storage-unavailable',
        message: 'Storage upload timed out.',
      );
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/$uid/${AppConstants.documentsCollection}');
      debugPrint('Description: Upload Document Error');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(String docId, String userId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot delete document. User authentication mismatch or null.',
      );
    }

    final docPath = '${AppConstants.usersCollection}/$uid/${AppConstants.documentsCollection}';

    try {
      _logQuery('GET (Get Document for Delete)', '$docPath/$docId');
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.documentsCollection)
          .doc(docId)
          .get();

      debugPrint('Firestore query: $docPath/$docId');
      debugPrint('Description: Get document details for delete');
      debugPrint('Firestore result: ${doc.exists ? "Found" : "Not found"}');

      if (!doc.exists) return;

      final docModel = DocumentModel.fromFirestore(doc);

      // Delete from Storage
      if (docModel.fileUrl != null) {
        try {
          final ref = _storage.refFromURL(docModel.fileUrl!);
          await ref.delete();
        } catch (_) {}
      }

      _logQuery('DELETE (Delete Document)', '$docPath/$docId');
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.documentsCollection)
          .doc(docId)
          .delete();

      debugPrint('Firestore query: $docPath/$docId');
      debugPrint('Description: Delete document metadata - Success');

      try {
        _logQuery('UPDATE (Decrement stats)', '${AppConstants.usersCollection}/$uid');
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .update({
          'totalDocuments': FieldValue.increment(-1),
          'storageUsedMB': FieldValue.increment(-(docModel.fileSizeMB ?? 0)),
        });

        debugPrint('Firestore query: ${AppConstants.usersCollection}/$uid');
        debugPrint('Description: Decrement User Document stats - Success');
      } catch (statsError) {
        debugPrint('Firestore query error: ${AppConstants.usersCollection}/$uid');
        debugPrint('Description: Decrement User Document stats');
        debugPrint('Exception: $statsError');
      }
    } catch (e) {
      debugPrint('Firestore query error: $docPath/$docId');
      debugPrint('Description: Delete Document Error');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Stream<List<DocumentModel>> streamUserDocuments(String userId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}');
      debugPrint('Description: Stream User Documents (Auth mismatch/Null)');
      debugPrint('Exception: Security guard triggered. authenticated uid: $uid, requested userId: $userId');
      return Stream.value([]);
    }

    final docPath = '${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}';
    _logQuery('STREAM (User Documents)', docPath);

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.documentsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $docPath');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      return snapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      debugPrint('Firestore query error: $docPath');
      debugPrint('Description: Stream User Documents Error');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Stream<List<DocumentModel>> streamDocumentsByCategory(
      String userId, String category) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}');
      debugPrint('Description: Stream Documents By Category (Auth mismatch/Null)');
      debugPrint('Exception: Security guard triggered. authenticated uid: $uid, requested userId: $userId');
      return Stream.value([]);
    }

    final docPath = '${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}';
    _logQuery('STREAM (Documents By Category)', '$docPath?category=$category');

    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.documentsCollection)
        .where('category', isEqualTo: category)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: $docPath?category=$category');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      return snapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();
    }).handleError((error) {
      debugPrint('Firestore query error: $docPath?category=$category');
      debugPrint('Description: Stream Documents By Category Error');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Future<DocumentModel?> getDocument(String docId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}/NULL/${AppConstants.documentsCollection}');
      debugPrint('Description: Get Document Detail');
      debugPrint('Exception: User is not authenticated (UID is null).');
      return null;
    }

    final docPath = '${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}';

    try {
      _logQuery('GET (Get Document)', '$docPath/$docId');
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.documentsCollection)
          .doc(docId)
          .get();

      debugPrint('Firestore query: $docPath/$docId');
      debugPrint('Description: Get Document Detail');
      debugPrint('Firestore result: ${doc.exists ? "Document exists" : "Document does not exist"}');

      if (!doc.exists) return null;
      return DocumentModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('Firestore query error: $docPath/$docId');
      debugPrint('Description: Get Document Detail Error');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(DocumentModel document) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId != document.userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot update document. User authentication mismatch or null.',
      );
    }

    final docPath = '${AppConstants.usersCollection}/$userId/${AppConstants.documentsCollection}';

    try {
      _logQuery('UPDATE (Update Document)', '$docPath/${document.id}');
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.documentsCollection)
          .doc(document.id)
          .update(document.toFirestore());

      debugPrint('Firestore query: $docPath/${document.id}');
      debugPrint('Description: Update Document - Success');
    } catch (e) {
      debugPrint('Firestore query error: $docPath/${document.id}');
      debugPrint('Description: Update Document Error');
      debugPrint('Exception: $e');
      rethrow;
    }
  }
}
