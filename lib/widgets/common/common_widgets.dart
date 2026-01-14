import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class CompactCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  const CompactCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.compactCardDecoration(borderRadius: borderRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
    );
  }
}

class CompactButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final bool isSmall;

  const CompactButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = isSmall ? 32.0 : 38.0;
    final fontSize = isSmall ? 12.0 : 13.0;
    final iconSize = isSmall ? 14.0 : 16.0;
    final hPadding = isSmall ? 10.0 : 14.0;

    return SizedBox(
      height: height,
      child: isPrimary
          ? ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
              ),
              child: _buildContent(fontSize, iconSize),
            )
          : OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                side: const BorderSide(color: AppTheme.primaryColor),
              ),
              child: _buildContent(fontSize, iconSize),
            ),
    );
  }

  Widget _buildContent(double fontSize, double iconSize) {
    if (isLoading) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 6),
        ],
        Text(text, style: TextStyle(fontSize: fontSize)),
      ],
    );
  }
}

class IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  const IconAction({
    super.key,
    required this.icon,
    this.onTap,
    this.color,
    this.backgroundColor,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppTheme.elevatedColor,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon,
              size: size * 0.5, color: color ?? AppTheme.textSecondary),
        ),
      ),
    );
  }
}

/// Progress Bar - Compact linear progress
class CompactProgress extends StatelessWidget {
  final double progress;
  final Color? color;
  final double height;

  const CompactProgress({
    super.key,
    required this.progress,
    this.color,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.borderColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (progress / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// Status Chip - Compact status indicator
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Empty State
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style:
                    const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Stat Box - Compact stats display
class StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const StatBox({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.compactCardDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.primaryColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                    color: color ?? AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
              Text(label,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading Overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
      ],
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final EdgeInsets? margin;

  const SkeletonCard({
    super.key,
    this.height = 100,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
        duration: 1200.ms, color: AppTheme.primaryColor.withOpacity(0.1));
  }
}
