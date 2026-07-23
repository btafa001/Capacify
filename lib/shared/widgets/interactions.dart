import 'package:flutter/material.dart';

/// A visible focus ring, drawn OVER the child without affecting its layout.
///
/// Both interactive wrappers below are built around a bare [GestureDetector],
/// which has no focus affordance of its own. Hover alone can't stand in for
/// one: a keyboard user never hovers, and a mouse user's hover state is gone
/// the moment they tab. This is the "which control am I on?" indicator, and
/// it has to be drawn rather than implied — the hover treatments these widgets
/// already apply (a 1.5% scale, a border tint) are far too subtle to serve as
/// a focus indicator on their own.
class _FocusRing extends StatelessWidget {
  final bool visible;
  final double radius;
  final Widget child;

  const _FocusRing({required this.visible, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      // passthrough, not the default loose: these wrap cards and full-width
      // action bars that size themselves off tight incoming constraints.
      // Loosening them would let those children shrink-wrap, silently
      // narrowing every card and button the ring is wrapped around.
      fit: StackFit.passthrough,
      children: [
        child,
        if (visible)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keyboard activation for a tappable that isn't a real button.
///
/// The framework binds Enter / Space / numpad-Enter to [ActivateIntent] (and
/// buttons additionally to [ButtonActivateIntent]) but nothing dispatches
/// those to a [GestureDetector.onTap]. Both are registered so a focused
/// wrapper responds to the keys a user will actually press.
Map<Type, Action<Intent>> _activateActions(VoidCallback? onTap) {
  void invoke() => onTap?.call();
  return <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => invoke()),
    ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) => invoke()),
  };
}

/// Premium hover-lift for cards (Linear / Stripe / Attio feel). On pointer hover
/// the child scales up a hair and the pointer becomes a click cursor; the hover
/// state is handed back through [builder] so nested accents (trade badge, left
/// strip, border, shadow) can brighten in sync. Touch devices never hover, so
/// this is inert there — which is the correct behaviour.
///
/// Motion is deliberately small (default scale 1.015, ~180ms): the goal is
/// "selectable and alive", not movement for its own sake.
///
/// A tappable [HoverLift] is a real stop in the focus order and announces
/// itself as a button, so the capacity cards it wraps — the primary way into
/// the product — are reachable without a mouse. Pass [semanticLabel] where the
/// child's own text doesn't already say what activating it does.
class HoverLift extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  /// Corner radius of the focus ring — match the child's own radius.
  final double focusRingRadius;
  final String? semanticLabel;

  const HoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.scale = 1.015,
    this.duration = const Duration(milliseconds: 180),
    this.focusRingRadius = 12,
    this.semanticLabel,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    // MergeSemantics collapses the FocusableActionDetector's focus node and the
    // button/label node into ONE control, so a screen reader announces "Karte,
    // button" rather than a focusable container wrapping a separate button.
    // Harmless when non-interactive — there's no focus node to merge, so the
    // child stays a plain (unfocusable, non-button) label.
    return MergeSemantics(
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        actions: _activateActions(widget.onTap),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: Semantics(
          button: interactive,
          enabled: interactive,
          label: widget.semanticLabel,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedScale(
              scale: _hovered ? widget.scale : 1.0,
              duration: widget.duration,
              curve: Curves.easeOut,
              child: _FocusRing(
                visible: _focused,
                radius: widget.focusRingRadius,
                child: widget.builder(context, _hovered),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tap target that feels responsive: hover raises confidence (the [builder]
/// can brighten), press compresses it slightly (scale 0.97) so the click reads
/// as physical. Wraps any visual — labelled button, icon button, action-bar
/// cell. Inspiration: Linear / Stripe / Framer.
///
/// Focusable and Enter/Space-activatable, and announced as a button: this
/// carries real actions (send interest, reveal contact), so it has to be usable
/// without a pointer. Give [semanticLabel] to icon-only variants, which
/// otherwise expose no text for a screen reader to read out.
class PressableButton extends StatefulWidget {
  final Widget Function(BuildContext context, bool hovered, bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  /// Corner radius of the focus ring — match the child's own radius.
  final double focusRingRadius;
  final String? semanticLabel;

  const PressableButton({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = 0.97,
    this.focusRingRadius = 8,
    this.semanticLabel,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    // See HoverLift: merge focus + button + label into one announced control.
    return MergeSemantics(
      child: FocusableActionDetector(
        enabled: interactive,
        mouseCursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        actions: _activateActions(widget.onTap),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: Semantics(
          button: interactive,
          enabled: interactive,
          label: widget.semanticLabel,
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
              child: _FocusRing(
                visible: _focused,
                radius: widget.focusRingRadius,
                child: widget.builder(context, _hovered, _pressed),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link that behaves like one: hover recolours it, and it is a real
/// focus stop announced as a button.
///
/// The landing page's nav and footer links were `MouseRegion` + bare
/// `GestureDetector` around a `Text` — invisible to keyboard traversal, which
/// left Impressum, Datenschutz and AGB unreachable without a mouse. Those are
/// exactly the links that have to be reachable.
///
/// [style] is called with `active: true` for hover AND for keyboard focus, so
/// a link a keyboard user has landed on looks the same as one under the
/// pointer; the underline beneath it is what distinguishes focus from hover.
class HoverTextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final TextStyle Function(BuildContext context, bool active) style;
  /// Transition duration for the style change. [Duration.zero] snaps.
  final Duration animate;
  /// Set for links that form a mutually exclusive set (the DE/EN pair), so the
  /// current one is announced as selected instead of looking identical to the
  /// other. Null for ordinary links.
  final bool? semanticsSelected;

  const HoverTextLink({
    super.key,
    required this.label,
    required this.onTap,
    required this.style,
    this.animate = Duration.zero,
    this.semanticsSelected,
  });

  @override
  State<HoverTextLink> createState() => _HoverTextLinkState();
}

class _HoverTextLinkState extends State<HoverTextLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final style = widget.style(context, _hovered || _focused);
    // See HoverLift: one merged control. The label comes from the Text child.
    return MergeSemantics(
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: _activateActions(widget.onTap),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: Semantics(
          button: true,
          selected: widget.semanticsSelected,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: DecoratedBox(
            // Always 2px, transparent when unfocused — a border that appears
            // only on focus would shift the whole nav row down by 2px as the
            // user tabs along it.
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _focused ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: widget.animate == Duration.zero
                ? Text(widget.label, style: style)
                : AnimatedDefaultTextStyle(
                    duration: widget.animate,
                    style: style,
                    child: Text(widget.label),
                  ),
            ),
          ),
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
