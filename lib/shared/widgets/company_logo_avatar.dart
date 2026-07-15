import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A company logo avatar that degrades to initials on ANY load failure —
/// including the Flutter-Web-specific bug where a network image that trips a
/// browser-native fallback path (bad CORS headers, an unexpected
/// content-type, a redirect) renders at its native size, ignoring Flutter's
/// own width/height constraints — seen as a huge grey box overtaking a
/// dialog. A hard SizedBox+ClipOval+Image.network wrapper (tried first, in
/// company_detail_screen.dart) did NOT actually stop this. CircleAvatar's
/// backgroundImage paints through BoxDecoration.image, a different pipeline
/// that's always bounded to the avatar's own circle by Flutter's own paint
/// step — it can't leak past that regardless of what the underlying image
/// does. This is the same mechanism already used (and never buggy) for the
/// avatars on live_capacity_feed_screen.dart's feed cards.
class CompanyLogoAvatar extends StatefulWidget {
  final String logoUrl;
  final String companyName;
  final double radius;
  const CompanyLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.companyName,
    this.radius = 40,
  });

  @override
  State<CompanyLogoAvatar> createState() => _CompanyLogoAvatarState();
}

class _CompanyLogoAvatarState extends State<CompanyLogoAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant CompanyLogoAvatar old) {
    super.didUpdateWidget(old);
    // A different URL (e.g. a fresh upload) deserves a fresh attempt.
    if (old.logoUrl != widget.logoUrl) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final showImage = widget.logoUrl.isNotEmpty && !_failed;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: AppColors.primary.withOpacity(0.15),
      backgroundImage: showImage ? NetworkImage(widget.logoUrl) : null,
      onBackgroundImageError: showImage
          ? (_, __) {
              if (mounted) setState(() => _failed = true);
            }
          : null,
      child: showImage
          ? null
          : Text(
              widget.companyName.isNotEmpty ? widget.companyName[0].toUpperCase() : 'U',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.75,
              ),
            ),
    );
  }
}
