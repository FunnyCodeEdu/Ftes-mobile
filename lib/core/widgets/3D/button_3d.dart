import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Button style variants
enum Button3DVariant {
  /// Outline style - only border, transparent background
  outline,

  /// Solid style - filled background color
  solid,

  /// Gradient style - gradient background
  gradient,

  /// Carbon style - carbon fiber pattern effect
  carbon,
}

/// A modern 3D button with multiple style variants
/// Features a shadow layer behind the button
/// When pressed, the face layer moves down and shadow shrinks for 3D effect
class OutlineButton3D extends StatefulWidget {
  /// The text to display on the button
  final String text;

  /// Callback function when button is pressed
  final VoidCallback? onPressed;

  /// Border radius for the button (default: 22)
  final double borderRadius;

  /// Border width (default: 2.0)
  final double borderWidth;

  /// Button style variant (default: outline)
  final Button3DVariant variant;

  /// Blue color for border and shadow (default: Colors.blue)
  final Color borderColor;

  /// Background color of the button (used for solid variant)
  final Color? backgroundColor;

  /// Gradient colors for gradient variant (top color, bottom color)
  final List<Color>? gradientColors;

  /// Spacing between button and shadow layer (default: 4.0)
  final double shadowOffset;

  /// Button width (optional, will wrap content if not specified)
  final double? width;

  /// Button height (default: 56.0)
  final double height;

  /// Padding inside the button (default: EdgeInsets.symmetric(horizontal: 32, vertical: 16))
  final EdgeInsetsGeometry? padding;

  /// Font size for the text (default: 16.0)
  final double? fontSize;

  /// Auto-size button width to fit text content (default: false)
  /// When true, button will automatically adjust width to fit text
  /// Note: Height is always independent and uses the height parameter
  final bool autoSize;

  /// Icon to display before or after text
  final IconData? icon;

  /// Whether icon is on the right side (default: false, icon on left)
  final bool iconOnRight;

  /// Icon size (default: null, will use fontSize + 4 if provided)
  final double? iconSize;

  const OutlineButton3D({
    super.key,
    this.text = 'Outline',
    this.onPressed,
    this.variant = Button3DVariant.outline,
    this.borderRadius = 22.0,
    this.borderWidth = 2.0,
    this.borderColor = Colors.blue,
    this.backgroundColor,
    this.gradientColors,
    this.shadowOffset = 4.0,
    this.width,
    this.height = 56.0,
    this.padding,
    this.fontSize,
    this.autoSize = false,
    this.icon,
    this.iconOnRight = false,
    this.iconSize,
  });

  @override
  State<OutlineButton3D> createState() => _OutlineButton3DState();
}

class _OutlineButton3DState extends State<OutlineButton3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      _animationController.reverse();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) {
      _animationController.reverse();
    }
  }

  /// Get button decoration based on variant
  BoxDecoration _getButtonDecoration(Color shadowColor) {
    switch (widget.variant) {
      case Button3DVariant.outline:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.borderColor,
            width: widget.borderWidth,
          ),
        );

      case Button3DVariant.solid:
        return BoxDecoration(
          color: widget.backgroundColor ?? widget.borderColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.borderWidth > 0
              ? Border.all(color: widget.borderColor, width: widget.borderWidth)
              : null,
        );

      case Button3DVariant.gradient:
        final colors =
            widget.gradientColors ??
            [
              widget.backgroundColor ?? widget.borderColor,
              (widget.backgroundColor ?? widget.borderColor).withValues(
                alpha: 0.85,
              ),
            ];
        return BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.borderWidth > 0
              ? Border.all(color: widget.borderColor, width: widget.borderWidth)
              : null,
        );

      case Button3DVariant.carbon:
        // Carbon fiber effect with dark gradient
        final carbonColors = [
          const Color(0xFF1A1A1A),
          const Color(0xFF2D2D2D),
          const Color(0xFF1A1A1A),
        ];
        return BoxDecoration(
          gradient: LinearGradient(
            colors: carbonColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: Colors.grey.shade700,
            width: widget.borderWidth > 0 ? widget.borderWidth : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        );
    }
  }

  /// Get text color based on variant
  Color _getTextColor() {
    switch (widget.variant) {
      case Button3DVariant.outline:
        return widget.borderColor;
      case Button3DVariant.solid:
        return widget.backgroundColor != null
            ? Colors.white
            : widget.borderColor;
      case Button3DVariant.gradient:
        return Colors.white;
      case Button3DVariant.carbon:
        return Colors.white;
    }
  }

  /// Get shadow color based on variant
  Color _getShadowColor() {
    switch (widget.variant) {
      case Button3DVariant.outline:
        return widget.borderColor;
      case Button3DVariant.solid:
        if (widget.backgroundColor != null) {
          return Color.fromRGBO(
            (widget.backgroundColor!.red * 0.7).round().clamp(0, 255),
            (widget.backgroundColor!.green * 0.7).round().clamp(0, 255),
            (widget.backgroundColor!.blue * 0.7).round().clamp(0, 255),
            1.0,
          );
        }
        return widget.borderColor;
      case Button3DVariant.gradient:
        final colors =
            widget.gradientColors ??
            [
              widget.backgroundColor ?? widget.borderColor,
              (widget.backgroundColor ?? widget.borderColor).withValues(
                alpha: 0.85,
              ),
            ];
        return Color.fromRGBO(
          (colors.last.red * 0.7).round().clamp(0, 255),
          (colors.last.green * 0.7).round().clamp(0, 255),
          (colors.last.blue * 0.7).round().clamp(0, 255),
          1.0,
        );
      case Button3DVariant.carbon:
        return Colors.black.withValues(alpha: 0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor();
    final shadowColor = _getShadowColor();

    final textStyle = TextStyle(
      color: textColor,
      fontSize: widget.fontSize ?? 16,
      fontWeight: FontWeight.w600, // Semi-bold
      letterSpacing: 0.5,
    );

    final paddingValue =
        widget.padding ??
        const EdgeInsets.symmetric(horizontal: 32, vertical: 16);

    // Calculate text size if autoSize is enabled or width is not specified
    // Note: fontSize and height are independent - fontSize only affects text size
    double? calculatedWidth;

    if (widget.autoSize || widget.width == null) {
      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      );

      // Use a large maxWidth for initial layout if width is not specified
      final maxWidth = widget.width ?? double.infinity;
      if (maxWidth.isFinite && maxWidth > 0) {
        textPainter.layout(
          maxWidth:
              maxWidth - paddingValue.horizontal - (widget.borderWidth * 2),
        );
      } else {
        // If no width constraint, layout with a reasonable max width
        textPainter.layout(
          maxWidth: 300 - paddingValue.horizontal - (widget.borderWidth * 2),
        );
      }

      final textSize = textPainter.size;

      // Auto-calculate width if not specified or autoSize is true
      // Height is always independent and uses the height parameter
      if (widget.width == null || widget.autoSize) {
        double iconWidth = 0;
        if (widget.icon != null) {
          final iconSizeValue = widget.iconSize ?? (widget.fontSize ?? 16) + 4;
          iconWidth = iconSizeValue + 8; // icon size + spacing
        }
        calculatedWidth =
            textSize.width +
            paddingValue.horizontal +
            (widget.borderWidth * 2) +
            iconWidth;
      }
    }

    final actualWidth = widget.width ?? calculatedWidth;
    // Height is always independent - use the height parameter directly
    final actualHeight = widget.height;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: SizedBox(
        width: actualWidth,
        height: actualHeight + widget.shadowOffset,
        child: Stack(
          children: [
            // Shadow layer (bottom layer) - shrinks when pressed
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pressAnimation,
                builder: (context, child) {
                  // Calculate shadow height: reduces to 0 when pressed
                  final shadowHeight =
                      actualHeight * (1 - _pressAnimation.value);
                  return Container(
                    height: shadowHeight,
                    decoration: BoxDecoration(
                      color: shadowColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  );
                },
              ),
            ),
            // Main button (top layer) - moves down when pressed
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _pressAnimation,
                builder: (context, child) {
                  // Calculate translation: moves down by shadowOffset when pressed
                  final faceTranslationY =
                      _pressAnimation.value * widget.shadowOffset;
                  return Transform.translate(
                    offset: Offset(0, faceTranslationY),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: null, // Handled by GestureDetector
                        borderRadius: BorderRadius.circular(
                          widget.borderRadius,
                        ),
                        child: Container(
                          height: actualHeight,
                          width: actualWidth,
                          padding: paddingValue,
                          decoration: _getButtonDecoration(shadowColor),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (widget.icon != null &&
                                  !widget.iconOnRight) ...[
                                Icon(
                                  widget.icon,
                                  color: textColor,
                                  size:
                                      widget.iconSize ??
                                      ((widget.fontSize ?? 16) + 4),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  widget.text,
                                  style: textStyle,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                              ),
                              if (widget.icon != null &&
                                  widget.iconOnRight) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  widget.icon,
                                  color: textColor,
                                  size:
                                      widget.iconSize ??
                                      ((widget.fontSize ?? 16) + 4),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
