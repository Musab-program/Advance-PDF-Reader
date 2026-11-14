import 'dart:ui';

import 'package:flutter/material.dart';

/// A concise feature or instructional row displayed inside [LuxuryDialog].
class LuxuryDialogHighlight {
  final IconData icon;
  final String text;

  const LuxuryDialogHighlight({
    required this.icon,
    required this.text,
  });
}

/// Bespoke frosted-glass modal dialog synchronized with the app's Indigo Light/Dark theme.
///
/// Supports both rich promotional/guide presentation (`compact: false`) and streamlined
/// compact dialogs (`compact: true`) for confirmations, inputs, save flows, and pickers.
class LuxuryDialog extends StatefulWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? badgeText;
  final IconData? badgeIcon;
  final Color? accentColor;
  final bool compact;
  final double? maxWidth;
  final Widget? body;
  final String? highlightsTitle;
  final List<LuxuryDialogHighlight>? highlights;
  final bool showActions;
  final String? primaryButtonText;
  final IconData? primaryButtonIcon;
  final VoidCallback? onPrimaryPressed;
  final bool closeOnPrimary;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final Color? secondaryButtonColor;
  final Widget? customActions;
  final bool showCloseButton;

  const LuxuryDialog({
    super.key,
    required this.title,
    required this.icon,
    this.message,
    this.badgeText,
    this.badgeIcon,
    this.accentColor,
    this.compact = false,
    this.maxWidth,
    this.body,
    this.highlightsTitle,
    this.highlights,
    this.showActions = true,
    this.primaryButtonText,
    this.primaryButtonIcon,
    this.onPrimaryPressed,
    this.closeOnPrimary = true,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.secondaryButtonColor,
    this.customActions,
    this.showCloseButton = true,
  });

  /// Resolves harmonious 2-stop gradient colors for either the default Indigo
  /// app theme or an explicit custom [accentColor] (e.g., red destructive or green).
  static (Color start, Color end) resolveGradientColors(
    ThemeData theme, {
    Color? accentColor,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    if (accentColor == null) {
      final primary = theme.primaryColor;
      final start = isDark
          ? Color.lerp(primary, const Color(0xFF4F46E5), 0.48)!
          : primary;
      final end = const Color(0xFF7C3AED);
      return (start, end);
    }

    final hsl = HSLColor.fromColor(accentColor);
    final start = isDark
        ? hsl.withLightness((hsl.lightness * 0.92).clamp(0.38, 0.56)).toColor()
        : accentColor;
    final end = hsl
        .withHue((hsl.hue + 10) % 360)
        .withLightness((hsl.lightness * 0.78).clamp(0.28, 0.48))
        .toColor();
    return (start, end);
  }

  /// Shared glass-bordered card decoration reused by specialized dialogs.
  static BoxDecoration cardDecoration(
    BuildContext context, {
    Color? accentColor,
    double borderRadius = 26,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? theme.primaryColor;

    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : theme.dividerColor.withValues(alpha: 0.9),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.14),
          blurRadius: 34,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: effectiveAccent.withValues(alpha: isDark ? 0.15 : 0.11),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Reusable tactile gradient button styled consistently with [LuxuryDialog].
  static Widget gradientButton({
    required BuildContext context,
    required String label,
    IconData? icon,
    Color? accentColor,
    VoidCallback? onTap,
    double height = 46,
    double borderRadius = 15,
  }) {
    return _LuxuryGradientButton(
      label: label,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Presents a standard [LuxuryDialog] with a frosted blur backdrop and spring entrance.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required IconData icon,
    String? message,
    String? badgeText,
    IconData? badgeIcon,
    Color? accentColor,
    bool compact = false,
    double? maxWidth,
    Widget? body,
    String? highlightsTitle,
    List<LuxuryDialogHighlight>? highlights,
    bool showActions = true,
    String? primaryButtonText,
    IconData? primaryButtonIcon,
    VoidCallback? onPrimaryPressed,
    bool closeOnPrimary = true,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
    Color? secondaryButtonColor,
    Widget? customActions,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showCustom<bool>(
      context,
      barrierDismissible: barrierDismissible,
      builder: (_) => LuxuryDialog(
        title: title,
        icon: icon,
        message: message,
        badgeText: badgeText,
        badgeIcon: badgeIcon,
        accentColor: accentColor,
        compact: compact,
        maxWidth: maxWidth,
        body: body,
        highlightsTitle: highlightsTitle,
        highlights: highlights,
        showActions: showActions,
        primaryButtonText: primaryButtonText,
        primaryButtonIcon: primaryButtonIcon,
        onPrimaryPressed: onPrimaryPressed,
        closeOnPrimary: closeOnPrimary,
        secondaryButtonText: secondaryButtonText,
        onSecondaryPressed: onSecondaryPressed,
        secondaryButtonColor: secondaryButtonColor,
        customActions: customActions,
        showCloseButton: showCloseButton,
      ),
    );
  }

  /// Presents any stateful or custom [WidgetBuilder] using [LuxuryDialog]'s
  /// unified frosted-blur backdrop and spring scale transition.
  static Future<T?> showCustom<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showGeneralDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.62 : 0.44),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return builder(dialogContext);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedScale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final curvedFade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        );

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.5 * curvedFade.value,
            sigmaY: 5.5 * curvedFade.value,
          ),
          child: FadeTransition(
            opacity: curvedFade,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(curvedScale),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<LuxuryDialog> createState() => _LuxuryDialogState();
}

class _LuxuryDialogState extends State<LuxuryDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sheenController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  void _handlePrimaryTap() {
    if (widget.closeOnPrimary) {
      Navigator.of(context).pop(true);
    }
    widget.onPrimaryPressed?.call();
  }

  void _handleSecondaryTap() {
    Navigator.of(context).pop(false);
    widget.onSecondaryPressed?.call();
  }

  void _handleDismiss() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? theme.primaryColor;
    final (gradStart, gradEnd) = LuxuryDialog.resolveGradientColors(
      theme,
      accentColor: widget.accentColor,
    );

    final cardColor = theme.cardColor;
    final titleColor = theme.textTheme.titleLarge?.color ??
        (isDark ? Colors.white : const Color(0xFF0F172A));
    final bodyColor = theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.78) ??
        (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569));

    final isCompact = widget.compact;
    final resolvedMaxWidth = widget.maxWidth ?? (isCompact ? 360.0 : 385.0);
    final radius = isCompact ? 24.0 : 28.0;
    final hasHighlights =
        widget.highlights != null && widget.highlights!.isNotEmpty;
    final hasMessage = widget.message != null && widget.message!.trim().isNotEmpty;

    return AnimatedPadding(
      padding: MediaQuery.viewInsetsOf(context),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
              child: Container(
                decoration: LuxuryDialog.cardDecoration(
                  context,
                  accentColor: widget.accentColor,
                  borderRadius: radius,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeroHeader(
                          isCompact: isCompact,
                          isDark: isDark,
                          cardColor: cardColor,
                          accent: accent,
                          gradStart: gradStart,
                          gradEnd: gradEnd,
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              isCompact ? 20 : 24,
                              isCompact ? 0 : 4,
                              isCompact ? 20 : 24,
                              isCompact ? 20 : 24,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.badgeText != null) ...[
                                  _buildStatusBadge(
                                    isDark: isDark,
                                    accent: accent,
                                    gradStart: gradStart,
                                  ),
                                  SizedBox(height: isCompact ? 10 : 14),
                                ],
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: isCompact ? 17.5 : 20,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3,
                                  ),
                                ),
                                if (hasMessage) ...[
                                  SizedBox(height: isCompact ? 7 : 10),
                                  Text(
                                    widget.message!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: bodyColor,
                                      fontSize: isCompact ? 13.0 : 13.8,
                                      height: 1.55,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                if (widget.body != null) ...[
                                  SizedBox(height: isCompact ? 14 : 18),
                                  widget.body!,
                                ],
                                if (hasHighlights) ...[
                                  SizedBox(height: isCompact ? 14 : 18),
                                  _buildHighlightsCard(
                                    theme: theme,
                                    isDark: isDark,
                                    accent: accent,
                                    textColor: titleColor,
                                  ),
                                ],
                                if (widget.showActions) ...[
                                  SizedBox(height: isCompact ? 16 : 22),
                                  _buildActions(theme, isDark),
                                ],
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
      ),
    );
  }

  Widget _buildHeroHeader({
    required bool isCompact,
    required bool isDark,
    required Color cardColor,
    required Color accent,
    required Color gradStart,
    required Color gradEnd,
  }) {
    final headerHeight = isCompact ? 88.0 : 132.0;
    final outerHaloSize = isCompact ? 68.0 : 88.0;
    final emblemSize = isCompact ? 52.0 : 68.0;
    final emblemRadius = isCompact ? 16.0 : 21.0;
    final iconSize = isCompact ? 25.0 : 32.0;

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.19 : 0.11),
                    gradEnd.withValues(alpha: isDark ? 0.06 : 0.03),
                    cardColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          if (!isCompact)
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
                  width: 1,
                ),
              ),
            ),
          Container(
            width: outerHaloSize,
            height: outerHaloSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isCompact ? 21 : 28),
              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.24 : 0.18),
                width: 1,
              ),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: emblemSize,
                height: emblemSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(emblemRadius),
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [gradStart, gradEnd],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradStart.withValues(alpha: isDark ? 0.40 : 0.32),
                      blurRadius: isCompact ? 12 : 18,
                      offset: Offset(0, isCompact ? 5 : 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(emblemRadius - 1),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _sheenController,
                        builder: (context, _) {
                          if (_sheenController.isDismissed ||
                              _sheenController.isCompleted) {
                            return const SizedBox.shrink();
                          }
                          final t = Curves.easeInOutCubic.transform(
                            _sheenController.value,
                          );
                          return FractionalTranslation(
                            translation: Offset(-1.5 + (t * 3.0), 0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: const Alignment(-0.5, -1.0),
                                  end: const Alignment(0.5, 1.0),
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.32),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.25, 0.5, 0.75],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      Icon(
                        widget.icon,
                        size: iconSize,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.badgeText != null || widget.badgeIcon != null)
                PositionedDirectional(
                  bottom: -4,
                  end: -4,
                  child: Container(
                    width: isCompact ? 22 : 26,
                    height: isCompact ? 22 : 26,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cardColor,
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.badgeIcon ?? Icons.auto_awesome_rounded,
                      size: isCompact ? 11.5 : 13.5,
                      color: isDark ? const Color(0xFFC7D2FE) : gradStart,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.showCloseButton)
            PositionedDirectional(
              top: isCompact ? 12 : 14,
              end: isCompact ? 12 : 14,
              child: Semantics(
                button: true,
                label: 'إغلاق',
                child: Material(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _handleDismiss,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isDark,
    required Color accent,
    required Color gradStart,
  }) {
    final pillTextColor =
        isDark ? Color.lerp(accent, Colors.white, 0.55)! : gradStart;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.34 : 0.24),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pillTextColor,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              widget.badgeText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: pillTextColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightsCard({
    required ThemeData theme,
    required bool isDark,
    required Color accent,
    required Color textColor,
  }) {
    final items = widget.highlights!;
    final badgeIconColor =
        isDark ? Color.lerp(accent, Colors.white, 0.45)! : accent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.scaffoldBackgroundColor.withValues(alpha: 0.65)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : theme.dividerColor.withValues(alpha: 0.85),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.highlightsTitle != null) ...[
            Text(
              widget.highlightsTitle!,
              style: TextStyle(
                color: badgeIconColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    items[i].icon,
                    size: 15.5,
                    color: badgeIconColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      items[i].text,
                      style: TextStyle(
                        color: textColor.withValues(alpha: isDark ? 0.90 : 0.86),
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(ThemeData theme, bool isDark) {
    if (widget.customActions != null) {
      return widget.customActions!;
    }

    final btnHeight = widget.compact ? 45.0 : 48.0;
    final primaryButton = _LuxuryGradientButton(
      label: widget.primaryButtonText ?? 'حسناً',
      icon: widget.primaryButtonIcon,
      accentColor: widget.accentColor,
      onTap: _handlePrimaryTap,
      height: btnHeight,
      borderRadius: 15,
    );

    if (widget.secondaryButtonText == null) {
      return SizedBox(width: double.infinity, child: primaryButton);
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _handleSecondaryTap,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(btnHeight),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: widget.secondaryButtonColor,
              side: BorderSide(
                color: widget.secondaryButtonColor?.withValues(alpha: 0.45) ??
                    (isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : theme.dividerColor),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Text(
              widget.secondaryButtonText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: widget.secondaryButtonColor ??
                    theme.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: primaryButton),
      ],
    );
  }
}

class _LuxuryGradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;

  const _LuxuryGradientButton({
    required this.label,
    required this.height,
    required this.borderRadius,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  State<_LuxuryGradientButton> createState() => _LuxuryGradientButtonState();
}

class _LuxuryGradientButtonState extends State<_LuxuryGradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (gradStart, gradEnd) = LuxuryDialog.resolveGradientColors(
      theme,
      accentColor: widget.accentColor,
    );
    final glowColor = widget.accentColor ?? (isDark ? theme.primaryColor : gradStart);

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: [gradStart, gradEnd],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: _isPressed ? 0.16 : 0.30),
              blurRadius: _isPressed ? 8 : 16,
              offset: Offset(0, _isPressed ? 3 : 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap == null ? null : (_) => setState(() => _isPressed = true),
            onTapUp: widget.onTap == null ? null : (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: Colors.white.withValues(alpha: 0.18),
            child: SizedBox(
              height: widget.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: Colors.white),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
