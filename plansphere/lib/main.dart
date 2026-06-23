import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'presentation/providers/theme_provider.dart';
import 'core/navigation/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  };

  bool firebaseInitialized = false;
  String? initError;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    firebaseInitialized = true;

    debugPrint("Firebase ready. Apps count: ${Firebase.apps.length}");
    debugPrint("UID: ${FirebaseAuth.instance.currentUser?.uid}");
    debugPrint("EMAIL: ${FirebaseAuth.instance.currentUser?.email}");

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .collection('test')
            .doc('test')
            .set({
          'message': 'Firestore working',
          'time': DateTime.now().toString(),
        });
        debugPrint('✅ FIRESTORE TEST SUCCESS');
      } else {
        debugPrint('ℹ️ FIRESTORE TEST SKIPPED (No authenticated user at launch)');
      }
    } catch (e) {
      debugPrint('❌ FIRESTORE TEST FAILED: $e');
    }
  } on FirebaseException catch (e, st) {
    if (e.code == 'duplicate-app') {
      firebaseInitialized = true;
      debugPrint("Firebase already initialized. Continuing...");
      debugPrint("UID: ${FirebaseAuth.instance.currentUser?.uid}");
      debugPrint("EMAIL: ${FirebaseAuth.instance.currentUser?.email}");
    } else {
      debugPrint("Firebase initialization failed: $e\n$st");
      initError = e.toString();
    }
  } catch (e, st) {
    debugPrint("Firebase initialization failed: $e\n$st");
    initError = e.toString();
  }

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  SharedPreferences? prefs;

  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("SharedPreferences initialization failed: $e");
    initError ??= e.toString();
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: PlanSphereApp(
        initError: initError,
        firebaseInitialized: firebaseInitialized,
      ),
    ),
  );
}

class PlanSphereApp extends ConsumerWidget {
  final bool firebaseInitialized;
  final String? initError;

  const PlanSphereApp({
    super.key,
    required this.firebaseInitialized,
    this.initError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!firebaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                initError ?? "Firebase initialization failed",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      );
    }

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}