import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable card component enforcing consistent corner radii, borders, and theme colors.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? borderSide;
  final double? elevation;
  final bool isSelected;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.color,
    this.borderSide,
    this.elevation,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBorder = BorderSide(
      color: isSelected
          ? AppColors.primary
          : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
      width: isSelected ? 1.8 : 1.0,
    );

    final cardBackgroundColor =
        color ??
        (isSelected
            ? (isDark ? AppColors.darkNavSelected : AppColors.lightNavSelected)
            : (isDark ? AppColors.darkSurface : AppColors.lightSurface));

    final cardShape = RoundedRectangleBorder(
      borderRadius: AppSpacing.borderRadiusMd,
      side: borderSide ?? defaultBorder,
    );

    if (onTap != null) {
      return Card(
        color: cardBackgroundColor,
        elevation: elevation ?? 0,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Padding(padding: padding, child: child),
        ),
      );
    }

    return Card(
      color: cardBackgroundColor,
      elevation: elevation ?? 0,
      shape: cardShape,
      child: Padding(padding: padding, child: child),
    );
  }
}
