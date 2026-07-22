import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/theme_provider.dart';
import 'package:plansphere/presentation/providers/auth_provider.dart';
import 'package:plansphere/data/services/backup_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final BackupService _backupService = BackupService();

  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  bool _warrantyReminders = true;
  bool _documentReminders = true;
  bool _backupReminders = true;
  bool _autoBackup = true;
  bool _isBiometricAvailable = false;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkBiometric();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _biometricEnabled = data['biometricEnabled'] ?? false;
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings from Firestore: $e');
    }
  }

  Future<void> _checkBiometric() async {
    final available = await _localAuth.canCheckBiometrics;
    setState(() => _isBiometricAvailable = available);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final authenticated = await _localAuth.authenticate(
  localizedReason: 'Authenticate to enable biometric lock',
  biometricOnly: true,
);
      if (!authenticated) return;
    }
    setState(() => _biometricEnabled = value);
    await _saveUserSetting('biometricEnabled', value);
  }

  Future<void> _saveUserSetting(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .update({key: value});
    } catch (e) {
      debugPrint('Error saving user setting to Firestore: $e');
    }
  }

  Future<void> _triggerManualBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isBackingUp = true);
    final url = await _backupService.createBackup(user.uid);
    setState(() => _isBackingUp = false);

    if (mounted) {
      if (url != null) {
        AppSnackbar.showSuccess(context, 'Cloud Backup created successfully!');
      } else {
        AppSnackbar.showError(context, 'Backup failed. Please check internet connection.');
      }
    }
  }

  Future<void> _showRestoreDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _backupService.listBackups(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('No backups found', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Create a backup first from Settings.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              );
            }

            final backups = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Backup to Restore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: backups.length,
                      itemBuilder: (context, index) {
                        final item = backups[index];
                        final date = item['updated'] as DateTime;
                        final sizeKB = (item['size'] ?? 0) / 1024;
                        return ListTile(
                          leading: const Icon(Icons.cloud_download_rounded, color: AppColors.primary),
                          title: Text('Backup: ${DateFormat('dd MMM yyyy, hh:mm a').format(date)}'),
                          subtitle: Text('Size: ${sizeKB.toStringAsFixed(1)} KB'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            _showLoadingOverlay();
                            final success = await _backupService.restoreBackup(user.uid, item['path']);
                            if (mounted) {
                              Navigator.pop(context); // Dismiss loading overlay
                              if (success) {
                                AppSnackbar.showSuccess(context, 'Data restored successfully!');
                              } else {
                                AppSnackbar.showError(context, 'Failed to restore backup.');
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Restoring your Vault...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            children: [
          // Appearance
          const _SectionHeader(title: 'Appearance'),
          _SettingsTile(
            icon: Icons.brightness_6_rounded,
            title: 'Theme',
            subtitle: _themeModeLabel(themeMode),
            onTap: () => _showThemeSheet(themeMode),
          ),

          // Security
          const _SectionHeader(title: 'Security'),
          _SwitchTile(
            icon: Icons.fingerprint_rounded,
            title: 'Biometric Authentication',
            subtitle: 'Lock app with fingerprint or face',
            value: _biometricEnabled,
            enabled: _isBiometricAvailable,
            onChanged: _toggleBiometric,
          ),
          _SettingsTile(
            icon: Icons.lock_reset_rounded,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: _showChangePasswordDialog,
          ),

          // Notifications
          const _SectionHeader(title: 'Notifications'),
          _SwitchTile(
            icon: Icons.notifications_rounded,
            title: 'Enable Notifications',
            subtitle: 'Receive all app notifications',
            value: _notificationsEnabled,
            onChanged: (v) {
              setState(() => _notificationsEnabled = v);
              _saveUserSetting('notificationsEnabled', v);
            },
          ),
          _SwitchTile(
            icon: Icons.verified_rounded,
            title: 'Warranty Reminders',
            subtitle: 'Get reminded before warranty expires',
            value: _warrantyReminders,
            enabled: _notificationsEnabled,
            onChanged: (v) => setState(() => _warrantyReminders = v),
          ),
          _SwitchTile(
            icon: Icons.folder_rounded,
            title: 'Document Reminders',
            subtitle: 'Get reminded before documents expire',
            value: _documentReminders,
            enabled: _notificationsEnabled,
            onChanged: (v) => setState(() => _documentReminders = v),
          ),
          _SwitchTile(
            icon: Icons.cloud_upload_rounded,
            title: 'Backup Reminders',
            subtitle: 'Get reminded to backup your data',
            value: _backupReminders,
            enabled: _notificationsEnabled,
            onChanged: (v) => setState(() => _backupReminders = v),
          ),

          // Backup
          const _SectionHeader(title: 'Backup & Data'),
          _SwitchTile(
            icon: Icons.cloud_sync_rounded,
            title: 'Auto Backup',
            subtitle: 'Automatically backup to cloud daily',
            value: _autoBackup,
            onChanged: (v) => setState(() => _autoBackup = v),
          ),
          _SettingsTile(
            icon: Icons.backup_rounded,
            title: _isBackingUp ? 'Backing Up...' : 'Backup Data Now',
            subtitle: 'Export bills & documents JSON to Firebase Storage',
            onTap: _isBackingUp ? () {} : _triggerManualBackup,
          ),
          _SettingsTile(
            icon: Icons.cloud_download_rounded,
            title: 'Restore Data',
            subtitle: 'Browse and restore from cloud backups',
            onTap: _showRestoreDialog,
          ),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: 'Clear Cache',
            subtitle: 'Clear temporary files',
            onTap: () => AppSnackbar.showSuccess(context, 'Cache cleared'),
            color: AppColors.warning,
          ),

          // Platform Administrator Route
          const _SectionHeader(title: 'Administrative Control'),
          _SettingsTile(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Web Admin Panel',
            subtitle: 'Platform user activity statistics',
            onTap: () => context.push('/admin'),
            color: const Color(0xFF8E44AD),
          ),

          // Privacy
          const _SectionHeader(title: 'Privacy'),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            subtitle: 'Read our terms of service',
            onTap: () {},
          ),

          // Danger Zone
          const _SectionHeader(title: 'Danger Zone'),
          _SettingsTile(
            icon: Icons.delete_rounded,
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            onTap: () => _showDeleteAccountDialog(),
            color: AppColors.error,
          ),

          const SizedBox(height: 40),
        ],
      ),
        ),
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
    }
  }

  void _showThemeSheet(ThemeMode current) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Theme',
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...[
              (ThemeMode.system, 'System Default',
                  Icons.settings_brightness_rounded),
              (ThemeMode.light, 'Light', Icons.light_mode_rounded),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
            ].map((item) => ListTile(
                  leading: Icon(item.$3),
                  title: Text(item.$2),
                  trailing: current == item.$1
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(themeModeProvider.notifier)
                        .setTheme(item.$1);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 28),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter a new password for your PlanSphere account. Make sure it is at least 6 characters.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => loading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await user.updatePassword(passwordController.text.trim());
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppSnackbar.showSuccess(context, 'Password updated successfully!');
                          }
                        } else {
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            AppSnackbar.showError(context, 'No user logged in.');
                          }
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => loading = false);
                        if (e.code == 'requires-recent-login') {
                          Navigator.pop(ctx);
                          _showReauthOrResetDialog();
                        } else {
                          AppSnackbar.showError(context, e.message ?? 'An error occurred.');
                        }
                      } catch (e) {
                        setDialogState(() => loading = false);
                        AppSnackbar.showError(context, 'An unexpected error occurred.');
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReauthOrResetDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.security_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Security Verification'),
          ],
        ),
        content: Text(
          'For security reasons, changing your password directly requires a recent login. '
          'We can send a secure reset link to your email ($email) instead, or you can log out and log back in to retry.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (email.isNotEmpty) {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (context.mounted) {
                    AppSnackbar.showSuccess(context, 'Password reset link sent to $email!');
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.showError(context, 'Failed to send password reset email.');
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and ALL your data. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authServiceProvider).deleteAccount();
              if (mounted) context.go('/auth/login');
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color:
              (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Function(bool) onChanged;
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(enabled ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: AppColors.primary.withOpacity(enabled ? 1 : 0.3),
            size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              color: enabled ? null : Colors.grey[400])),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      trailing: Switch(
        value: value && enabled,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppColors.primary,
      ),
    );
  }
}
