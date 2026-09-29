import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onSignupSuccess;
  final VoidCallback onLogin;

  const SignupScreen({
    super.key,
    required this.onSignupSuccess,
    required this.onLogin,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Creates a new Firebase Authentication account.
  Future<void> _signup() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      widget.onSignupSuccess();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showAuthError(error);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to create your account. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Shows a Firebase Authentication sign-up error.
  void _showAuthError(FirebaseAuthException error) {
    String message;

    switch (error.code) {
      case 'email-already-in-use':
        message =
            'An account already exists with this email.';
        break;

      case 'invalid-email':
        message =
            'Please enter a valid email address.';
        break;

      case 'weak-password':
        message =
            'Password is too weak. Use at least 6 characters.';
        break;

      case 'operation-not-allowed':
        message =
            'Email/password authentication is not enabled in Firebase.';
        break;

      case 'network-request-failed':
        message =
            'Network connection failed. Please check your internet connection.';
        break;

      case 'too-many-requests':
        message =
            'Too many attempts. Please try again later.';
        break;

      default:
        message =
            error.message ??
            'Unable to create your account. Please try again.';
    }

    _showMessage(message);
  }

  // Shows a sign-up status message.
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: RapidAidColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Builds the account creation screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _isLoading ? null : widget.onLogin,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildSignupForm(),
                    const SizedBox(height: 24),
                    _buildSignupButton(),
                    const SizedBox(height: 22),
                    _buildLoginPrompt(),
                    const SizedBox(height: 24),
                    _buildSecurityMessage(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            RapidAidColors.primary,
            RapidAidColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Get started with RapidAid',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Create your account to manage your emergency contacts and SOS alerts.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.email,
            ],
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'Enter your email',
              prefixIcon: Icon(
                Icons.email_outlined,
              ),
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (email.isEmpty) {
                return 'Please enter your email.';
              }

              final emailRegex = RegExp(
                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
              );

              if (!emailRegex.hasMatch(email)) {
                return 'Please enter a valid email address.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [
              AutofillHints.newPassword,
            ],
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a password',
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
              ),
              suffixIcon: IconButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please create a password.';
              }

              if (value.length < 6) {
                return 'Password must contain at least 6 characters.';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            enabled: !_isLoading,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [
              AutofillHints.newPassword,
            ],
            onFieldSubmitted: (_) => _signup(),
            decoration: InputDecoration(
              labelText: 'Confirm password',
              hintText: 'Enter your password again',
              prefixIcon: const Icon(
                Icons.lock_reset_rounded,
              ),
              suffixIcon: IconButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _obscureConfirmPassword =
                              !_obscureConfirmPassword;
                        });
                      },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password.';
              }

              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signup,
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_rounded),
                  SizedBox(width: 9),
                  Text('Create Account'),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account?',
          style: TextStyle(
            color: RapidAidColors.textSecondary,
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : widget.onLogin,
          child: const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildSecurityMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: RapidAidColors.info.withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: RapidAidColors.info,
            size: 23,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'RapidAid uses Firebase Authentication to securely manage your account.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: RapidAidColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}