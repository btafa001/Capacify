import 'package:flutter/material.dart';

/// Premium hover-lift for cards (Linear / Stripe / Attio feel). On pointer hover
/// the child scales up a hair and the pointer becomes a click cursor; the hover
/// state is handed back through [builder] so nested accents (trade badge, left
/// strip, border, shadow) can brighten in sync. Touch devices never hover, so
/// this is inert there — which is the correct behaviour.
///
/// Motion is deliberately small (default scale 1.015, ~180ms): the goal is
/// "selectable and alive", not movement for its own sake.
class HoverLift extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  const HoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.scale = 1.015,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hovered ? widget.scale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOut,
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}

/// A tap target that feels responsive: hover raises confidence (the [builder]
/// can brighten), press compresses it slightly (scale 0.97) so the click reads
/// as physical. Wraps any visual — labelled button, icon button, action-bar
/// cell. Inspiration: Linear / Stripe / Framer.
class PressableButton extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;

  const PressableButton({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.builder(context, _hovered, _pressed),
        ),
      ),
    );
  }
}

/// One-shot fade + slide-up used when a feed item first appears. Kept subtle
/// (opacity 0→1, 10px rise, ~220ms). The caller is responsible for only wrapping
/// genuinely-new items (e.g. via an "already animated" id set) so cards don't
/// re-animate on scroll — re-animation would read as cheap, not premium.
class EntryFade extends StatefulWidget {
  final Widget child;
  /// Optional stagger — the fade waits this long before starting (child stays
  /// invisible meanwhile). Used to cascade a grid of cards in on load.
  final Duration delay;
  const EntryFade({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<EntryFade> createState() => _EntryFadeState();
}

class _EntryFadeState extends State<EntryFade> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
