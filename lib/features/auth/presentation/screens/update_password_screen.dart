import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/timora_branding.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _success = false;
  String? _localValidationError;

  void _updatePassword() async {
    FocusScope.of(context).unfocus();

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() => _localValidationError = 'Please enter a new password.');
      return;
    }
    if (password.length < 6) {
      setState(() => _localValidationError = 'Password must be at least 6 characters.');
      return;
    }
    if (confirmPassword.isEmpty) {
      setState(() => _localValidationError = 'Please confirm your new password.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _localValidationError = 'Passwords do not match.');
      return;
    }

    setState(() => _localValidationError = null);

    final success = await ref.read(authControllerProvider.notifier).updatePassword(password);
    if (success && mounted) {
      setState(() {
        _success = true;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final displayedError = _localValidationError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TimoraBranding(showTagline: false),
              const SizedBox(height: 32),
              Text(
                'Set New Password',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter and confirm your new secure password.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              if (_success) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your password has been reset successfully! You can now sign in with your new credentials.',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Sign In with New Password',
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                ),
              ] else ...[
                if (displayedError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayedError,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  label: 'New Password',
                  hint: 'Enter new password (min 6 chars)',
                  controller: _passwordController,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  onChanged: (_) {
                    if (_localValidationError != null) {
                      setState(() => _localValidationError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Confirm New Password',
                  hint: 'Re-enter your new password',
                  controller: _confirmPasswordController,
                  isPassword: true,
                  obscureText: _obscureConfirmPassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  onChanged: (_) {
                    if (_localValidationError != null) {
                      setState(() => _localValidationError = null);
                    }
                  },
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  text: 'Update Password',
                  isLoading: authState.isLoading,
                  onPressed: authState.isLoading ? null : _updatePassword,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
