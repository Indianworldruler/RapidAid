import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onSignUp;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onSignUp,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Signs the user in using Firebase Authentication.
  Future<void> _login() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.instance.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      widget.onLoginSuccess();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _showAuthError(error);
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to sign in. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Shows a Firebase Authentication error message.
  void _showAuthError(FirebaseAuthException error) {
    String message;

    switch (error.code) {
      case 'invalid-credential':
        message = 'Incorrect email or password.';
        break;

      case 'user-not-found':
        message = 'No account was found with this email.';
        break;

      case 'wrong-password':
        message = 'Incorrect password.';
        break;

      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;

      case 'user-disabled':
        message = 'This account has been disabled.';
        break;

      case 'too-many-requests':
        message =
            'Too many login attempts. Please try again later.';
        break;

      case 'network-request-failed':
        message =
            'Network connection failed. Please check your internet connection.';
        break;

      case 'operation-not-allowed':
        message =
            'Email/password authentication is not enabled in Firebase.';
        break;

      default:
        message =
            error.message ?? 'Unable to sign in. Please try again.';
    }

    _showMessage(message);
  }

  // Shows a login status message.
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
    super.dispose();
  }

  // Builds the login screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                24,
                24,
                24,
                28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBrandHeader(),
                    const SizedBox(height: 36),
                    _buildWelcomeText(),
                    const SizedBox(height: 28),
                    _buildLoginForm(),
                    const SizedBox(height: 24),
                    _buildLoginButton(),
                    const SizedBox(height: 26),
                    _buildDivider(),
                    const SizedBox(height: 22),
                    _buildSignUpPrompt(),
                    const SizedBox(height: 28),
                    _buildSafetyMessage(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: RapidAidColors.primary,
            borderRadius: BorderRadius.circular(17),
            boxShadow: [
              BoxShadow(
                color: RapidAidColors.primary.withValues(
                  alpha: 0.22,
                ),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.bolt_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RapidAid',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: RapidAidColors.textPrimary,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Emergency assistance',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: RapidAidColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: RapidAidColors.textPrimary,
          ),
        ),
        SizedBox(height: 9),
        Text(
          'Sign in to access your emergency contacts and send an SOS alert when you need help.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: RapidAidColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
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
              prefixIcon: Icon(Icons.email_outlined),
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
            textInputAction: TextInputAction.done,
            autofillHints: const [
              AutofillHints.password,
            ],
            onFieldSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
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
                return 'Please enter your password.';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
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
                  Icon(Icons.login_rounded),
                  SizedBox(width: 9),
                  Text('Sign In'),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
          ),
          child: Text(
            'NEW TO RAPIDAID?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: RapidAidColors.textLight,
            ),
          ),
        ),
        const Expanded(
          child: Divider(),
        ),
      ],
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Don\'t have an account?',
          style: TextStyle(
            fontSize: 14,
            color: RapidAidColors.textSecondary,
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : widget.onSignUp,
          child: const Text('Create Account'),
        ),
      ],
    );
  }

  Widget _buildSafetyMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RapidAidColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: RapidAidColors.primary.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            color: RapidAidColors.primary,
            size: 23,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your account is protected using Firebase Authentication.',
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