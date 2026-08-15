import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// First screen after the OS native splash. Shows the composite brand image
/// (the same one overlaid on the rig's left screen) for ~5.5s with a gentle
/// fade and float, then hands off to Home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fade;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    // Slow up-and-down drift, looping for the whole splash.
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    // Dwell ~5.5s so reviewers can read everything, then go home.
    Future.delayed(const Duration(milliseconds: 5500), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // White to match the composite image's own white background.
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AnimatedBuilder(
                animation: _float,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, (_float.value - 0.5) * 16), // ±8px drift
                  child: child,
                ),
                child: Image.asset(
                  'assets/logos/logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
