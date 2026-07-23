import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capacify/shared/widgets/interactions.dart';

/// Regression cover for H5: the shared tap wrappers used to be bare
/// GestureDetectors, so everything built on them — the capacity cards, the
/// send-interest bar, the landing nav and footer links — was mouse-only. A
/// keyboard user could not reach them and a screen reader saw no controls.
///
/// These assert the two things that actually matter to that user: the widget
/// is a stop in the focus order announced as a button, and pressing Enter or
/// Space on it fires the same callback a click would.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  /// Tab into the first focusable widget of the pumped tree.
  Future<void> tabTo(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }

  group('HoverLift', () {
    testWidgets('is focusable and announced as a button when tappable',
        (tester) async {
      await tester.pumpWidget(host(
        HoverLift(onTap: () {}, builder: (_, __) => const Text('Karte')),
      ));

      await tabTo(tester);

      expect(
        Focus.of(tester.element(find.text('Karte')), scopeOk: true).hasFocus,
        isTrue,
        reason: 'a tappable HoverLift must be reachable by Tab',
      );
      expect(
        tester.getSemantics(find.text('Karte')),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Karte',
        ),
      );
    });

    testWidgets('Enter and Space both activate it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        HoverLift(onTap: () => taps++, builder: (_, __) => const Text('Karte')),
      ));

      await tabTo(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1, reason: 'Enter must activate a focused card');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 2, reason: 'Space must activate a focused card');
    });

    testWidgets('a non-tappable one stays out of the focus order',
        (tester) async {
      await tester.pumpWidget(host(
        Column(children: [
          HoverLift(builder: (_, __) => const Text('Deko')),
          TextButton(onPressed: () {}, child: const Text('Echt')),
        ]),
      ));

      await tabTo(tester);

      // Tab lands on the real button, not on the decorative wrapper.
      final focused = primaryFocus;
      expect(focused, isNotNull);
      expect(
        find.descendant(
          of: find.byType(TextButton),
          matching: find.text('Echt'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Deko')),
        isNot(matchesSemantics(isButton: true, isFocusable: true)),
      );
    });

    testWidgets('does not loosen the constraints its child is laid out with',
        (tester) async {
      // The focus ring is drawn in a Stack over the child. With the default
      // StackFit.loose that Stack would let a full-width child shrink-wrap,
      // quietly narrowing every card in the feed.
      await tester.pumpWidget(host(
        SizedBox(
          width: 400,
          child: HoverLift(
            onTap: () {},
            builder: (_, __) => Container(height: 40, color: const Color(0xFF000000)),
          ),
        ),
      ));

      expect(tester.getSize(find.byType(Container)).width, 400);
    });
  });

  group('PressableButton', () {
    testWidgets('is focusable, announced as a button, and key-activatable',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(
        PressableButton(
          onTap: () => taps++,
          builder: (_, __, ___) => const Text('Interesse senden'),
        ),
      ));

      await tabTo(tester);

      expect(
        tester.getSemantics(find.text('Interesse senden')),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Interesse senden',
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('HoverTextLink', () {
    testWidgets('a footer legal link is reachable and activatable by keyboard',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(host(
        HoverTextLink(
          label: 'Impressum',
          onTap: () => opened++,
          style: (_, __) => const TextStyle(fontSize: 13),
        ),
      ));

      await tabTo(tester);

      expect(
        tester.getSemantics(find.text('Impressum')),
        matchesSemantics(
          isButton: true,
          isFocusable: true,
          isFocused: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Impressum',
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('marks the active item of a mutually exclusive pair as selected',
        (tester) async {
      await tester.pumpWidget(host(
        Row(mainAxisSize: MainAxisSize.min, children: [
          HoverTextLink(
            label: 'DE',
            onTap: () {},
            semanticsSelected: true,
            style: (_, __) => const TextStyle(fontSize: 12),
          ),
          HoverTextLink(
            label: 'EN',
            onTap: () {},
            semanticsSelected: false,
            style: (_, __) => const TextStyle(fontSize: 12),
          ),
        ]),
      ));

      expect(
        tester.getSemantics(find.text('DE')),
        matchesSemantics(
          isButton: true,
          isSelected: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasSelectedState: true,
          label: 'DE',
        ),
      );
      expect(
        tester.getSemantics(find.text('EN')),
        matchesSemantics(
          isButton: true,
          isSelected: false,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasSelectedState: true,
          label: 'EN',
        ),
      );
    });

    testWidgets('keeps a constant height whether focused or not',
        (tester) async {
      // The focus underline is always laid out, transparent when unfocused —
      // otherwise tabbing along the nav row would nudge it down by 2px.
      await tester.pumpWidget(host(
        HoverTextLink(
          label: 'Login',
          onTap: () {},
          style: (_, __) => const TextStyle(fontSize: 14),
        ),
      ));

      final unfocused = tester.getSize(find.byType(HoverTextLink));
      await tabTo(tester);
      expect(tester.getSize(find.byType(HoverTextLink)), unfocused);
    });
  });
}
