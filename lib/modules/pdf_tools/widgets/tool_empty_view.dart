import 'package:flutter/material.dart';

/// Clean and themed empty state across PDF tools featuring the dedicated
/// vector illustration, concise explanation text, and a signature Indigo
/// gradient action button synchronized with the app theme.
class ToolEmptyView extends StatelessWidget {
  final String imagePath;
  final String description;
  final String? title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const ToolEmptyView({
    super.key,
    required this.imagePath,
    required this.description,
    this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textSecondary =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72) ?? Colors.black54;

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Vector Illustration
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 230,
                maxWidth: 290,
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.auto_stories_rounded,
                  size: 72,
                  color: theme.primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Concise Description
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Luxury Themed Action Button
            if (onAction != null) ...[
              const SizedBox(height: 28),
              _LuxuryToolActionButton(
                label: actionLabel ?? 'اختيار الملف',
                icon: actionIcon ?? Icons.file_open_rounded,
                onTap: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LuxuryToolActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _LuxuryToolActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_LuxuryToolActionButton> createState() => _LuxuryToolActionButtonState();
}

class _LuxuryToolActionButtonState extends State<_LuxuryToolActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    // Single smooth specular sweep on mount without an infinite background ticker.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shimmerController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.primaryColor;
    final gradStart = isDark ? const Color(0xFF6366F1) : primary;
    final gradMid = isDark ? primary : const Color(0xFF6366F1);
    final gradEnd = const Color(0xFF7C3AED);

    return Semantics(
      button: true,
      label: widget.label,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [gradStart, gradMid, gradEnd],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.24 : 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? primary : gradStart)
                    .withValues(alpha: _isPressed ? 0.20 : (isDark ? 0.34 : 0.36)),
                blurRadius: _isPressed ? 10 : 22,
                spreadRadius: _isPressed ? 0 : 1,
                offset: Offset(0, _isPressed ? 4 : 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Subtle specular sheen sweep on mount
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, _) {
                        final t = Curves.easeInOutCubic.transform(_shimmerController.value);
                        if (_shimmerController.isDismissed || _shimmerController.isCompleted) {
                          return const SizedBox.shrink();
                        }
                        return FractionalTranslation(
                          translation: Offset(-1.4 + (t * 2.8), 0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: const Alignment(-0.4, -1.0),
                                end: const Alignment(0.4, 1.0),
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.24),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.25, 0.5, 0.75],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) => setState(() => _isPressed = false),
                    onTapCancel: () => setState(() => _isPressed = false),
                    splashColor: Colors.white.withValues(alpha: 0.18),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.26),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 13.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
