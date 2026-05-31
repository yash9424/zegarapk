import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bg =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..forward();

  late final AnimationController _logo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  late final AnimationController _text =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  late final Animation<double> _bgScale =
      CurvedAnimation(parent: _bg, curve: Curves.easeOut);

  late final Animation<double> _logoScale = Tween(begin: 0.0, end: 1.0)
      .animate(CurvedAnimation(parent: _logo, curve: Curves.elasticOut));

  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _logo, curve: const Interval(0.0, 0.5));

  late final Animation<double> _textFade =
      CurvedAnimation(parent: _text, curve: Curves.easeIn);

  late final Animation<Offset> _textSlide = Tween(
          begin: const Offset(0, 0.5), end: Offset.zero)
      .animate(CurvedAnimation(parent: _text, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _bg.addStatusListener((s) {
      if (s == AnimationStatus.completed) _logo.forward();
    });
    _logo.addStatusListener((s) {
      if (s == AnimationStatus.completed) _text.forward();
    });
    _text.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 900), _goToLogin);
      }
    });
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, anim1, anim2) => const LoginScreen(),
        transitionsBuilder: (context, anim, secAnim, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bg.dispose();
    _logo.dispose();
    _ring.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated gradient background that scales in.
          AnimatedBuilder(
            animation: _bgScale,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.6 + 0.8 * _bgScale.value,
                  colors: const [
                    Color(0xFFE23744),
                    AppColors.primary,
                    AppColors.primaryDark,
                    Color(0xFF6B000A),
                  ],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Rotating decorative rings.
          AnimatedBuilder(
            animation: _ring,
            builder: (context, child) => CustomPaint(
              painter: _RingPainter(_ring.value),
            ),
          ),

          // Centre content.
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo badge with scale + fade.
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: _logoBadge(),
                ),
              ),
              const SizedBox(height: 28),

              // "ZEGAR" wordmark slides up + fades in.
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textFade,
                  child: _wordmark(),
                ),
              ),
              const SizedBox(height: 12),

              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'Smart Workplace Portal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),

          // Bottom loading bar.
          Positioned(
            bottom: 60,
            left: 60,
            right: 60,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _ring,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: null,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                        borderRadius: BorderRadius.circular(10),
                        minHeight: 3,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoBadge() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Colors.white, Color(0xFFF0F0F0)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryLight, AppColors.primaryDark],
          ).createShader(bounds),
          child: const Text(
            'Z',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
              shadows: [
                Shadow(
                  color: Color(0x55000000),
                  offset: Offset(3, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordmark() {
    const style = TextStyle(
      fontSize: 42,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 6,
      height: 1,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('ZE', style: style),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primaryDark],
            ).createShader(bounds),
            child: const Text(
              'Z',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        const Text('AR', style: style),
        Transform.translate(
          offset: const Offset(2, -16),
          child: const Text(
            '®',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < 4; i++) {
      final radius = 80.0 + i * 70;
      final opacity = (0.12 - i * 0.02).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }

    // Two rotating arcs.
    for (var i = 0; i < 2; i++) {
      final dir = i == 0 ? 1.0 : -1.0;
      final radius = 130.0 + i * 90;
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.20);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
          rect, t * 2 * math.pi * dir, math.pi * 0.4, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.t != t;
}

