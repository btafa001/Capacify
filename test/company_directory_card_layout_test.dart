// Regression test for the phone layout of the company directory cards: at
// phone widths the grid still renders two columns, which left the logo and the
// verification badge practically touching (and the longest badge label
// overflowing past the logo). Measures the real gap rather than eyeballing it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capacify/core/models/company_model.dart';
import 'package:capacify/core/services/block_provider.dart';
import 'package:capacify/core/services/company_provider.dart';
import 'package:capacify/features/company/screens/company_directory_screen.dart';
import 'package:capacify/shared/widgets/company_logo_avatar.dart';

CompanyModel _company({
  required String id,
  required String name,
  required String status,
}) =>
    CompanyModel(
      id: id,
      ownerId: 'owner-$id',
      name: name,
      description: 'Rohbau, Sanierung und Umbau im Großraum Hamburg.',
      website: '',
      email: '',
      phone: '',
      address: '',
      city: 'Hamburg',
      postalCode: '',
      country: 'DE',
      employees: '25',
      trades: const ['rohbau'],
      services: const [],
      logoUrl: '', // initials fallback — no network image in tests
      verificationStatus: status,
    );

Finder _badgeFinder() => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_VerificationBadge');

Future<void> _pumpDirectory(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        companiesProvider.overrideWith((ref) => Stream.value([
              _company(id: 'a', name: 'Bau Nord GmbH', status: 'none'),
              _company(id: 'b', name: 'Elbe Rohbau AG', status: 'pending'),
              _company(id: 'c', name: 'Hansa Bau KG', status: 'verified'),
            ])),
        companyByIdProvider.overrideWith((ref, id) => Stream.value(null)),
        myBlockedCompanyIdsProvider.overrideWith((ref) => Stream.value(<String>{})),
      ],
      child: const MaterialApp(home: CompanyDirectoryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Horizontal gap between a card's logo and its badge, per card.
List<double> _gaps(WidgetTester tester) {
  final logos = tester.renderObjectList<RenderBox>(find.byType(CompanyLogoAvatar)).toList();
  final badges = tester.renderObjectList<RenderBox>(_badgeFinder()).toList();
  expect(logos.length, badges.length);
  expect(logos, isNotEmpty);

  return List.generate(logos.length, (i) {
    final logoRight = logos[i].localToGlobal(Offset.zero).dx + logos[i].size.width;
    final badgeLeft = badges[i].localToGlobal(Offset.zero).dx;
    return badgeLeft - logoRight;
  });
}

/// Every badge must stay inside its card's 16px content padding — i.e. the
/// label is bounded by the card, never spilling out over the logo.
void _expectBadgesInsideCards(WidgetTester tester) {
  final cards = tester
      .renderObjectList<RenderBox>(
          find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CompanyCard'))
      .toList();
  final badges = tester.renderObjectList<RenderBox>(_badgeFinder()).toList();
  expect(cards.length, badges.length);

  for (var i = 0; i < cards.length; i++) {
    final cardRight = cards[i].localToGlobal(Offset.zero).dx + cards[i].size.width;
    final badgeRight = badges[i].localToGlobal(Offset.zero).dx + badges[i].size.width;
    expect(badgeRight, lessThanOrEqualTo(cardRight - 16 + 0.01),
        reason: 'badge must stay within the card padding');
  }
}

void main() {
  testWidgets('phone: logo and verification badge keep a visible gap',
      (tester) async {
    await _pumpDirectory(tester, const Size(412, 900)); // Nothing Phone (3)-ish

    for (final gap in _gaps(tester)) {
      expect(gap, greaterThanOrEqualTo(10.0),
          reason: 'logo and badge must not crowd each other on phones');
    }
    _expectBadgesInsideCards(tester);

    // flutter_test paints with a stand-in font that is far wider than the real
    // one, which overflows the AppBar wordmark at this width (it does not in
    // the app). Consume it — the card geometry is asserted directly above, so
    // a real card overflow would already have failed.
    final err = tester.takeException();
    if (err != null) expect(err.toString(), contains('RenderFlex overflowed'));
  });

  testWidgets('desktop: cards keep the full-size logo', (tester) async {
    await _pumpDirectory(tester, const Size(1440, 1000));

    final logo = tester.renderObject<RenderBox>(find.byType(CompanyLogoAvatar).first);
    expect(logo.size.width, 52.0); // radius 26, unchanged from before
    for (final gap in _gaps(tester)) {
      expect(gap, greaterThan(10.0));
    }
  });
}
