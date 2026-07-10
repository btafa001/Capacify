import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/capacity_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../shared/widgets/theme_switcher.dart';
import '../../../shared/widgets/dot_grid_painter.dart';
import '../../../shared/widgets/interactions.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';
import '../../legal/screens/impressum_screen.dart';
import '../../../shared/widgets/capacify_logo.dart';
import 'about_screen.dart';
import '../../../core/services/analytics_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreenView('Landing');
    _pulse = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toLogin()    => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  void _toRegister() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
  void _toAbout()    => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavBar(isMobile: isMobile, onLogin: _toLogin, onRegister: _toRegister, onAbout: _toAbout),
            _HeroSection(isMobile: isMobile, pulse: _pulse, onLogin: _toLogin, onRegister: _toRegister),
            _UnlockShowcaseSection(isMobile: isMobile),
            _ForWhoSection(isMobile: isMobile),
            _HowItWorksLiveSection(isMobile: isMobile),
            _NetworkSection(isMobile: isMobile),
            _TrustSection(isMobile: isMobile),
            _FinalCTASection(isMobile: isMobile, onLogin: _toLogin, onRegister: _toRegister),
            _FooterSection(isMobile: isMobile),
          ],
        ),
      ),
    );
  }
}

// ─── NAV BAR ──────────────────────────────────────────────────────────────────

class _NavBar extends StatefulWidget {
  final bool isMobile;
  final VoidCallback onLogin, onRegister, onAbout;
  const _NavBar({required this.isMobile, required this.onLogin, required this.onRegister, required this.onAbout});
  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> {
  bool _hoverLogin = false;
  bool _hoverAbout = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 16 : 40),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _LogoBadge(size: widget.isMobile ? 32 : 46, fontSize: 26),
          SizedBox(width: widget.isMobile ? 8 : 10),
          Text(
            'Capacify',
            style: TextStyle(
              fontSize: widget.isMobile ? 17 : 22,
              fontWeight: FontWeight.w900,
              color: c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (widget.isMobile) ...[
            const LanguageSwitcher(iconOnly: true),
            const SizedBox(width: 8),
            const ThemeSwitcher(iconOnly: true),
            const SizedBox(width: 8),
          ] else ...[
            const LanguageSwitcher(compact: true),
            const SizedBox(width: 12),
            const ThemeSwitcher(),
            const SizedBox(width: 24),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoverAbout = true),
              onExit:  (_) => setState(() => _hoverAbout = false),
              child: GestureDetector(
                onTap: widget.onAbout,
                child: Text(l.navAbout, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _hoverAbout ? AppColors.primary : c.textSecondary)),
              ),
            ),
            const SizedBox(width: 32),
          ],
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoverLogin = true),
            onExit:  (_) => setState(() => _hoverLogin = false),
            child: GestureDetector(
              onTap: widget.onLogin,
              child: Text(l.navLogin, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _hoverLogin ? AppColors.primary : c.textSecondary)),
            ),
          ),
          SizedBox(width: widget.isMobile ? 10 : 16),
          _GradientBtn(
            label: widget.isMobile ? l.navStartFreeMobile : l.navStartFree,
            onTap: widget.onRegister,
            px: widget.isMobile ? 14 : 18,
            py: 9,
            fs: 13,
          ),
        ],
      ),
    );
  }
}

// ─── HERO ─────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final bool isMobile;
  final AnimationController pulse;
  final VoidCallback onLogin, onRegister;
  const _HeroSection({required this.isMobile, required this.pulse, required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CustomPaint(
      painter: DotGridPainter(color: c.textPrimary),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 36 : 56),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [AppColors.primary.withOpacity(0.06), Colors.transparent]),
          border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isMobile
                ? _MobileHero(pulse: pulse, onLogin: onLogin, onRegister: onRegister)
                : _DesktopHero(pulse: pulse, onLogin: onLogin, onRegister: onRegister),
          ),
        ),
      ),
    );
  }
}

class _DesktopHero extends StatelessWidget {
  final AnimationController pulse;
  final VoidCallback onLogin, onRegister;
  const _DesktopHero({required this.pulse, required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 38,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LiveBadge(pulse: pulse),
              const SizedBox(height: 28),
              RichText(
                text: TextSpan(
                  // Tighter tracking (matches the loading-splash wordmark) for a
                  // punchier display feel; the trailing "?" picks up the orange
                  // accent, echoing the splash's orange dot.
                  style: GoogleFonts.archivo(fontSize: 66, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.05, letterSpacing: -1.8),
                  children: [
                    TextSpan(text: l.heroTitle),
                    TextSpan(text: l.heroHighlight, style: const TextStyle(color: AppColors.primary)),
                    const TextSpan(text: '?', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(l.heroSubtitle, style: TextStyle(fontSize: 18, color: c.textSecondary, height: 1.6)),
              const SizedBox(height: 36),
              Row(
                children: [
                  _GradientBtn(label: l.heroCtaRegister, onTap: onRegister, px: 28, py: 15, fs: 15),
                  const SizedBox(width: 14),
                  _OutlineBtn(label: l.navLogin, onTap: onLogin, px: 28, py: 15, fs: 15),
                ],
              ),
              const SizedBox(height: 28),
              const _MarketPulseRow(),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(flex: 62, child: _CardGrid()),
      ],
    );
  }
}

/// Real "proof of life" — live company + capacity counts (never fabricated).
/// Falls back to the static location/trades line while loading or if both are
/// zero, so an empty market never advertises "0 Firmen".
class _MarketPulseRow extends ConsumerWidget {
  const _MarketPulseRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final pulse = ref.watch(marketPulseProvider).valueOrNull;
    final hasData = pulse != null && (pulse.companies > 0 || pulse.activeCapacities > 0);

    if (!hasData) {
      return Row(children: [
        Icon(Icons.location_on_outlined, size: 14, color: c.textTertiary),
        const SizedBox(width: 5),
        Text(l.heroStatLocation, style: TextStyle(fontSize: 12, color: c.textTertiary, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Icon(Icons.construction_outlined, size: 14, color: c.textTertiary),
        const SizedBox(width: 5),
        Text(l.heroStatTrades(kSelectableTradeCount), style: TextStyle(fontSize: 12, color: c.textTertiary, fontWeight: FontWeight.w500)),
      ]);
    }
    return Wrap(spacing: 18, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Text(l.pulseActiveCapacities(pulse.activeCapacities),
            style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w800)),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.apartment_outlined, size: 14, color: c.textSecondary),
        const SizedBox(width: 5),
        Text(l.pulseCompanies(pulse.companies),
            style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w600)),
      ]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_on_outlined, size: 14, color: c.textTertiary),
        const SizedBox(width: 4),
        Text(kServiceRegion, style: TextStyle(fontSize: 13, color: c.textTertiary, fontWeight: FontWeight.w500)),
      ]),
    ]);
  }
}

class _MobileHero extends StatelessWidget {
  final AnimationController pulse;
  final VoidCallback onLogin, onRegister;
  const _MobileHero({required this.pulse, required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LiveBadge(pulse: pulse),
        const SizedBox(height: 22),
        RichText(
          text: TextSpan(
            style: GoogleFonts.archivo(fontSize: 40, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.08, letterSpacing: -1.1),
            children: [
              TextSpan(text: l.heroTitle),
              TextSpan(text: l.heroHighlight, style: const TextStyle(color: AppColors.primary)),
              const TextSpan(text: '?', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l.heroSubtitleMobile, style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.6)),
        const SizedBox(height: 28),
        _GradientBtn(label: l.heroCtaRegister, onTap: onRegister, px: 24, py: 15, fs: 15, full: true),
        const SizedBox(height: 10),
        _OutlineBtn(label: l.navLogin, onTap: onLogin, px: 24, py: 15, fs: 15, full: true),
        const SizedBox(height: 32),
        _CardGrid(mobile: true),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final AnimationController pulse;
  const _LiveBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final p = math.sin(pulse.value * math.pi * 2);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.live.withOpacity(0.08 + 0.04 * p),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.live.withOpacity(0.25 + 0.12 * p)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppColors.live, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.live.withOpacity(0.6), blurRadius: 6, spreadRadius: 1)],
                ),
              ),
              const SizedBox(width: 8),
              Text(l.heroLiveBadge, style: const TextStyle(color: AppColors.live, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
            ],
          ),
        );
      },
    );
  }
}

// ─── PREVIEW CARDS ────────────────────────────────────────────────────────────

class _CardGrid extends StatelessWidget {
  final bool mobile;
  const _CardGrid({this.mobile = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = [
      _CardData(offer: true,  title: l.card1Title, trade: 'Elektro',          loc: 'Hamburg-Mitte', avail: l.card1Avail, n: 3, live: true,  ago: l.ago(4),  verified: true),
      _CardData(offer: false, title: l.card2Title, trade: 'Dach',              loc: 'Hamburg-Nord',  avail: l.card2Avail, n: 2, live: false, ago: l.ago(12)),
      _CardData(offer: true,  title: l.card3Title, trade: 'Trockenbau',        loc: 'Eimsbüttel',    avail: l.card3Avail, n: 5, live: true,  ago: l.ago(18)),
      _CardData(offer: false, title: l.card4Title, trade: 'SHK', loc: 'Bergedorf',     avail: l.card4Avail, n: 4, live: false, ago: l.ago(31)),
    ];
    // Cascade the cards in on load — the hero "feed" populating itself. Subtle
    // stagger (~90ms apart), one-shot; premium load-in, not a gimmick.
    Widget staggered(int i, _CardData d) =>
        EntryFade(delay: Duration(milliseconds: i * 90), child: _Card(d: d));
    if (mobile) {
      return Column(children: [staggered(0, cards[0]), const SizedBox(height: 12), staggered(1, cards[1])]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [staggered(0, cards[0]), const SizedBox(height: 16), staggered(2, cards[2])])),
        const SizedBox(width: 14),
        Expanded(child: Column(children: [staggered(1, cards[1]), const SizedBox(height: 16), staggered(3, cards[3])])),
      ],
    );
  }
}

class _CardData {
  final bool offer, live, verified;
  final String title, trade, loc, avail, ago;
  final int n;
  const _CardData({required this.offer, required this.title, required this.trade, required this.loc, required this.avail, required this.n, required this.live, required this.ago, this.verified = false});
}

class _Card extends StatefulWidget {
  final _CardData d;
  const _Card({required this.d});
  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final accent = widget.d.offer ? AppColors.offerColor : AppColors.needColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _h ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(_h ? 0.45 : 0.20), width: 1.5),
          boxShadow: [BoxShadow(color: accent.withOpacity(_h ? 0.14 : 0.04), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.only(topLeft: Radius.circular(11), topRight: Radius.circular(11)))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: accent.withOpacity(0.3))),
                        child: Text(widget.d.offer ? l.availableLabel : l.wantedLabel, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 6),
                      if (widget.d.live)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.live.withOpacity(0.10), borderRadius: BorderRadius.circular(4)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(l.liveLabel, style: const TextStyle(color: AppColors.live, fontSize: 10, fontWeight: FontWeight.w900)),
                          ]),
                        ),
                      if (widget.d.verified) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.live.withOpacity(0.10), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.live.withOpacity(0.30))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified, size: 10, color: AppColors.live),
                            const SizedBox(width: 3),
                            Text(l.verifiedLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.live, letterSpacing: 0.3)),
                          ]),
                        ),
                      ],
                      const Spacer(),
                      Icon(Icons.lock_outline, size: 14, color: c.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(widget.d.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(4)), child: Text(widget.d.trade, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 13, color: c.textTertiary), const SizedBox(width: 3),
                    Text(widget.d.loc, style: TextStyle(fontSize: 13, color: c.textTertiary)),
                    const Spacer(),
                    Icon(Icons.people_outline, size: 13, color: c.textTertiary), const SizedBox(width: 3),
                    Text('${widget.d.n} ${l.persPeriod}', style: TextStyle(fontSize: 13, color: c.textTertiary)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(0.08), borderRadius: BorderRadius.circular(4)), child: Text(widget.d.avail, style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w700))),
                    const Spacer(),
                    Text(widget.d.ago, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UNLOCK SHOWCASE (anonymous → Vermittlung → revealed) ──────────────────
//
// The signature graphic: an anonymized feed card on the left, a pulsing
// "1 Vermittlung" in the middle, and the same post revealed on the right. The
// revealed card blur-reveals on a loop (locked → spend → unlocked → back),
// which visualises the platform's core mechanic in one glance.

class _UnlockShowcaseSection extends StatefulWidget {
  final bool isMobile;
  const _UnlockShowcaseSection({required this.isMobile});
  @override
  State<_UnlockShowcaseSection> createState() => _UnlockShowcaseSectionState();
}

class _UnlockShowcaseSectionState extends State<_UnlockShowcaseSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 4200), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // 0 = fully hidden, 1 = fully revealed. Locked → unlock ramp → hold → fade back.
  double _reveal(double t) {
    if (t < 0.35) return 0;
    if (t < 0.5) return (t - 0.35) / 0.15;
    if (t < 0.9) return 1;
    return 1 - (t - 0.9) / 0.1;
  }


  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 20 : 40, vertical: widget.isMobile ? 36 : 56),
      // Matches the Hero section directly above it — every other section on
      // the page alternates background/surfaceVariant; this one was the only
      // outlier using `surface`, which read as a different visual language.
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Text(l.unlockShowcaseTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: widget.isMobile ? 24 : 32,
                      fontWeight: FontWeight.w900,
                      color: c.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.15)),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(l.unlockShowcaseSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.5)),
              ),
              const SizedBox(height: 34),
              AnimatedBuilder(
                animation: _ctrl,
                builder: (ctx, _) {
                  final reveal = _reveal(_ctrl.value);
                  if (widget.isMobile) {
                    return Column(children: [
                      _anonCard(),
                      const SizedBox(height: 10),
                      _connector(false),
                      const SizedBox(height: 10),
                      _revealCard(reveal),
                    ]);
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _anonCard()),
                        SizedBox(width: 132, child: _connector(true)),
                        Expanded(child: _revealCard(reveal)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child, Color? border, double borderWidth = 1}) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border ?? c.border, width: borderWidth),
      ),
      child: child,
    );
  }

  Widget _pill(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _anonCard() {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _pill(l.offerLabel, AppColors.offerColor, Icons.trending_up),
            const Spacer(),
            _pill(l.showcaseAnonBadge, c.textTertiary, Icons.lock_outline),
          ]),
          const SizedBox(height: 14),
          Text(l.showcaseDemoTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.2)),
          const SizedBox(height: 4),
          Text('5 ${l.persons} · Hamburg-Harburg',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
          const SizedBox(height: 14),
          _hiddenLine(Icons.business_outlined, l.showcaseHiddenName),
          const SizedBox(height: 8),
          _hiddenLine(Icons.phone_outlined, '••• ••• ••••'),
        ],
      ),
    );
  }

  Widget _hiddenLine(IconData icon, String label) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 15, color: c.textTertiary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 13, color: c.textTertiary)),
      ]),
    );
  }

  // The connector is a DIAGRAM node, not a real button — it visualises the
  // "one message turns anonymous into connected" hop. A single clean circular
  // send-node reads far better than text crammed into a narrow pill (which
  // fought its 132px slot); the label lives below as a caption, and a subtle
  // directional arrow shows the flow (→ desktop, ↓ mobile). Static on purpose:
  // the section already animates the reveal blur + badge crossfade, so a
  // pulsing button on top made it feel busy — "premium restraint."
  Widget _connector(bool horizontal) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.80),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.38),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.send_rounded, size: 21, color: Colors.white),
        ),
        const SizedBox(height: 11),
        Text(
          AppLocalizations.of(context).showcaseVermittlungPill,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
            height: 1.25,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 11),
        Icon(horizontal ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
            size: 20, color: AppColors.primary.withOpacity(0.45)),
      ],
    );
  }

  Widget _revealCard(double reveal) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final borderColor = Color.lerp(c.border, AppColors.live, reveal)!;
    final sigma = (1 - reveal) * 7;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Spacer(),
          // Badge crossfades hidden → unlocked.
          Stack(children: [
            Opacity(opacity: (1 - reveal).clamp(0, 1), child: _pill(l.showcaseAnonBadge, c.textTertiary, Icons.lock_outline)),
            Opacity(opacity: reveal.clamp(0, 1), child: _pill(l.showcaseUnlockedBadge, AppColors.live, Icons.lock_open_outlined)),
          ]),
        ]),
        const SizedBox(height: 14),
        Text('Müller Dach GmbH',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.star, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(l.showcaseDemoRating,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
        ]),
        const SizedBox(height: 14),
        _contactLine(Icons.phone_outlined, '+49 40 55 51 72'),
        const SizedBox(height: 8),
        _contactLine(Icons.mail_outline, 'kontakt@mueller-dach.de'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.forum_outlined, size: 16, color: Colors.white),
            const SizedBox(width: 7),
            Text(l.sendMessageButton, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ]),
        ),
      ],
    );
    // Blur the sensitive content while locked.
    final blurred = sigma < 0.2
        ? content
        : ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma), child: content);
    // Constant border WIDTH (only the color animates) — a Container's border
    // adds to its own layout size, so animating the width made the card
    // physically grow/shrink each frame ("right card window" resizing).
    return _cardShell(border: borderColor, borderWidth: 1.5, child: blurred);
  }

  Widget _contactLine(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(color: AppColors.live.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 15, color: AppColors.live),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.live, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ─── HOW IT WORKS (live mockups) ───────────────────────────────────────────
//
// Small animated mockups of the real screens (post form, live feed, contact)
// per step, instead of a plain icon.

class _HowItWorksLiveSection extends StatefulWidget {
  final bool isMobile;
  const _HowItWorksLiveSection({required this.isMobile});
  @override
  State<_HowItWorksLiveSection> createState() => _HowItWorksLiveSectionState();
}

class _HowItWorksLiveSectionState extends State<_HowItWorksLiveSection> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 2400), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final steps = [
      _LiveStep(n: 1, title: l.step1Title, desc: l.step1Desc, mockup: _MockupPost(ctrl: _ctrl)),
      _LiveStep(n: 2, title: l.step2Title, desc: l.step2Desc, mockup: _MockupFeed(ctrl: _ctrl)),
      _LiveStep(n: 3, title: l.step3Title, desc: l.step3Desc, mockup: _MockupContact(ctrl: _ctrl)),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 20 : 40, vertical: widget.isMobile ? 32 : 44),
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.howTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 6),
              Text(l.howSubtitle, style: TextStyle(fontSize: 15, color: c.textSecondary)),
              const SizedBox(height: 40),
              widget.isMobile
                  ? Column(children: [
                      steps[0],
                      const SizedBox(height: 14),
                      steps[1],
                      const SizedBox(height: 14),
                      steps[2],
                    ])
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: steps[0]),
                          Padding(padding: const EdgeInsets.only(top: 184), child: Row(children: [Container(width: 32, height: 1, color: AppColors.primary.withOpacity(0.25)), Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary.withOpacity(0.4))])),
                          Expanded(child: steps[1]),
                          Padding(padding: const EdgeInsets.only(top: 184), child: Row(children: [Container(width: 32, height: 1, color: AppColors.primary.withOpacity(0.25)), Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary.withOpacity(0.4))])),
                          Expanded(child: steps[2]),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveStep extends StatelessWidget {
  final int n;
  final String title, desc;
  final Widget mockup;
  const _LiveStep({required this.n, required this.title, required this.desc, required this.mockup});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: mockup),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFCC5500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3))),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.55)),
        ],
      ),
    );
  }
}

// Smooth 0..1 oscillation derived from a continuously-repeating controller
// (same trick as _LiveBadge uses), driving the small "breathing" pulse on
// whichever element should look alive in each mockup below.
double _wave(AnimationController ctrl) => math.sin(ctrl.value * math.pi * 2) * 0.5 + 0.5;

class _MockupFrame extends StatelessWidget {
  final Widget child;
  const _MockupFrame({required this.child});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 136,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _MockupPost extends StatelessWidget {
  final AnimationController ctrl;
  const _MockupPost({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _MockupFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neue Kapazität', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textTertiary, letterSpacing: 0.3)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt, size: 11, color: AppColors.primary),
              const SizedBox(width: 4),
              const Text('Elektro', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.people_outline, size: 13, color: c.textTertiary),
            const SizedBox(width: 5),
            Text('3 Mitarbeiter · Ab sofort', style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ]),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                final wave = _wave(ctrl);
                return Transform.scale(
                  scale: 0.92 + wave * 0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFCC5500)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3 + wave * 0.2), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: const Text('Veröffentlichen', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MockupFeed extends StatelessWidget {
  final AnimationController ctrl;
  const _MockupFeed({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _MockupFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const _PulseDot(),
            const SizedBox(width: 6),
            Text(l.liveLabel, style: const TextStyle(color: AppColors.live, fontSize: 10, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          _MiniFeedRow(label: l.wantedLabel, trade: 'Dachdecker', loc: 'Hamburg-Nord', color: AppColors.needColor),
          const SizedBox(height: 6),
          _MiniFeedRow(label: l.availableLabel, trade: 'Trockenbau', loc: 'Eimsbüttel', color: AppColors.offerColor),
        ],
      ),
    );
  }
}

class _MiniFeedRow extends StatelessWidget {
  final String label, trade, loc;
  final Color color;
  const _MiniFeedRow({required this.label, required this.trade, required this.loc, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(children: [
        Expanded(child: Text(trade, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        Text(loc, style: TextStyle(fontSize: 10, color: c.textTertiary)),
      ]),
    );
  }
}

class _MockupContact extends StatelessWidget {
  final AnimationController ctrl;
  const _MockupContact({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _MockupFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle),
              child: const Center(child: Icon(Icons.business, size: 13, color: AppColors.primary)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('Elektro Schmidt GmbH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.mail_outline, size: 13, color: c.textTertiary),
            const SizedBox(width: 6),
            Expanded(child: Text('kontakt@schmidt-elektro.de', style: TextStyle(fontSize: 10.5, color: c.textSecondary), overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                final wave = _wave(ctrl);
                return Transform.scale(
                  scale: 0.92 + wave * 0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.live.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.live.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.call, size: 12, color: AppColors.live),
                      const SizedBox(width: 5),
                      const Text('Anrufen', style: TextStyle(color: AppColors.live, fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ForWhoSection extends StatelessWidget {
  final bool isMobile;
  const _ForWhoSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final offerCard = _ForWhoCard(
      tag: l.forWhoOfferTag,
      title: l.forWhoOfferTitle,
      desc: l.forWhoOfferDesc,
      points: [l.forWhoOfferPoint1, l.forWhoOfferPoint2],
      color: AppColors.offerColor,
      icon: Icons.inventory_2_outlined,
    );
    final needCard = _ForWhoCard(
      tag: l.forWhoNeedTag,
      title: l.forWhoNeedTitle,
      desc: l.forWhoNeedDesc,
      points: [l.forWhoNeedPoint1, l.forWhoNeedPoint2],
      color: AppColors.needColor,
      icon: Icons.travel_explore_outlined,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 32 : 44),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border.symmetric(horizontal: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.forWhoTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 6),
              Text(l.forWhoSubtitle, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 28),
              isMobile
                  ? Column(children: [
                      offerCard,
                      const SizedBox(height: 12),
                      Center(child: _MatchConnector()),
                      const SizedBox(height: 12),
                      needCard,
                    ])
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: offerCard),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Center(child: _MatchConnector())),
                          Expanded(child: needCard),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)),
      child: Icon(Icons.swap_horiz, size: 18, color: c.textTertiary),
    );
  }
}

class _ForWhoCard extends StatefulWidget {
  final String tag, title, desc;
  final List<String> points;
  final Color color;
  final IconData icon;
  const _ForWhoCard({required this.tag, required this.title, required this.desc, required this.points, required this.color, required this.icon});
  @override
  State<_ForWhoCard> createState() => _ForWhoCardState();
}

class _ForWhoCardState extends State<_ForWhoCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _h ? c.surface : c.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.color.withOpacity(_h ? 0.35 : 0.18), width: 1.5),
          boxShadow: _h ? [BoxShadow(color: widget.color.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: widget.color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(widget.icon, size: 20, color: widget.color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(widget.tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: widget.color, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(widget.desc, style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5)),
            const SizedBox(height: 16),
            ...widget.points.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 14, color: widget.color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p, style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── NETWORK ──────────────────────────────────────────────────────────────────
//
// Honest coverage facts, not fabricated multi-city activity — the product
// only operates in Hamburg today, so these are facts about what's actually
// built (district coverage, trade coverage, real-time architecture) rather
// than invented usage numbers.

class _NetworkSection extends StatelessWidget {
  final bool isMobile;
  const _NetworkSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final facts = [
      _FactCard(icon: Icons.location_on_outlined, value: '15', label: l.networkFactDistricts),
      _FactCard(icon: Icons.construction_outlined, value: '$kSelectableTradeCount', label: l.networkFactTrades),
      _FactCard(icon: Icons.bolt_outlined, value: l.networkFactLiveValue, label: l.networkFactLive, pulse: true),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 32 : 44),
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.networkTitle,    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 6),
              Text(l.networkSubtitle, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 32),
              isMobile
                  ? Column(children: [
                      facts[0], const SizedBox(height: 12),
                      facts[1], const SizedBox(height: 12),
                      facts[2],
                    ])
                  : Row(children: [
                      Expanded(child: facts[0]), const SizedBox(width: 14),
                      Expanded(child: facts[1]), const SizedBox(width: 14),
                      Expanded(child: facts[2]),
                    ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactCard extends StatefulWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool pulse;
  const _FactCard({required this.icon, required this.value, required this.label, this.pulse = false});
  @override
  State<_FactCard> createState() => _FactCardState();
}

class _FactCardState extends State<_FactCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _h ? c.surface : c.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(_h ? 0.30 : 0.10)),
          boxShadow: _h ? [BoxShadow(color: AppColors.primary.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 16),
            Row(children: [
              Text(widget.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: -0.5)),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.textPrimary, letterSpacing: -0.5)),
              if (widget.pulse) ...[const SizedBox(width: 8), const _PulseDot()],
            ]),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final p = math.sin(_ctrl.value * math.pi * 2) * 0.5 + 0.5;
        return Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
            color: AppColors.live, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.live.withOpacity(0.35 + 0.45 * p), blurRadius: 4 + 10 * p, spreadRadius: 0.5 + 1.5 * p)],
          ),
        );
      },
    );
  }
}

// ─── TRUST ────────────────────────────────────────────────────────────────────

class _TrustSection extends StatelessWidget {
  final bool isMobile;
  const _TrustSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 32 : 44),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border.symmetric(horizontal: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.trustTitle,    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.8)),
              const SizedBox(height: 6),
              Text(l.trustSubtitle, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 32),
              isMobile
                  ? Column(children: [
                      _TrustCard(icon: Icons.verified_outlined,  title: l.trust1Title, desc: l.trust1Desc, color: AppColors.live),
                      const SizedBox(height: 12),
                      _TrustCard(icon: Icons.star_outline,       title: l.trust2Title, desc: l.trust2Desc, color: AppColors.accent),
                      const SizedBox(height: 12),
                      _TrustCard(icon: Icons.call_outlined,  title: l.trust3Title, desc: l.trust3Desc, color: AppColors.primary),
                      const SizedBox(height: 12),
                      _TrustCard(icon: Icons.security_outlined,  title: l.trust4Title, desc: l.trust4Desc, color: AppColors.distance),
                    ])
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _TrustCard(icon: Icons.verified_outlined, title: l.trust1Title, desc: l.trust1Desc, color: AppColors.live)),
                          const SizedBox(width: 14),
                          Expanded(child: _TrustCard(icon: Icons.star_outline,      title: l.trust2Title, desc: l.trust2Desc, color: AppColors.accent)),
                          const SizedBox(width: 14),
                          Expanded(child: _TrustCard(icon: Icons.call_outlined, title: l.trust3Title, desc: l.trust3Desc, color: AppColors.primary)),
                          const SizedBox(width: 14),
                          Expanded(child: _TrustCard(icon: Icons.security_outlined, title: l.trust4Title, desc: l.trust4Desc, color: AppColors.distance)),
                        ],
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _TrustCard({required this.icon, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 160),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 24, color: color)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary)),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── FINAL CTA ────────────────────────────────────────────────────────────────

class _FinalCTASection extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onLogin, onRegister;
  const _FinalCTASection({required this.isMobile, required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dark mode keeps its original treatment exactly (low-opacity orange
    // blending down into the dark base). Light mode gets its own distinct
    // 3-stop gradient — light, orange in the middle, back to light — rather
    // than borrowing dark mode's colors, since the rest of the page stays
    // light-themed around it.
    final gradient = isDark
        ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withOpacity(0.07), const Color(0xFF0D1020)])
        : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.background, AppColors.primary.withOpacity(0.45), c.background]);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 48 : 64),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1020),
        gradient: gradient,
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.25))),
                child: Text(l.ctaBadge, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
              ),
              const SizedBox(height: 24),
              Text(l.ctaTitle, style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -1.2, height: 1.1), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(l.ctaSubtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 14 : 16, color: c.textSecondary, height: 1.6)),
              const SizedBox(height: 40),
              isMobile
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _GradientBtn(label: l.heroCtaRegister, onTap: onRegister, px: 24, py: 16, fs: 16, full: true),
                      const SizedBox(height: 12),
                      _OutlineBtn(label: l.ctaAlreadyMember, onTap: onLogin, px: 24, py: 16, fs: 16, full: true),
                    ])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _GradientBtn(label: l.heroCtaRegister, onTap: onRegister, px: 36, py: 17, fs: 16),
                      const SizedBox(width: 14),
                      _OutlineBtn(label: l.navLogin, onTap: onLogin, px: 36, py: 17, fs: 16),
                    ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FOOTER ───────────────────────────────────────────────────────────────────

class _FooterSection extends StatelessWidget {
  final bool isMobile;
  const _FooterSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border, width: 0.5))),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isMobile
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _LogoBadge(size: 30, fontSize: 17, showText: true),
                        const SizedBox(height: 4),
                        Text(l.footerTagline, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 28, runSpacing: 6, children: [
                          _FLink(label: l.footerContact, onTap: _launchFooterContactEmail),
                          _FLink(label: l.footerAGB,     page: const AGBScreen()),
                          _FLink(label: l.footerPrivacy, page: const DatenschutzScreen()),
                          _FLink(label: l.footerImprint, page: const ImpressumScreen()),
                        ]),
                      ])
                    : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _LogoBadge(size: 30, fontSize: 17, showText: true),
                          const SizedBox(height: 4),
                          Text(l.footerTagline, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                        ]),
                        const Spacer(),
                        _FLink(label: l.footerContact, onTap: _launchFooterContactEmail), const SizedBox(width: 32),
                        _FLink(label: l.footerAGB,     page: const AGBScreen()),     const SizedBox(width: 32),
                        _FLink(label: l.footerPrivacy, page: const DatenschutzScreen()), const SizedBox(width: 32),
                        _FLink(label: l.footerImprint, page: const ImpressumScreen()),
                      ]),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: 10),
            decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.border, width: 0.5))),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(children: [
                  Expanded(child: Text(l.footerDisclaimer, style: TextStyle(fontSize: 11, color: c.textTertiary, height: 1.4))),
                  const SizedBox(width: 32),
                  Text('© 2026 Capacify', style: TextStyle(fontSize: 11, color: c.textTertiary)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _launchFooterContactEmail() async {
  final uri = Uri(scheme: 'mailto', path: 'info@capacify.de');
  try { await launchUrl(uri); } catch (_) {}
}

class _FLink extends StatefulWidget {
  final String label;
  final Widget? page;
  final VoidCallback? onTap;
  const _FLink({required this.label, this.page, this.onTap});
  @override
  State<_FLink> createState() => _FLinkState();
}

class _FLinkState extends State<_FLink> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap ??
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.page!)),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _h ? AppColors.primary : c.textSecondary),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// ─── SHARED PRIMITIVES ────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final double size, fontSize;
  final bool showText;
  const _LogoBadge({required this.size, required this.fontSize, this.showText = false});

  @override
  Widget build(BuildContext context) {
    if (showText) return CapacifyWordmark(symbolSize: size, fontSize: fontSize - 1, textColor: AppColors.of(context).textPrimary);
    return CapacifySymbol(size: size);
  }
}

class _GradientBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double px, py, fs;
  final bool full;
  const _GradientBtn({required this.label, required this.onTap, required this.px, required this.py, required this.fs, this.full = false});
  @override
  State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn> {
  bool _h = false;
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.full ? double.infinity : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, _h ? AppColors.primary : const Color(0xFFCC5500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(_h ? 0.40 : 0.22), blurRadius: _h ? 24 : 14, offset: const Offset(0, 4))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _p = v),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.px, vertical: widget.py),
                child: Center(child: Text(widget.label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: widget.fs, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double px, py, fs;
  final bool full;
  const _OutlineBtn({required this.label, required this.onTap, required this.px, required this.py, required this.fs, this.full = false});
  @override
  State<_OutlineBtn> createState() => _OutlineBtnState();
}

class _OutlineBtnState extends State<_OutlineBtn> {
  bool _h = false;
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.full ? double.infinity : null,
          decoration: BoxDecoration(
            color: _h ? AppColors.primary.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(_h ? 0.55 : 0.30), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _p = v),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.px, vertical: widget.py),
                child: Center(child: Text(widget.label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.primary, fontSize: widget.fs, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
