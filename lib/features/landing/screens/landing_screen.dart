import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/language_switcher.dart';
import '../../../shared/widgets/theme_switcher.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/register_screen.dart';
import '../../legal/screens/agb_screen.dart';
import '../../legal/screens/datenschutz_screen.dart';
import '../../legal/screens/impressum_screen.dart';
import '../../../shared/widgets/capacify_logo.dart';
import 'about_screen.dart';

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
            _StatsBar(isMobile: isMobile),
            _HowItWorksSection(isMobile: isMobile),
            _ActivitySection(isMobile: isMobile),
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
      padding: EdgeInsets.symmetric(horizontal: widget.isMobile ? 20 : 40),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _LogoBadge(size: 46, fontSize: 26),
          const SizedBox(width: 10),
          Text('Capacify', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.5)),
          const Spacer(),
          const LanguageSwitcher(compact: true),
          const SizedBox(width: 12),
          const ThemeSwitcher(),
          if (!widget.isMobile) ...[
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
          ] else
            const SizedBox(width: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoverLogin = true),
            onExit:  (_) => setState(() => _hoverLogin = false),
            child: GestureDetector(
              onTap: widget.onLogin,
              child: Text(l.navLogin, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _hoverLogin ? AppColors.primary : c.textSecondary)),
            ),
          ),
          const SizedBox(width: 16),
          _GradientBtn(label: widget.isMobile ? l.navStartFreeMobile : l.navStartFree, onTap: widget.onRegister, px: 18, py: 9, fs: 13),
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
      painter: _DotGrid(color: c.textPrimary),
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

class _DotGrid extends CustomPainter {
  final Color color;
  _DotGrid({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withOpacity(0.09);
    for (double x = 0; x < size.width; x += 28) {
      for (double y = 0; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 2.0, p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _DotGrid o) => o.color != color;
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
                  style: GoogleFonts.archivo(fontSize: 66, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.07, letterSpacing: -0.5),
                  children: [
                    TextSpan(text: l.heroTitle),
                    TextSpan(text: l.heroHighlight, style: const TextStyle(color: AppColors.primary)),
                    const TextSpan(text: '?'),
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
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: c.textTertiary),
                  const SizedBox(width: 5),
                  Text(l.heroStatLocation, style: TextStyle(fontSize: 12, color: c.textTertiary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 20),
                  Icon(Icons.construction_outlined, size: 14, color: c.textTertiary),
                  const SizedBox(width: 5),
                  Text(l.heroStatTrades, style: TextStyle(fontSize: 12, color: c.textTertiary, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 64),
        Expanded(flex: 62, child: _CardGrid()),
      ],
    );
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
            style: GoogleFonts.archivo(fontSize: 40, fontWeight: FontWeight.w900, color: c.textPrimary, height: 1.1, letterSpacing: -0.3),
            children: [
              TextSpan(text: l.heroTitle),
              TextSpan(text: l.heroHighlight, style: const TextStyle(color: AppColors.primary)),
              const TextSpan(text: '?'),
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
      _CardData(offer: false, title: l.card4Title, trade: 'Sanitär & Heizung', loc: 'Bergedorf',     avail: l.card4Avail, n: 4, live: false, ago: l.ago(31)),
    ];
    if (mobile) {
      return Column(children: [_Card(d: cards[0]), const SizedBox(height: 12), _Card(d: cards[1])]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [_Card(d: cards[0]), const SizedBox(height: 16), _Card(d: cards[2])])),
        const SizedBox(width: 14),
        Expanded(child: Column(children: [_Card(d: cards[1]), const SizedBox(height: 16), _Card(d: cards[3])])),
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

// ─── STATS BAR ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final bool isMobile;
  const _StatsBar({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 24 : 32),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        border: Border.symmetric(horizontal: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isMobile
              ? Column(children: [
                  Row(children: [Expanded(child: _Stat('120+', l.stat1Label, AppColors.primary)), Expanded(child: _Stat('31', l.stat2Label, AppColors.offerColor))]),
                  Row(children: [Expanded(child: _Stat('14', l.stat3Label, AppColors.needColor)), Expanded(child: _Stat('< 2h', l.stat4Label, AppColors.accent))]),
                ])
              : Row(children: [
                  Expanded(child: _Stat('120+', l.stat1Label, AppColors.primary)),
                  Expanded(child: _Stat('31',   l.stat2Label, AppColors.offerColor)),
                  Expanded(child: _Stat('14',   l.stat3Label, AppColors.needColor)),
                  Expanded(child: _Stat('< 2h', l.stat4Label, AppColors.accent)),
                ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: color, height: 1.0, letterSpacing: -1.5)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── HOW IT WORKS ─────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  final bool isMobile;
  const _HowItWorksSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 36 : 52),
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
              isMobile
                  ? Column(children: [
                      _Step(n: 1, title: l.step1Title, desc: l.step1Desc, icon: Icons.flash_on_outlined),
                      const SizedBox(height: 14),
                      _Step(n: 2, title: l.step2Title, desc: l.step2Desc, icon: Icons.search_outlined),
                      const SizedBox(height: 14),
                      _Step(n: 3, title: l.step3Title, desc: l.step3Desc, icon: Icons.phone_outlined),
                    ])
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _Step(n: 1, title: l.step1Title, desc: l.step1Desc, icon: Icons.flash_on_outlined)),
                          Padding(padding: const EdgeInsets.only(top: 28), child: Row(children: [Container(width: 32, height: 1, color: AppColors.primary.withOpacity(0.25)), Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary.withOpacity(0.4))])),
                          Expanded(child: _Step(n: 2, title: l.step2Title, desc: l.step2Desc, icon: Icons.search_outlined)),
                          Padding(padding: const EdgeInsets.only(top: 28), child: Row(children: [Container(width: 32, height: 1, color: AppColors.primary.withOpacity(0.25)), Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary.withOpacity(0.4))])),
                          Expanded(child: _Step(n: 3, title: l.step3Title, desc: l.step3Desc, icon: Icons.phone_outlined)),
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

class _Step extends StatelessWidget {
  final int n;
  final String title, desc;
  final IconData icon;
  const _Step({required this.n, required this.title, required this.desc, required this.icon});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFCC5500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.30), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
              ),
              const Spacer(),
              Icon(icon, size: 20, color: c.textTertiary),
            ],
          ),
          const SizedBox(height: 18),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          Text(desc, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.55)),
        ],
      ),
    );
  }
}

// ─── ACTIVITY ─────────────────────────────────────────────────────────────────

class _ActivitySection extends StatelessWidget {
  final bool isMobile;
  const _ActivitySection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l = AppLocalizations.of(context);
    final items = [
      _ActivityData(emoji: '⚡', text: l.activity1, time: l.ago(4),  offer: true,  loc: 'Hamburg-Mitte'),
      _ActivityData(emoji: '🏗️', text: l.activity2, time: l.ago(12), offer: false, loc: 'Hamburg-Nord'),
      _ActivityData(emoji: '🪛', text: l.activity3, time: l.ago(28), offer: true,  loc: 'Altona'),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 36 : 46),
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
              Row(
                children: [
                  Text(l.activityTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.8)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.live.withOpacity(0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.live.withOpacity(0.25))),
                    child: Text(l.liveLabel, style: const TextStyle(color: AppColors.live, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l.activitySubtitle, style: TextStyle(fontSize: 14, color: c.textSecondary)),
              const SizedBox(height: 28),
              isMobile
                  ? Column(children: [
                      _ActivityCard(d: items[0]), const SizedBox(height: 12),
                      _ActivityCard(d: items[1]), const SizedBox(height: 12),
                      _ActivityCard(d: items[2]),
                    ])
                  : Row(children: [
                      Expanded(child: _ActivityCard(d: items[0])), const SizedBox(width: 14),
                      Expanded(child: _ActivityCard(d: items[1])), const SizedBox(width: 14),
                      Expanded(child: _ActivityCard(d: items[2])),
                    ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityData {
  final String emoji, text, time, loc;
  final bool offer;
  const _ActivityData({required this.emoji, required this.text, required this.time, required this.offer, required this.loc});
}

class _ActivityCard extends StatefulWidget {
  final _ActivityData d;
  const _ActivityCard({required this.d});
  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
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
        decoration: BoxDecoration(
          color: _h ? c.surface : c.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(_h ? 0.30 : 0.14)),
          boxShadow: _h ? [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(widget.d.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(widget.d.text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: accent.withOpacity(0.10), borderRadius: BorderRadius.circular(4)), child: Text(widget.d.offer ? l.availableLabel : l.wantedLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent, letterSpacing: 0.4))),
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined, size: 13, color: c.textTertiary), const SizedBox(width: 2),
                          Text(widget.d.loc, style: TextStyle(fontSize: 13, color: c.textTertiary)),
                          const Spacer(),
                          Text(widget.d.time, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      _FactCard(icon: Icons.construction_outlined, value: '11', label: l.networkFactTrades),
      _FactCard(icon: Icons.bolt_outlined, value: l.networkFactLiveValue, label: l.networkFactLive, pulse: true),
    ];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 36 : 52),
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
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 36 : 52),
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
                      _TrustCard(icon: Icons.schedule_outlined,  title: l.trust3Title, desc: l.trust3Desc, color: AppColors.primary),
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
                          Expanded(child: _TrustCard(icon: Icons.schedule_outlined, title: l.trust3Title, desc: l.trust3Desc, color: AppColors.primary)),
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40, vertical: isMobile ? 48 : 64),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1020),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primary.withOpacity(0.07), const Color(0xFF0D1020)]),
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

class _FLink extends StatefulWidget {
  final String label;
  final Widget page;
  const _FLink({required this.label, required this.page});
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
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => widget.page)),
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
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
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
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.px, vertical: widget.py),
              child: Center(child: Text(widget.label, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: widget.fs, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
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
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
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
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.px, vertical: widget.py),
              child: Center(child: Text(widget.label, textAlign: TextAlign.center, style: TextStyle(color: AppColors.primary, fontSize: widget.fs, fontWeight: FontWeight.w700, letterSpacing: 0.3))),
            ),
          ),
        ),
      ),
    );
  }
}
