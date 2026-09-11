import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/profile_initials.dart';

/// Circular profile photo, or initials when [imageUrl] is missing / fails.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
    this.onTap,
    this.onDarkBackground = false,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final VoidCallback? onTap;
  final bool onDarkBackground;

  static const _fill = Color(0xFF556285);

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final photo = imageUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;
    final initials = ProfileInitials.fromName(name);
    final colors = AppColors.of(context);
    final ring = onDarkBackground
        ? Colors.white.withValues(alpha: 0.35)
        : colors.brand.withValues(alpha: 0.28);

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill,
        border: Border.all(color: ring, width: 1.5),
        boxShadow: onDarkBackground
            ? null
            : [
                BoxShadow(
                  color: colors.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: hasPhoto
          ? Image.network(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _InitialsLabel(
                initials: initials,
                radius: radius,
              ),
            )
          : _InitialsLabel(initials: initials, radius: radius),
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}

class _InitialsLabel extends StatelessWidget {
  const _InitialsLabel({required this.initials, required this.radius});

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (initials.isEmpty) {
      return Icon(
        Icons.person,
        size: radius * 1.05,
        color: Colors.white,
      );
    }
    return Text(
      initials,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.72,
        fontWeight: FontWeight.w700,
        height: 1,
        letterSpacing: 0.4,
      ),
    );
  }
}
