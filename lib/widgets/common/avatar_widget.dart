import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';

/// Circular avatar widget with network image, fallback initials, and optional size.
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String  name;
  final double  size;
  final VoidCallback? onTap;
  final bool    showBorder;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size      = 48,
    this.onTap,
    this.showBorder = false,
  });

  String get _initials {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color get _avatarColor {
    final colors = [
      AppColors.primary, AppColors.secondary, AppColors.tertiary,
      const Color(0xFF7B2FFF), const Color(0xFFFF5677), const Color(0xFF00B4D8),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl:   imageUrl!,
        fit:        BoxFit.cover,
        width:      size,
        height:     size,
        placeholder: (_, __) => _buildInitials(),
        errorWidget: (_, __, ___) => _buildInitials(),
      );
    } else {
      avatar = _buildInitials();
    }

    Widget circle = ClipOval(
      child: SizedBox(width: size, height: size, child: avatar),
    );

    if (showBorder) {
      circle = Container(
        width:  size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: circle,
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: circle);
    }
    return circle;
  }

  Widget _buildInitials() => Container(
    width:      size,
    height:     size,
    color:      _avatarColor,
    alignment:  Alignment.center,
    child: Text(
      _initials,
      style: TextStyle(
        color:      Colors.white,
        fontSize:   size * 0.38,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
