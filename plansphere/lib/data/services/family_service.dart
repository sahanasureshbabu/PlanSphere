import 'package:cloud_firestore/cloud_firestore.dart';
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
    final inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
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
    return docRef.id;
  }

  Future<bool> joinFamilyGroup({
    required String inviteCode,
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhotoUrl,
  }) async {
    final snapshot = await _familyRef
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .get();

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
    return true;
  }

  Future<void> removeMember(
      String groupId, String memberId) async {
    final doc = await _familyRef.doc(groupId).get();
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
  }

  Stream<QuerySnapshot> streamUserFamilyGroups(String userId) {
    // Fixed Firestore querying bug: use flat UIDs array
    return _familyRef
        .where('memberIds', arrayContains: userId)
        .snapshots();
  }

  Future<DocumentSnapshot?> getFamilyGroup(String groupId) async {
    final doc = await _familyRef.doc(groupId).get();
    return doc.exists ? doc : null;
  }

  Future<void> sendFamilyNotification({
    required String groupId,
    required String fromUserId,
    required String title,
    required String body,
    required String type,
  }) async {
    final groupDoc = await _familyRef.doc(groupId).get();
    if (!groupDoc.exists) return;

    final data = groupDoc.data() as Map<String, dynamic>;
    final members = List<dynamic>.from(data['members'] ?? []);

    final batch = _firestore.batch();
    for (final member in members) {
      final memberId = member['userId'] as String;
      if (memberId == fromUserId) continue;

      final notifRef = _firestore
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
  }
}
