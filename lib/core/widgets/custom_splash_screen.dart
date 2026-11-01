import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.animateEntrance) {
      _entranceController.forward();
    } else {
      _entranceController.value = 1.0;
    }

    // 2. Continuous breathing / pulsing glow animation (2000ms per half-cycle)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.30, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Background color:
    // Dark: Deep Obsidian (#070E17)
    // Light: Pure Crisp Luxury Porcelain (#F8FAFC)
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF070E17)
        : const Color(0xFFF8FAFC);

    final bool isDocumentMode = widget.title.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              // Radial Ambient Aura pulsing behind the logo
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      final double glowVal = _glowAnimation.value;
                      return Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isDarkMode
                                ? [
                                    const Color(0xFF38BDF8)
                                        .withValues(alpha: 0.35 * glowVal),
                                    const Color(0xFF818CF8)
                                        .withValues(alpha: 0.22 * glowVal),
                                    Colors.transparent,
                                  ]
                                : [
                                    const Color(0xFF0284C7)
                                        .withValues(alpha: 0.28 * glowVal),
                                    const Color(0xFF4F46E5)
                                        .withValues(alpha: 0.16 * glowVal),
                                    Colors.transparent,
                                  ],
                            stops: const [0.0, 0.48, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Main Center Content
              Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),

                        // Logo with dynamic pulsing halo and scale
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final double glowVal = _glowAnimation.value;
                        final double scaleVal = _scaleAnimation.value;

                        return Transform.scale(
                          scale: scaleVal,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Atmospheric BoxShadow Halo
                              Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: isDarkMode
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF38BDF8)
                                                .withValues(alpha: 0.45 * glowVal),
                                            blurRadius: 45 * glowVal,
                                            spreadRadius: 8 * glowVal,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF818CF8)
                                                .withValues(alpha: 0.30 * glowVal),
                                            blurRadius: 65 * glowVal,
                                            spreadRadius: 16 * glowVal,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF0284C7)
                                                .withValues(alpha: 0.35 * glowVal),
                                            blurRadius: 38 * glowVal,
                                            spreadRadius: 6 * glowVal,
                                          ),
                                          BoxShadow(
                                            color: const Color(0xFF4F46E5)
                                                .withValues(alpha: 0.22 * glowVal),
                                            blurRadius: 55 * glowVal,
                                            spreadRadius: 12 * glowVal,
                                          ),
                                        ],
                                ),
                              ),

                              // Dedicated Splash Screen Logo
                              SizedBox(
                                width: 145,
                                height: 145,
                                child: Image.asset(
                                  'assets/images/Splash Screen.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.picture_as_pdf_rounded,
                                      color: isDarkMode
                                          ? const Color(0xFF38BDF8)
                                          : const Color(0xFF0284C7),
                                      size: 80,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Typography: App Splash Mode vs Document Loading Mode
                    if (isDocumentMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subTitle ?? 'preparing_pages'.tr,
                        style: TextStyle(
                          color: (isDarkMode ? Colors.white : const Color(0xFF475569))
                              .withValues(alpha: isDarkMode ? 0.6 : 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      // Cinematic App Title
                      Text(
                        'AURA PDF',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.5,
                        ),
                      ),
                      if (widget.subTitle != null &&
                          widget.subTitle!.trim().isNotEmpty &&
                          widget.subTitle!.trim().toLowerCase() != 'aura pdf' &&
                          widget.subTitle!.trim().toLowerCase() != 'orapdf') ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subTitle!,
                          style: TextStyle(
                            color: isDarkMode
                                ? const Color(0xFF38BDF8).withValues(alpha: 0.95)
                                : const Color(0xFF0284C7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ],
                    ],

                    const Spacer(flex: 3),
                    const SizedBox(height: 50),
                  ],
                ),
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
