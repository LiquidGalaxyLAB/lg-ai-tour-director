import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// First screen shown after the OS-level native splash. Holds the brand for a
/// total of 4 seconds (logo gently fades in over the first 800ms), then hands
/// off to the home tab via GoRouter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // dark navy backdrop — matches the native splash for a seamless handoff
  static const Color _background = Color(0xFF1A1A2E);
  static const Color _subtitleColor = Color(0xFF9AA0A6);

  late final AnimationController _fadeController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // Total dwell of 4s, then move to the home tab (guard against disposal).
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Tour Director app logo (globe wrapped in film strip).
              Image.asset(
                'assets/logos/app-logo-without-bg.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              // Main title.
              Text(
                'AI Tour Director',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              // "Liquid Galaxy" lockup below the title.
              Image.asset(
                'assets/logos/lg-logo-for-app.png',
                width: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              // Subtitle.
              Text(
                'Powered by Liquid Galaxy',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
