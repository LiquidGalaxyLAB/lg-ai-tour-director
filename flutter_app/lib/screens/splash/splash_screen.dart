import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Color _titleColor = AppColors.googleBlue; // reads on light bg
  static const Color _muted = Color(0xFF5F6368); // slate — grey-safe on light

  static const List<(String, double)> _primary = [
    ('lg-eu', 34),
    ('gsoc', 46),
    ('lg-lab', 30),
  ];

  static const List<(String, double)> _partners = [
    ('gdg-lleida', 28),
    ('flutter-lleida', 38),
    ('parc', 24),
    ('lab-tic', 30),
  ];

  late final AnimationController _entrance;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 5500), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _float.dispose();
    super.dispose();
  }

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
          offset: Offset(0, (1 - curved.value) * 16),
          child: c,
        ),
      ),
      child: child,
    );
  }

  Widget _logo(String name, double height) => Image.asset(
    'assets/logos/$name-trim.png',
    height: height,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
  );

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF5F9FF), Color(0xFFE9F1FC)],
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hero app logo — scales + fades in, then floats gently.
                      AnimatedBuilder(
                        animation: Listenable.merge([_entrance, _float]),
                        builder: (context, child) {
                          final intro = CurvedAnimation(
                            parent: _entrance,
                            curve: const Interval(
                              0.0,
                              0.55,
                              curve: Curves.easeOutBack,
                            ),
                          ).value;
                          final bob = (_float.value - 0.5) * 10;
                          return Opacity(
                            opacity: intro.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, bob),
                              child: Transform.scale(
                                scale: 0.84 + 0.16 * intro,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _logo('app-logo-without-bg', 104),
                      ),
                      const SizedBox(height: 16),
                      _staggered(
                        start: 0.25,
                        end: 0.7,
                        child: Text(
                          'AI Tour Director',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: _titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _staggered(
                        start: 0.4,
                        end: 0.82,
                        child: Text(
                          'Powered by Liquid Galaxy',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Supporters board.
                      _staggered(
                        start: 0.55,
                        end: 1.0,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 380),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SUPPORTED BY',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 22,
                                runSpacing: 16,
                                children: [
                                  for (final (name, h) in _primary)
                                    _logo(name, h),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1, thickness: 1),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 20,
                                runSpacing: 14,
                                children: [
                                  for (final (name, h) in _partners)
                                    _logo(name, h),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
