import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_navigation.dart';
import 'app_theme.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RapidAidApp());
}

class RapidAidApp extends StatelessWidget {
  const RapidAidApp({super.key});

  // Builds the main RapidAid application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RapidAid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const RapidAidRoot(),
        '/login': (context) => LoginScreen(
              onLoginSuccess: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              onSignUp: () {
                Navigator.of(context).pushNamed('/signup');
              },
            ),
        '/signup': (context) => SignupScreen(
              onSignupSuccess: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              onLogin: () {
                Navigator.of(context).pushNamed('/login');
              },
            ),
        '/home': (context) => const AppNavigation(),
      },
    );
  }
}

class RapidAidRoot extends StatefulWidget {
  const RapidAidRoot({super.key});

  @override
  State<RapidAidRoot> createState() => _RapidAidRootState();
}

class _RapidAidRootState extends State<RapidAidRoot> {
  bool _showSplash = true;

  // Completes the splash screen.
  void _finishSplash() {
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });
  }

  // Builds the correct screen based on Firebase Authentication state.
  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinished: _finishSplash,
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: RapidAidColors.background,
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final User? user = snapshot.data;

        if (user != null) {
          return const AppNavigation();
        }

        return LoginScreen(
          onLoginSuccess: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/home',
              (route) => false,
            );
          },
          onSignUp: () {
            Navigator.of(context).pushNamed('/signup');
          },
        );
      },
    );
  }
}