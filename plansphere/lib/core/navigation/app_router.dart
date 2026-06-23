import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansphere/presentation/screens/splash/splash_screen.dart';
import 'package:plansphere/presentation/screens/auth/login_screen.dart';
import 'package:plansphere/presentation/screens/auth/register_screen.dart';
import 'package:plansphere/presentation/screens/auth/forgot_password_screen.dart';
import 'package:plansphere/presentation/screens/home/home_screen.dart';
import 'package:plansphere/presentation/screens/home/main_shell.dart';
import 'package:plansphere/core/constants/app_colors.dart';

import 'package:plansphere/presentation/screens/bills/bills_screen.dart';
import 'package:plansphere/presentation/screens/bills/add_bill_screen.dart';
import 'package:plansphere/presentation/screens/bills/bill_detail_screen.dart';
import 'package:plansphere/presentation/screens/bills/shared_bill_view.dart';
import 'package:plansphere/presentation/screens/bills/edit_bill_screen.dart';
import 'package:plansphere/presentation/screens/scanner/bill_scanner_screen.dart';
import 'package:plansphere/presentation/screens/analytics/analytics_screen.dart';
import 'package:plansphere/presentation/screens/settings/settings_screen.dart';
import 'package:plansphere/presentation/screens/warranty/warranty_screen.dart';
import 'package:plansphere/presentation/screens/warranty/warranty_detail_screen.dart';
import 'package:plansphere/presentation/screens/documents/documents_screen.dart';
import 'package:plansphere/presentation/screens/search/search_screen.dart';
import 'package:plansphere/presentation/screens/notifications/notifications_screen.dart';
import 'package:plansphere/presentation/screens/profile/profile_screen.dart';
import 'package:plansphere/presentation/screens/family/family_screen.dart';
import 'package:plansphere/presentation/screens/family/family_detail_screen.dart';
import 'package:plansphere/presentation/screens/bills/amc_screen.dart';
import 'package:plansphere/presentation/screens/bills/service_history_screen.dart';
import 'package:plansphere/presentation/screens/bills/claim_assistant_screen.dart';
import 'package:plansphere/data/services/ocr_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in main.dart');
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (_) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable:
        GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),

    redirect: (context, state) {
      final location = state.uri.path;
      final user = FirebaseAuth.instance.currentUser;

      final isLoggedIn = user != null;
      final isSplash = location == '/splash';
      final isAuth = location.startsWith('/auth');
      final isSharedBill = location.startsWith('/shared-bill');

      debugPrint('ROUTER UID: ${user?.uid}');
      debugPrint('ROUTER EMAIL: ${user?.email}');

      if (isSplash || isSharedBill) return null;

      if (!isLoggedIn) {
        return isAuth ? null : '/auth/login';
      }

      if (isLoggedIn && isAuth) {
        return '/home';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/bills', builder: (context, state) => const BillsScreen()),
          GoRoute(path: '/warranty', builder: (context, state) => const WarrantyScreen()),
          GoRoute(path: '/documents', builder: (context, state) => const DocumentsScreen()),
          GoRoute(path: '/analytics', builder: (context, state) => const AnalyticsScreen()),
        ],
      ),

      GoRoute(
        path: '/bills/add',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is OcrResult) {
            return AddBillScreen(ocrResult: extra);
          }
          return const AddBillScreen();
        },
      ),
      GoRoute(path: '/scanner', builder: (context, state) => const BillScannerScreen()),
      GoRoute(path: '/amc', builder: (context, state) => const AmcScreen()),
      GoRoute(path: '/service-history', builder: (context, state) => const ServiceHistoryScreen()),
      GoRoute(path: '/claim-assistant', builder: (context, state) => const ClaimAssistantScreen()),
      GoRoute(
        path: '/bills/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initialTab = state.extra is int ? state.extra as int : null;
          return BillDetailScreen(billId: id, initialTab: initialTab);
        },
      ),
      GoRoute(
        path: '/shared-bill/:shareId',
        builder: (context, state) {
          final shareId = state.pathParameters['shareId']!;
          return SharedBillView(shareId: shareId);
        },
      ),
      GoRoute(
        path: '/bills/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EditBillScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/warranty/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return WarrantyDetailScreen(warrantyId: id);
        },
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/family', builder: (context, state) => const FamilyScreen()),
      GoRoute(
        path: '/family/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FamilyDetailScreen(groupId: id);
        },
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      );
    },
  );
});