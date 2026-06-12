import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:plansphere/data/services/auth_service.dart';
import 'package:plansphere/data/models/user_model.dart';

/// ================= AUTH SERVICE =================
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// ================= AUTH STATE STREAM =================
/// FIX: clean Firebase auth stream (this is correct)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// ================= CURRENT USER DATA =================
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);

  final user = authState.asData?.value;
  if (user == null) return null;

  return ref.read(authServiceProvider).getUserData(user.uid);
});

/// ================= OPTIONAL USER STREAM =================
/// FIX: simplified & removed broken nested stream
final currentUserStreamProvider = StreamProvider<UserModel?>((ref) async* {
  final auth = FirebaseAuth.instance;

  await for (final firebaseUser in auth.authStateChanges()) {
    if (firebaseUser == null) {
      yield null;
    } else {
      final userData =
          await ref.read(authServiceProvider).getUserData(firebaseUser.uid);
      yield userData;
    }
  }
});

/// ================= AUTH NOTIFIER =================
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithGoogle();
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.sendPasswordResetEmail(email);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }
}

/// ================= AUTH NOTIFIER PROVIDER =================
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});