import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/avatar_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_palette.dart';
import '../../utils/app_typography.dart';

/// Round avatar: the photo if there is one, otherwise initials on a soft,
/// per-person colour (the same person always gets the same colour).
///
/// Pass [uid] where the person is known: their current profile photo then
/// shows even if [imageUrl] is an older copy (a tour keeps the photo a member
/// had when they joined).
class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? uid;
  final String  name;
  final double  size;
  final VoidCallback? onTap;
  /// A gold ring around the avatar (the signed-in user, the admin, ...).
  final bool    showBorder;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.uid,
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

  /// Stable colour per name.
  static Color toneFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return AppColors.avatarTones[h % AppColors.avatarTones.length];
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.palette;
    final tone = toneFor(name);

    final initials = Container(
      width:     size,
      height:    size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            Color.lerp(tone, Colors.white, p.isDark ? 0.10 : 0.30)!,
            Color.lerp(tone, Colors.black, p.isDark ? 0.35 : 0.08)!,
          ],
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontFamily:    AppType.display,
          color:         Colors.white,
          fontSize:      size * 0.36,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );

    final tokenUid = AvatarService.uidFromToken(imageUrl);
    final isWebUrl = tokenUid == null && imageUrl != null && imageUrl!.startsWith('http');
    final fallback = isWebUrl
        ? CachedNetworkImage(
            imageUrl:    imageUrl!,
            fit:         BoxFit.cover,
            // On the website, download the photo and decode it like an
            // uploaded one, instead of the browser-image shortcut (which can
            // draw a black circle).
            imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
            placeholder: (_, __) => initials,
            errorWidget: (_, __, ___) => initials,
          )
        : initials;

    // Uploaded profile photos live in the database (see AvatarService).
    final photoUid = tokenUid ?? uid;
    final Widget photo = photoUid == null
        ? fallback
        : ValueListenableBuilder<Uint8List?>(
            valueListenable: AvatarStore.photoOf(photoUid),
            builder: (_, bytes, __) => bytes == null
                ? fallback
                : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, width: size, height: size),
          );

    Widget circle = ClipOval(child: SizedBox(width: size, height: size, child: photo));

    if (showBorder) {
      circle = Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
        child: Container(
          padding:    const EdgeInsets.all(2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.background),
          child:      circle,
        ),
      );
    }

    return onTap == null ? circle : GestureDetector(onTap: onTap, child: circle);
  }
}

/// Overlapping avatars: "these people are in the tour".
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final List<String?> imageUrls;
  final List<String> uids;
  final double size;
  final int max;
  /// Colour of the gap ring between avatars (the surface they sit on).
  final Color? ringColor;

  const AvatarStack({
    super.key,
    required this.names,
    this.imageUrls = const [],
    this.uids = const [],
    this.size = 30,
    this.max = 4,
    this.ringColor,
  });

  @override
  Widget build(BuildContext context) {
    final p     = context.palette;
    final ring  = ringColor ?? p.background;
    final shown = names.take(max).toList();
    final extra = names.length - shown.length;
    final step  = size * 0.68;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      width:  count == 0 ? 0 : step * (count - 1) + size + 4,
      height: size + 4,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: Container(
                padding:    const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
                child: AvatarWidget(
                  name:     shown[i],
                  imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                  uid:      i < uids.length ? uids[i] : null,
                  size:     size,
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: Container(
                width: size + 4, height: size + 4,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape:  BoxShape.circle,
                  color:  p.surfaceSunken,
                  border: Border.all(color: ring, width: 2),
                ),
                child: Text('+$extra',
                    style: TextStyle(fontFamily: AppType.display, fontSize: size * 0.34, fontWeight: FontWeight.w700, color: p.text)),
              ),
            ),
        ],
      ),
    );
  }
}
