import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A company logo avatar that degrades to initials on ANY load failure.
///
/// Renders the logo through an HTML `<img>` element (Image.network with
/// `webHtmlElementStrategy`) rather than CircleAvatar's backgroundImage. Reason:
/// on Flutter Web the CanvasKit renderer decodes a network image into a WebGL
/// texture, which browsers forbid for a CROSS-ORIGIN image that arrives without
/// `Access-Control-Allow-Origin`. Firebase Storage's own download URLs
/// (firebasestorage.googleapis.com/...&token=) serve the bytes fine but send NO
/// CORS header for the new-format `.firebasestorage.app` bucket, so every logo
/// failed to texture and fell back to initials. A plain `<img>` has no such
/// restriction — the browser displays cross-origin images, only blocking
/// pixel-readback — so this path shows the logo without any bucket CORS config.
///
/// `WebHtmlElementStrategy.prefer` uses the `<img>` directly instead of first
/// attempting (and failing) the CanvasKit fetch, avoiding a wasted request per
/// logo. The image is hard-bounded by a fixed SizedBox + ClipOval so it can
/// never render at its native size and overflow (an old failure mode of a bare
/// Image.network here). On mobile/desktop this strategy is simply ignored.
class CompanyLogoAvatar extends StatelessWidget {
  final String logoUrl;
  final String companyName;
  final double radius;
  const CompanyLogoAvatar({
    super.key,
    required this.logoUrl,
    required this.companyName,
    this.radius = 40,
  });

  Widget _initials() {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: AppColors.primary.withOpacity(0.15),
      child: Text(
        companyName.isNotEmpty ? companyName[0].toUpperCase() : 'U',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final Widget content = logoUrl.isEmpty
        ? _initials()
        : Image.network(
            logoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            errorBuilder: (_, __, ___) => _initials(),
          );
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: content),
    );
  }
}
