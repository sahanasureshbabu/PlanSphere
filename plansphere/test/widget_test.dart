import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plansphere/main.dart';
import 'package:plansphere/core/navigation/app_router.dart';
import 'package:plansphere/presentation/providers/auth_provider.dart';
import 'package:plansphere/presentation/screens/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  testWidgets('App test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final mockRouter = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/auth/login',
          builder: (context, state) => const Scaffold(body: Text('Login')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          appRouterProvider.overrideWithValue(mockRouter),
        ],
        child: const PlanSphereApp(firebaseInitialized: true),
      ),
    );

    // Clean up the widget tree to unmount splash screen
    await tester.pumpWidget(const SizedBox());
    // Resolve the splash screen's delayed navigation timer while unmounted
    await tester.pump(const Duration(seconds: 3));
  });
}