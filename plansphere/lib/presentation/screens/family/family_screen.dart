import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Sharing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(AppConstants.familyGroupsCollection)
            .where('members', arrayContains: {'userId': user?.uid})
            .snapshots(),
        builder: (context, snapshot) {
          // Check if user has a family group
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return _NoFamilyGroup(
              onCreateGroup: () => _showCreateGroupSheet(),
              onJoinGroup: () => _showJoinGroupSheet(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _FamilyGroupCard(
                groupId: docs[i].id,
                groupName: data['name'] ?? 'My Family',
                memberCount:
                    (data['members'] as List?)?.length ?? 0,
                inviteCode: data['inviteCode'] ?? '',
                isAdmin: data['adminId'] == user?.uid,
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Family Group',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'e.g. The Sharma Family',
                prefixIcon: Icon(Icons.group_rounded),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await _createFamilyGroup(nameCtrl.text.trim());
              },
              text: 'Create Group',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupSheet() {
    final codeCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Join Family Group',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Enter the invite code shared by your family member',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                hintText: 'e.g. ABC123',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: () async {
                if (codeCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await _joinFamilyGroup(
                    codeCtrl.text.trim().toUpperCase());
              },
              text: 'Join Group',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _createFamilyGroup(String name) async {
    if (user == null) return;
    final inviteCode =
        const Uuid().v4().substring(0, 6).toUpperCase();
    final groupData = {
      'name': name,
      'adminId': user!.uid,
      'members': [
        {
          'userId': user!.uid,
          'name': user!.displayName ?? 'Admin',
          'email': user!.email ?? '',
          'photoUrl': user!.photoURL,
          'role': 'admin',
          'joinedAt': Timestamp.fromDate(DateTime.now()),
        }
      ],
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    await FirebaseFirestore.instance
        .collection(AppConstants.familyGroupsCollection)
        .add(groupData);

    if (mounted) {
      AppSnackbar.showSuccess(
          context, 'Family group "$name" created! Invite code: $inviteCode');
    }
  }

  Future<void> _joinFamilyGroup(String inviteCode) async {
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection(AppConstants.familyGroupsCollection)
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (snapshot.docs.isEmpty) {
      if (mounted) {
        AppSnackbar.showError(
            context, 'Invalid invite code. Please check and try again.');
      }
      return;
    }

    final groupDoc = snapshot.docs.first;
    final newMember = {
      'userId': user!.uid,
      'name': user!.displayName ?? 'Member',
      'email': user!.email ?? '',
      'photoUrl': user!.photoURL,
      'role': 'member',
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    };

    await groupDoc.reference.update({
      'members': FieldValue.arrayUnion([newMember]),
    });

    if (mounted) {
      AppSnackbar.showSuccess(
          context, 'You have joined the family group!');
    }
  }
}

class _NoFamilyGroup extends StatelessWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  const _NoFamilyGroup(
      {required this.onCreateGroup, required this.onJoinGroup});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_rounded,
                size: 48, color: AppColors.primary),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Family Sharing',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            'Share bills, warranties and documents\nwith your family members securely.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onCreateGroup,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Family Group'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onJoinGroup,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Join with Invite Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ..._buildFeatures(context),
        ],
      ),
    );
  }

  List<Widget> _buildFeatures(BuildContext context) {
    final features = [
      (Icons.share_rounded, 'Share Bills', 'Share bills with family members'),
      (Icons.verified_rounded, 'Shared Warranties',
          'Track warranties together'),
      (Icons.folder_rounded, 'Document Vault',
          'Access shared documents anytime'),
      (Icons.admin_panel_settings_rounded, 'Role Management',
          'Admin & Member roles'),
    ];
    return features.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(f.$1, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(f.$3,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        )).toList();
  }
}

class _FamilyGroupCard extends StatelessWidget {
  final String groupId;
  final String groupName;
  final int memberCount;
  final String inviteCode;
  final bool isAdmin;

  const _FamilyGroupCard({
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.inviteCode,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/family/$groupId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Admin',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                    icon: Icons.people_rounded,
                    label: '$memberCount members'),
                const SizedBox(width: 8),
                _InfoChip(
                    icon: Icons.vpn_key_rounded,
                    label: inviteCode),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: inviteCode));
                AppSnackbar.showSuccess(
                    context, 'Invite code copied!');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.copy_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Copy Invite Code: $inviteCode',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
