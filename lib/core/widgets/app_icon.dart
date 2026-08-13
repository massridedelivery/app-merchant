import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:merchant_app/core/assets/app_icons.dart';

/// Renders an icon from [AppIcons].
///
/// Handles both the SVG and the PNG entries of the icon set, and applies a
/// `srcIn` tint so the single-colour icons follow the semantic palette. Icons
/// listed in [AppIcons.brandColored] keep their own artwork colours.
///
/// [size] and [color] fall back to the ambient [IconTheme], which makes this a
/// drop-in replacement for [Icon] — including inside widgets that style a
/// subtree with `IconTheme`.
///
/// ```dart
/// AppIcon(AppIcons.houseLine, color: AppColors.semanticGrayNeutralFgHigh)
/// ```
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final String asset;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24;
    final effectiveColor = color ?? iconTheme.color;
    final tint = AppIcons.brandColored.contains(asset) ? null : effectiveColor;

    if (asset.endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
        colorFilter:
            tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
      );
    }

    return Image.asset(
      asset,
      width: effectiveSize,
      height: effectiveSize,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      color: tint,
    );
  }
}
