import 'dart:math' as math;
import 'package:flutter/material.dart';

class CustomSplashScreen extends StatefulWidget {
  final String title;
  final String? subTitle;
  final Duration duration;

  /// When false, the splash appears instantly (no fade-in), so switching
  /// between loading phases looks like one continuous splash.
  final bool animateEntrance;

  const CustomSplashScreen({
    super.key,
    this.title = '',
    this.subTitle,
    this.duration = const Duration(milliseconds: 1600),
    this.animateEntrance = true,
  });

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with TickerProviderStateMixin {
  // Main breathing glow & scale animation
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  // Expanding aura ripples
  late final AnimationController _rippleController;

  // Entrance pop and fade
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _entranceScaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation (Bounce pop)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _entranceScaleAnimation = Tween<double>(begin: 0.40, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutBack,
      ),
    );

    if (widget.animateEntrance) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }

    // 2. Breathing halo & gentle float
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    // 3. Ambient ripples expanding outward continuously
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Background luxury palette:
    // Dark: Deep Cosmos (#070B14)
    // Light: Pure Crisp Luxury Porcelain (#F8FAFC)
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF070B14)
        : const Color(0xFFF8FAFC);

    final bool isDocumentMode = widget.title.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Background Cosmic Glow Mesh (Centered on the Screen and Logo) ──
            Center(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  final double glowVal = _glowAnimation.value;
                  return Container(
                    width: 330,
                    height: 330,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isDarkMode
                            ? [
                                const Color(0xFF6366F1).withValues(alpha: 0.38 * glowVal),
                                const Color(0xFFA855F7).withValues(alpha: 0.20 * glowVal),
                                Colors.transparent,
                              ]
                            : [
                                const Color(0xFF6366F1).withValues(alpha: 0.22 * glowVal),
                                const Color(0xFF38BDF8).withValues(alpha: 0.15 * glowVal),
                                Colors.transparent,
                              ],
                        stops: const [0.0, 0.46, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Outward Expanding Breathing Rings (Centered Exactly on the Screen and Logo) ──
            Center(
              child: AnimatedBuilder(
                animation: _rippleController,
                builder: (context, child) {
                  final ringColor = isDarkMode
                      ? const Color(0xFF818CF8)
                      : const Color(0xFF6366F1);

                  return CustomPaint(
                    painter: _AuraRipplesPainter(
                      progress: _rippleController.value,
                      ringColor: ringColor,
                      isDark: isDarkMode,
                    ),
                    size: const Size(360, 360),
                  );
                },
              ),
            ),

            // ── Logo Perfectly Centered at Absolute Screen Center (0, 0) ──
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entranceScaleAnimation, _scaleAnimation, _glowAnimation]),
                builder: (context, child) {
                  final double entranceScale = _entranceScaleAnimation.value;
                  final double pulseScale = _scaleAnimation.value;
                  final double glowVal = _glowAnimation.value;
                  final double combinedScale = entranceScale * pulseScale;

                  return Transform.scale(
                    scale: combinedScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Direct Halo hugging the card
                        Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.55 * glowVal)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.25 * glowVal),
                                blurRadius: 32,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),

                        // Frosted squircle card identical to sample
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: isDarkMode
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF312E81),
                                      Color(0xFF1E1B4B),
                                    ],
                                  )
                                : const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF1F5F9),
                                    ],
                                  ),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : const Color(0xFF6366F1).withValues(alpha: 0.22),
                              width: 1.5,
                            ),
                            boxShadow: isDarkMode
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.45 * glowVal),
                                      blurRadius: 26,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.25 * glowVal),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'assets/images/Splash Screen.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.picture_as_pdf_rounded,
                                color: isDarkMode
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5),
                                size: 50,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Bottom Fixed Footer (Subtle Dots + Clean Text) ──
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Loading Dots
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final offset = (index * 0.2);
                          final val = (_pulseController.value + offset) % 1.0;
                          final opacity = 0.3 + (0.7 * (1.0 - (val - 0.5).abs() * 2));
                          final scale = 0.8 + (0.4 * (1.0 - (val - 0.5).abs() * 2));

                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isDarkMode
                                        ? const Color(0xFF818CF8)
                                        : const Color(0xFF6366F1))
                                    .withValues(alpha: opacity.clamp(0.2, 1.0)),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Footer text: Shows File Name when opening document, or 'AURA READER' when launching app
                  Text(
                    isDocumentMode ? widget.title : 'AURA READER',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDocumentMode
                          ? (isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B))
                          : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      fontSize: isDocumentMode ? 12 : 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: isDocumentMode ? 0.3 : 1.8,
                    ),
                  ),

                  if (isDocumentMode && widget.subTitle != null && widget.subTitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.subTitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter that renders continuous, expanding aura wave ripples
class _AuraRipplesPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool isDark;

  _AuraRipplesPainter({
    required this.progress,
    required this.ringColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const minRadius = 55.0;
    const maxRadius = 150.0;
    const ringCount = 3;

    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i / ringCount)) % 1.0;
      final currentRadius = minRadius + (maxRadius - minRadius) * ringProgress;

      // Opacity fades out towards edges: sin curve for smooth fade
      final opacity = math.sin(ringProgress * math.pi) * (isDark ? 0.35 : 0.25);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 - (0.6 * ringProgress)
        ..color = ringColor.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.drawCircle(center, currentRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuraRipplesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.isDark != isDark;
  }
}
