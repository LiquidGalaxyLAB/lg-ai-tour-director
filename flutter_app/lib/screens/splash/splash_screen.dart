import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

/// First screen shown after the OS-level native splash. Holds the brand for a
/// total of 4 seconds, then hands off to the home tab via GoRouter.
///
/// Two animations run together:
///  • a one-shot staggered entrance — the app logo fades + scales in, then the
///    title, Liquid Galaxy lockup and subtitle slide up in sequence;
///  • a gentle, continuous float on the globe so the screen feels alive during
///    the hold before navigation.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _subtitleColor = Colors.white70;

  late final AnimationController _entrance;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    // Slow up-and-down drift on the globe, looping for the whole splash.
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Total dwell of 4s, then move to the home tab (guard against disposal).
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

  /// Fade + slide-up for a staggered child, active over [start]→[end] of the
  /// entrance timeline.
  Widget _staggered({
    required double start,
    required double end,
    required Widget child,
  }) {
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 18),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Brand-blue vertical gradient — app theme, "google colors", deepened at the
    // bottom for depth so the colourful logos and white title pop.
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.googleBlue,
        Color.lerp(AppColors.googleBlue, Colors.black, 0.45)!,
      ],
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // AI Tour Director app logo: scales + fades in, then floats gently.
              AnimatedBuilder(
                animation: Listenable.merge([_entrance, _float]),
                builder: (context, child) {
                  final intro = CurvedAnimation(
                    parent: _entrance,
                    curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
                  ).value;
                  final bob = (_float.value - 0.5) * 12; // ±6px drift
                  return Opacity(
                    opacity: intro.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, bob),
                      child: Transform.scale(
                        scale: 0.82 + 0.18 * intro,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/logos/app-logo-without-bg.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              // Main title.
              _staggered(
                start: 0.25,
                end: 0.75,
                child: Text(
                  'AI Tour Director',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _staggered(
                start: 0.4,
                end: 0.85,
                child: Image.asset(
                  'assets/logos/lg-logo-splash.png',
                  width: 160,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              // Subtitle.
              _staggered(
                start: 0.55,
                end: 1.0,
                child: Text(
                  'Powered by Liquid Galaxy',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
