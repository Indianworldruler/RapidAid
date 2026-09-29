import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const SplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _pulseController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(
        0.0,
        0.65,
        curve: Curves.easeIn,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: -0.12,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeOutBack,
      ),
    );

    _pulseAnimation = Tween<double>(
      begin: 0.94,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    _logoController.forward();
    _pulseController.repeat(reverse: true);

    await Future.delayed(
      const Duration(milliseconds: 2600),
    );

    if (!mounted) return;

    widget.onFinished();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -70,
              child: _backgroundCircle(
                size: 220,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _backgroundCircle(
                size: 260,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28,
              left: -45,
              child: _backgroundCircle(
                size: 110,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _logoController,
                  _pulseController,
                ]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value *
                            _pulseAnimation.value,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 24),
                    const Text(
                      'RapidAid',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help when every second matters',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 38,
              child: Column(
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Preparing your emergency centre...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: RapidAidColors.primary,
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          CustomPaint(
            size: const Size(56, 56),
            painter: _RapidAidLogoPainter(),
          ),
        ],
      ),
    );
  }

  Widget _backgroundCircle({
    required double size,
    required Color color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RapidAidLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = math.min(
      size.width,
      size.height,
    ) /
        2;

    final path = Path();

    path.moveTo(
      center.dx - radius * 0.18,
      center.dy - radius * 0.88,
    );

    path.lineTo(
      center.dx + radius * 0.14,
      center.dy - radius * 0.88,
    );

    path.lineTo(
      center.dx + radius * 0.05,
      center.dy - radius * 0.22,
    );

    path.lineTo(
      center.dx + radius * 0.48,
      center.dy - radius * 0.22,
    );

    path.lineTo(
      center.dx - radius * 0.16,
      center.dy + radius * 0.88,
    );

    path.lineTo(
      center.dx - radius * 0.04,
      center.dy + radius * 0.20,
    );

    path.lineTo(
      center.dx - radius * 0.48,
      center.dy + radius * 0.20,
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}