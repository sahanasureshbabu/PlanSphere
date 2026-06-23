import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plansphere/main.dart';
import 'package:plansphere/core/navigation/app_router.dart';
import 'package:plansphere/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  testWidgets('App test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
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