import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:plansphere/core/constants/app_colors.dart';
import 'package:plansphere/core/constants/app_constants.dart';
import 'package:plansphere/core/widgets/custom_text_field.dart';
import 'package:plansphere/core/widgets/gradient_button.dart';
import 'package:plansphere/core/widgets/app_snackbar.dart';
import 'package:plansphere/presentation/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (!mounted) return;

      final state = ref.read(authNotifierProvider);

      if (state.hasError) {
        AppSnackbar.showError(
          context,
          _getAuthErrorMessage(state.error),
        );
      } else {
        AppSnackbar.showSuccess(context, 'Login successful!');
      }
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,
        _getAuthErrorMessage(e),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      final state = ref.read(authNotifierProvider);

      if (state.hasError) {
        AppSnackbar.showError(
          context,
          _getAuthErrorMessage(state.error),
        );
      } else {
        AppSnackbar.showSuccess(context, 'Login successful!');
      }
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.showError(
        context,
        _getAuthErrorMessage(e),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getAuthErrorMessage(Object? error) {
    final e = error.toString().toLowerCase();

    debugPrint('LOGIN ERROR: $e');

    if (e.contains('user-not-found')) {
      return 'No account found with this email';
    }

    if (e.contains('wrong-password')) {
      return 'Wrong password';
    }

    if (e.contains('invalid-credential')) {
      return 'Invalid email or password';
    }

    if (e.contains('invalid-email')) {
      return 'Invalid email format';
    }

    if (e.contains('too-many-requests')) {
      return 'Too many attempts. Try again later';
    }

    if (e.contains('network-request-failed')) {
      return 'Check your internet connection';
    }

    if (e.contains('email-already-in-use')) {
      return 'This email is already registered';
    }

    if (e.contains('weak-password')) {
      return 'Password is too weak';
    }

    return 'Login failed: $e';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.darkBgGradient
              : const LinearGradient(
                  colors: [
                    Color(0xFFF5F7FF),
                    Color(0xFFEEEDFF),
                  ],
                ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.paddingL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  const Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.2),

                  const SizedBox(height: 40),

                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email required';
                      }

                      if (!v.contains('@')) {
                        return 'Enter valid email';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Password required';
                      }

                      if (v.trim().length < 6) {
                        return 'Minimum 6 characters required';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  GradientButton(
                    onPressed: _isLoading ? null : _signIn,
                    isLoading: _isLoading,
                    text: 'Sign In',
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => context.push('/auth/register'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}