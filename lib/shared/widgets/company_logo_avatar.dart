import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A company logo avatar that degrades to initials on ANY load failure.
///
/// Renders as an ordinary canvas-drawn `Image.network`, hard-bounded by a fixed
/// SizedBox + ClipOval so it can never paint at its native size and overflow
/// (an old failure mode of a bare Image.network here).
///
/// This widget previously forced an HTML `<img>` via
/// `webHtmlElementStrategy: WebHtmlElementStrategy.prefer`, because Flutter
/// Web's CanvasKit renderer decodes a network image into a WebGL texture, which
/// browsers forbid for a CROSS-ORIGIN image arriving without
/// `Access-Control-Allow-Origin` — and the Storage download URLs
/// (firebasestorage.googleapis.com/...&token=) served the bytes with no CORS
/// header, so every logo failed to texture and fell back to initials.
///
/// That was fixed at the source on 2026-07-20 by setting CORS on the bucket
/// (`gsutil cors set cors.json gs://capacify-mvp.firebasestorage.app`; the
/// config lives in cors.json at the repo root). Verified: the download URLs now
/// return `Access-Control-Allow-Origin` for the allowlisted origins and nothing
/// for anything else. So the `<img>` workaround is gone, and with it the
/// scroll-time jitter it caused — an `<img>` is a browser-composited layer
/// positioned via CSS on a different pipeline than Flutter's canvas, so it
/// lagged a frame behind its card while a list moved. A canvas-drawn image
/// moves in perfect lockstep instead.
///
/// If logos ever regress to initials on web, check the bucket's CORS config
/// FIRST (`gsutil cors get gs://capacify-mvp.firebasestorage.app`) — and note
/// that a NEW serving origin must be added to cors.json, or its logos break
/// while every existing origin keeps working.
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

  Widget _photo() {
    final size = radius * 2;
    return logoUrl.isEmpty
        ? _initials()
        : Image.network(
            logoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials(),
          );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    // The photo stays mounted at all times, including mid-scroll.
    //
    // Do NOT reintroduce the "hide the logo while an ancestor is scrolling"
    // trick (swapping in a canvas placeholder gated on
    // Scrollable.position.isScrollingNotifier). It targeted the old <img>
    // pipeline lag described in the class doc, but the cure was far worse on
    // touch: isScrollingNotifier stays true for the WHOLE drag, so merely
    // holding a finger on the Unternehmen list blanked every logo on screen
    // until release. The lag it worked around no longer exists anyway now
    // that the logo is canvas-drawn.
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: _photo()),
    );
  }
}
