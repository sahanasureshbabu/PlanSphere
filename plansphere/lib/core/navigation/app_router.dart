import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plansphere/presentation/providers/auth_provider.dart';
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

final appRouterProvider = Provider<GoRouter>((ref) {
  // authState watch is not used here but kept for context if needed later
  // ignore: unused_local_variable
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true, // Enabled for debugging

    // ================= REDIRECT LOGIC =================
    redirect: (context, state) {
      final location = state.uri.path;

      final authState = ref.read(authStateProvider);
      final user = authState.value;
      final isLoggedIn = user != null;
      final isLoading = authState.isLoading;

      final isSplash = location == '/splash';
      final isAuth = location.startsWith('/auth');

      // 1. Always allow splash
      if (isSplash) return null;

      // 2. Wait until Firebase auth finishes loading
      if (isLoading) return null;

      // 3. If NOT logged in → allow only auth screens
      if (!isLoggedIn) {
        if (isAuth) return null;
        return '/auth/login';
      }

      // 4. If logged in → block auth pages and redirect to home if at login
      if (isLoggedIn && (isAuth || location == '/')) {
        return '/home';
      }

      return null;
    },

    // ================= ROUTES =================
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // AUTH
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

      // APP (MAIN SHELL TABS)
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/bills',
            builder: (context, state) => const BillsScreen(),
          ),
          GoRoute(
            path: '/warranty',
            builder: (context, state) => const WarrantyScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
        ],
      ),

      // APP SUB-PAGES
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
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const BillScannerScreen(),
      ),
      GoRoute(
        path: '/amc',
        builder: (context, state) => const AmcScreen(),
      ),
      GoRoute(
        path: '/service-history',
        builder: (context, state) => const ServiceHistoryScreen(),
      ),
      GoRoute(
        path: '/claim-assistant',
        builder: (context, state) => const ClaimAssistantScreen(),
      ),
      GoRoute(
        path: '/bills/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final initialTab = state.extra is int ? state.extra as int : null;
          return BillDetailScreen(billId: id, initialTab: initialTab);
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
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/family/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FamilyDetailScreen(groupId: id);
        },
      ),
    ],


    // ================= ERROR PAGE =================
    errorBuilder: (context, state) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0E1A), Color(0xFF1A1930), Color(0xFF242340)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 72,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Page Not Found',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The page "${state.uri.path}" could not be found.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Back to Dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
});