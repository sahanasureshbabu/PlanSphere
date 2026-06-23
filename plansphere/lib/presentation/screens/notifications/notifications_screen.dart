import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/data/models/notification_model.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(user?.uid),
            child: const Text('Mark All Read'),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: user == null
              ? const Center(child: Text('Not logged in'))
              : StreamBuilder<QuerySnapshot>(
                  stream: _getNotificationsStream(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _EmptyNotifications();
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return _EmptyNotifications();
                    }

                    final notifications = snapshot.data!.docs
                        .map((doc) =>
                            NotificationModel.fromFirestore(doc))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: notifications.length,
                      itemBuilder: (ctx, i) => _NotificationItem(
                        notification: notifications[i],
                      ).animate().fadeIn(delay: (i * 50).ms),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getNotificationsStream(String uid) {
    final path = '${AppConstants.usersCollection}/$uid/${AppConstants.notificationsCollection}';
    debugPrint('[Firestore Query] Action: STREAM (Notifications)');
    debugPrint('[Firestore Query] Path: $path');
    debugPrint('[Firestore Query] Current UID: $uid');
    
    return FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.notificationsCollection)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> _markAllRead(String? userId) async {
    if (userId == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final path = '${AppConstants.usersCollection}/$userId/${AppConstants.notificationsCollection}';
      debugPrint('[Firestore Query] Action: GET (Mark All Read)');
      debugPrint('[Firestore Query] Path: $path');
      debugPrint('[Firestore Query] Current UID: $userId');

      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.notificationsCollection)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking notifications read: $e');
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context) {
    final iconData = _getIcon(notification.type);
    final color = _getColor(notification.type);

    return GestureDetector(
      onTap: () => _markRead(notification),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).cardColor
              : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: notification.isRead
              ? null
              : Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeago.format(notification.createdAt),
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'warranty':
        return Icons.verified_rounded;
      case 'document':
        return Icons.folder_rounded;
      case 'backup':
        return Icons.cloud_upload_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'warranty':
        return AppColors.warning;
      case 'document':
        return AppColors.info;
      case 'backup':
        return AppColors.secondary;
      default:
        return AppColors.primary;
    }
  }

  Future<void> _markRead(NotificationModel notification) async {
    if (!notification.isRead) {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.notificationsCollection)
          .doc(notification.id)
          .update({'isRead': true});
    }
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No notifications',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'You\'ll be notified about warranty\nexpirations and important updates',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
