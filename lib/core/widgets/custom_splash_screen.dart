import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomSplashScreen extends StatefulWidget {
  final String title;
  final String? subTitle;
  final Duration duration; // Custom duration to sync the progress bar animation

  const CustomSplashScreen({
    super.key,
    this.title = '',
    this.subTitle,
    this.duration = const Duration(milliseconds: 2000), // Default to 2s
  });

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _progressController;
  late final Animation<double> _progressAnimation;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // 1. Logo breathing animation (pulse)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // 2. Smooth determinate progress bar animation from 0% to 100%
    _progressController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.linear, // Smooth continuous fill
      ),
    );

    _progressController.forward();

    // 3. Shimmer gradient offset movement
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _progressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    // Check local language direction (Arabic = RTL) using built-in Directionality
    final bool isRtl = Directionality.of(context) == TextDirection.rtl;

    // Solid Opaque Premium Color Palette
    final Color backgroundColor = isDarkMode
        ? const Color(0xFF070E17) // Solid premium dark
        : const Color(0xFFF4F6F9); // Solid premium light

    final Color primaryGlowColor = isDarkMode
        ? const Color(0xFF3F8CFF)
        : const Color(0xFF0056C6);

    // Active Bar Gradient Colors
    final List<Color> activeGradient = isDarkMode
        ? [const Color(0xFF3F8CFF), const Color(0xFF8E3FFF)] // Sky Blue to Neon Purple
        : [const Color(0xFF0056C6), const Color(0xFF3F8CFF)]; // Navy Blue to Sky Blue

    final Color textPrimaryColor = isDarkMode
        ? Colors.white
        : const Color(0xFF1E2A38);

    final Color textSecondaryColor = isDarkMode
        ? Colors.white38
        : Colors.black38;

    final Color shimmerHighlight = isDarkMode
        ? Colors.white70
        : const Color(0xFF3F8CFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // Pulsing Logo in the center (Transparent)
            ScaleTransition(
              scale: _pulseAnimation,
              child: SizedBox(
                width: 140, 
                height: 140,
                child: Image.asset(
                  'assets/images/flutter_launcher_icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.picture_as_pdf_rounded,
                      color: primaryGlowColor,
                      size: 80,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Optional Document Title
            if (widget.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            const Spacer(flex: 2),

            // ── Premium Gradient Progress Bar with RTL Support ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: 6, // Sleek height
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? Colors.white.withValues(alpha: 0.08) 
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode 
                            ? Colors.white.withValues(alpha: 0.05) 
                            : Colors.black.withValues(alpha: 0.04),
                        width: 0.8,
                      ),
                    ),
                    child: Stack(
                      // Directing the fill animation: right-to-left for Arabic, left-to-right for English
                      alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                      children: [
                        FractionallySizedBox(
                          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: activeGradient,
                                begin: isRtl ? Alignment.centerLeft : Alignment.centerRight,
                                end: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryGlowColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 0.5),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Loading Text with Shimmer effect (Bilingual)
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                return ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.35, 0.5, 0.65],
                      colors: [
                        textSecondaryColor,
                        shimmerHighlight,
                        textSecondaryColor,
                      ],
                      transform: _SlideGradientTransform(
                          value: _shimmerController.value),
                    ).createShader(bounds);
                  },
                  child: Text(
                    widget.subTitle ?? 'preparing_pages'.tr,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

// ── Custom Transform to move the shimmer gradient horizontally ──
class _SlideGradientTransform extends GradientTransform {
  final double value;
  const _SlideGradientTransform({required this.value});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double width = bounds.width;
    return Matrix4.translationValues(
        -width + (value * 2 * width), 0.0, 0.0);
  }
}
