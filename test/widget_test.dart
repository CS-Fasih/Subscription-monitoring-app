import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tally/core/app_store.dart';
import 'package:tally/core/models.dart';
import 'package:tally/main.dart';

final _today = DateTime(2026, 10, 19);

Future<AppStore> _mount(
  WidgetTester tester, {
  Size size = const Size(1440, 1000),
  double textScale = 1,
  bool empty = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(
    await SharedPreferences.getInstance(),
    clock: () => _today,
  );
  await store.load();
  if (empty) await store.clearAll();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(TallyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Finder _dialogText(String label) =>
    find.descendant(of: find.byType(Dialog), matching: find.text(label));

Future<void> _navigate(
  WidgetTester tester,
  int page, {
  bool mobile = false,
}) async {
  if (mobile) {
    if (page == 5) {
      await tester.tap(find.byTooltip('Settings'));
    } else {
      const names = ['Overview', 'Plans', 'Calendar', 'Insights', 'Tools'];
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(names[page]),
        ),
      );
    }
  } else {
    const names = [
      'Overview',
      'Subscriptions',
      'Renewal calendar',
      'Insights',
      'Smart tools',
      'Settings',
    ];
    await tester.tap(find.text(names[page]).first);
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Use the shipped typefaces so layout tests measure the production text
    // metrics rather than Flutter's deliberately oversized Ahem test font.
    for (final family in ['Inter', 'Newsreader']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/fonts/$family.ttf'));
      await loader.load();
    }
  });
  for (final scenario in [
    (name: 'desktop', size: const Size(1440, 1000), scale: 1.0),
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (
      name: 'small phone with larger text',
      size: const Size(320, 700),
      scale: 1.3,
    ),
  ]) {
    testWidgets('all routes render on ${scenario.name} without layout errors', (
      tester,
    ) async {
      final store = await _mount(
        tester,
        size: scenario.size,
        textScale: scenario.scale,
      );
      expect(store.subscriptions, hasLength(8));
      expect(find.text('SAMPLE WORKSPACE'), findsOneWidget);
      final layoutErrors = <String, Object>{};
      void recordLayoutError(String location) {
        final error = tester.takeException();
        if (error != null) layoutErrors[location] = error;
      }

      recordLayoutError('Initial overview layout');

      const headings = [
        'A little clarity. A lot more control.',
        'Your subscriptions',
        'Renewal calendar',
        'Spending insights',
        'A little more clarity.',
        'Make yourself at home.',
      ];
      for (var page = 0; page < headings.length; page++) {
        await _navigate(tester, page, mobile: scenario.size.width < 1040);
        expect(find.text(headings[page]), findsWidgets);
        recordLayoutError('${headings[page]} at top');
        // Exercise the lower panels as well as the first viewport.
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        recordLayoutError('${headings[page]} at bottom');
      }
      expect(
        layoutErrors,
        isEmpty,
        reason: 'Every route must fit the viewport.',
      );
    });
  }

  testWidgets(
    'adding a subscription validates cents and persists the saved record',
    (tester) async {
      final store = await _mount(
        tester,
        empty: true,
        size: const Size(320, 700),
        textScale: 1.3,
      );
      await tester.tap(find.text('Add subscription').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_field('Subscription name'));
      await tester.enterText(_field('Subscription name'), 'Nebula');
      await tester.ensureVisible(_field('Price (USD)'));
      await tester.enterText(_field('Price (USD)'), '12.345');
      await tester.tap(_dialogText('Add subscription'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter 0–1,000,000 with up to 2 decimals.'),
        findsOneWidget,
      );
      expect(store.subscriptions, isEmpty);

      await tester.enterText(_field('Price (USD)'), '19.99');
      await tester.tap(_dialogText('Add subscription'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(store.subscriptions.single.name, 'Nebula');
      expect(store.subscriptions.single.amountCents, 1999);
      expect(store.subscriptions.single.renewalDate, _today);

      final reloaded = AppStore(
        await SharedPreferences.getInstance(),
        clock: () => _today,
      );
      await reloaded.load();
      expect(
        reloaded.subscriptions.single.toJson(),
        store.subscriptions.single.toJson(),
      );
      reloaded.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subscription search and status filters show matching plans only',
    (tester) async {
      await _mount(tester);
      await _navigate(tester, 1);
      final search = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Search subscriptions',
      );
      await tester.enterText(search, 'Netflix');
      await tester.pumpAndSettle();
      expect(find.text('Netflix'), findsWidgets);
      expect(find.text('Spotify'), findsNothing);
      expect(find.text('Showing 1 of 8 subscriptions'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Free trial'));
      await tester.pumpAndSettle();
      expect(find.text('Headspace'), findsOneWidget);
      expect(find.text('Netflix'), findsNothing);

      await tester.enterText(search, 'No such service');
      await tester.pumpAndSettle();
      expect(find.text('No matching subscriptions'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Showing 8 of 8 subscriptions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pausing a plan requires confirmation and updates spending totals',
    (tester) async {
      final store = await _mount(tester);
      final before = store.monthlyTotal;
      final netflix = store.subscriptions.firstWhere(
        (item) => item.name == 'Netflix',
      );
      await _navigate(tester, 1);
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_dialogText('Pause tracking'));
      await tester.tap(_dialogText('Pause tracking'));
      await tester.pumpAndSettle();
      expect(find.text('Pause this subscription in Tally?'), findsOneWidget);
      expect(store.monthlyTotal, before);
      await tester.tap(find.widgetWithText(FilledButton, 'Pause tracking'));
      await tester.pumpAndSettle();
      expect(
        store.subscriptions.firstWhere((item) => item.id == netflix.id).status,
        SubscriptionStatus.paused,
      );
      expect(store.monthlyTotal, closeTo(before - netflix.monthlyCents, .0001));
      expect(find.byType(Dialog), findsNothing);
      await _navigate(tester, 0);
      expect(
        find.text('\$${(store.monthlyTotal / 100).toStringAsFixed(2)}'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('calendar month controls navigate and return to today', (
    tester,
  ) async {
    await _mount(tester);
    await _navigate(tester, 2);
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('November 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 19'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('October 19'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculators compare annual costs and split every cent exactly', (
    tester,
  ) async {
    await _mount(tester);
    await _navigate(tester, 4);
    await tester.enterText(_field('Monthly plan'), '10');
    await tester.enterText(_field('Annual plan'), '90');
    await tester.pumpAndSettle();
    expect(find.text('\$30.00'), findsOneWidget);
    expect(find.text('per year · 25.0%'), findsOneWidget);

    await tester.enterText(_field('Total bill'), '10');
    await tester.enterText(_field('Number of people'), '3');
    await tester.pumpAndSettle();
    expect(
      find.text('1 person pays \$3.34\n2 people pay \$3.33'),
      findsOneWidget,
    );
    await tester.enterText(_field('Number of people'), '0');
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1 to 100.'), findsOneWidget);
    expect(
      find.text('Enter a bill and group size to calculate each share.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
