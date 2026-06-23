import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:plansphere/core/constants/app_constants.dart';
class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference get _familyRef =>
      _firestore.collection(AppConstants.familyGroupsCollection);

  Future<String> createFamilyGroup({
    required String adminId,
    required String adminName,
    required String adminEmail,
    String? adminPhotoUrl,
    required String groupName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != adminId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot create family group. User authentication mismatch or null.',
      );
    }

    final inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    try {
      final docRef = await _familyRef.add({
        'name': groupName,
        'adminId': adminId,
        'inviteCode': inviteCode,
        'memberIds': [adminId], // Flat UIDs array for querying
        'members': [
          {
            'userId': adminId,
            'name': adminName,
            'email': adminEmail,
            'photoUrl': adminPhotoUrl,
            'role': 'admin',
            'joinedAt': Timestamp.fromDate(DateTime.now()),
          }
        ],
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/${docRef.id}');
      debugPrint('Current UID: $adminId');
      debugPrint('Firestore result: Success');
      return docRef.id;
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}');
      debugPrint('Current UID: $adminId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<bool> joinFamilyGroup({
    required String inviteCode,
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhotoUrl,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot join family group. User authentication mismatch or null.',
      );
    }

    try {
      final snapshot = await _familyRef
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .get();

      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}?inviteCode=$inviteCode');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');

      if (snapshot.docs.isEmpty) return false;

      final doc = snapshot.docs.first;
      await doc.reference.update({
        'memberIds': FieldValue.arrayUnion([userId]), // Update flat UIDs list
        'members': FieldValue.arrayUnion([
          {
            'userId': userId,
            'name': userName,
            'email': userEmail,
            'photoUrl': userPhotoUrl,
            'role': 'member',
            'joinedAt': Timestamp.fromDate(DateTime.now()),
          }
        ]),
      });

      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/${doc.id}');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result: Success');
      return true;
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<void> removeMember(
      String groupId, String memberId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot remove member. User is not authenticated.',
      );
    }

    try {
      final doc = await _familyRef.doc(groupId).get();
      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Firestore result: ${doc.exists ? "Exists" : "Does not exist"}');
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      
      final members = List<dynamic>.from(data['members'] ?? []);
      members.removeWhere((m) => m['userId'] == memberId);
      
      final memberIds = List<dynamic>.from(data['memberIds'] ?? []);
      memberIds.remove(memberId);

      await doc.reference.update({
        'members': members,
        'memberIds': memberIds,
      });

      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Firestore result: Success');
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> streamUserFamilyGroups(String userId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != userId) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}');
      debugPrint('Current UID: $uid');
      debugPrint('Exception: Security guard triggered. authenticated uid: $uid, requested userId: $userId');
      return Stream.error(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Not authorized to stream family groups for this user.',
        ),
      );
    }

    return _familyRef
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}');
      debugPrint('Current UID: $userId');
      debugPrint('Firestore result count: ${snapshot.docs.length}');
      return snapshot;
    }).handleError((error) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}');
      debugPrint('Current UID: $userId');
      debugPrint('Exception: $error');
      throw error;
    });
  }

  Future<DocumentSnapshot?> getFamilyGroup(String groupId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: null');
      debugPrint('Exception: User is not authenticated.');
      return null;
    }

    try {
      final doc = await _familyRef.doc(groupId).get();
      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Firestore result: ${doc.exists ? "Exists" : "Does not exist"}');
      return doc.exists ? doc : null;
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Exception: $e');
      rethrow;
    }
  }

  Future<void> sendFamilyNotification({
    required String groupId,
    required String fromUserId,
    required String title,
    required String body,
    required String type,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Cannot send notification. User is not authenticated.',
      );
    }

    try {
      final groupDoc = await _familyRef.doc(groupId).get();
      debugPrint('Firestore query: ${AppConstants.familyGroupsCollection}/$groupId');
      debugPrint('Current UID: $uid');
      debugPrint('Firestore result: ${groupDoc.exists ? "Exists" : "Does not exist"}');
      if (!groupDoc.exists) return;

      final data = groupDoc.data() as Map<String, dynamic>;
      final members = List<dynamic>.from(data['members'] ?? []);

      final batch = _firestore.batch();
      for (final member in members) {
        final memberId = member['userId'] as String;
        if (memberId == fromUserId) continue;

        final notifRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(memberId)
            .collection(AppConstants.notificationsCollection)
            .doc();
        batch.set(notifRef, {
          'userId': memberId,
          'title': title,
          'body': body,
          'type': type,
          'relatedId': groupId,
          'isRead': false,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }
      await batch.commit();

      debugPrint('Firestore query: ${AppConstants.usersCollection}');
      debugPrint('Current UID: $uid');
      debugPrint('Firestore result: Success');
    } catch (e) {
      debugPrint('Firestore query error: ${AppConstants.usersCollection}');
      debugPrint('Current UID: $uid');
      debugPrint('Exception: $e');
      rethrow;
    }
  }
}
