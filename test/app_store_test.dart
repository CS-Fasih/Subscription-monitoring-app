import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:tally/core/app_store.dart';
import 'package:tally/core/models.dart';

final testToday = DateTime(2025, 1, 10);

Subscription example(
  String id, {
  int cents = 1200,
  BillingCycle cycle = BillingCycle.monthly,
}) => Subscription(
  id: id,
  name: 'Service $id',
  amountCents: cents,
  renewalDate: testToday,
  cycle: cycle,
);

class FailingPreferencesStore extends InMemorySharedPreferencesStore {
  FailingPreferencesStore() : super.empty();
  bool fail = false;
  bool throwFailure = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (throwFailure) throw StateError('Simulated disk unavailable');
    if (fail) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late AppStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = AppStore(preferences, clock: () => testToday);
    await store.load();
  });

  tearDown(() => store.dispose());

  test('first launch is explicitly demo and reload preserves data', () async {
    expect(store.isDemo, isTrue);
    expect(store.subscriptions, hasLength(8));
    expect(store.activeCount, 8);
    expect(store.storageError, isNull);
    final fresh = AppStore(preferences, clock: () => testToday);
    await fresh.load();
    expect(fresh.exportBackup(), store.exportBackup());
    fresh.dispose();
  });

  test(
    'CRUD persists and reloads; clear starts empty while preserving settings',
    () async {
      await store.updateSettings(store.settings.copyWith(displayName: 'Mina'));
      await store.clearAll();
      expect(store.subscriptions, isEmpty);
      expect(store.isDemo, isFalse);
      expect(store.settings.displayName, 'Mina');
      await store.upsert(example('one'));
      await store.upsert(example('one', cents: 2500));
      expect(store.subscriptions.single.amountCents, 2500);
      await store.setStatus(
        store.subscriptions.single,
        SubscriptionStatus.paused,
      );
      expect(store.monthlyTotal, 0);
      await store.load();
      expect(store.subscriptions.single.status, SubscriptionStatus.paused);
      await store.remove('one');
      expect(store.subscriptions, isEmpty);
      await store.restoreDemo();
      expect(store.isDemo, isTrue);
      expect(store.settings.displayName, 'Mina');
    },
  );

  test(
    'concurrent mutations are serialized without dropping records',
    () async {
      await store.clearAll();
      await Future.wait(
        List.generate(20, (index) => store.upsert(example('$index'))),
      );
      expect(store.subscriptions, hasLength(20));
      await store.load();
      expect(store.subscriptions, hasLength(20));
    },
  );

  test('currency cannot change while amounts exist', () async {
    await expectLater(
      store.updateSettings(store.settings.copyWith(currency: 'EUR')),
      throwsFormatException,
    );
    expect(store.settings.currency, 'USD');
    await store.clearAll();
    await store.updateSettings(store.settings.copyWith(currency: 'EUR'));
    expect(store.settings.currency, 'EUR');
  });

  test(
    'restored USD samples reset a foreign currency budget without losing the name',
    () async {
      await store.clearAll();
      await store.updateSettings(
        store.settings.copyWith(
          displayName: 'Mina',
          currency: 'PKR',
          budgetCents: 700000,
          reminderDays: 7,
        ),
      );
      await store.restoreDemo();
      expect(store.settings.currency, 'USD');
      expect(store.settings.budgetCents, const AppSettings().budgetCents);
      expect(store.settings.displayName, 'Mina');
      expect(store.settings.reminderDays, 7);
      expect(store.isDemo, isTrue);
      await store.updateSettings(store.settings.copyWith(budgetCents: 30000));
      await store.restoreDemo();
      expect(store.settings.budgetCents, 30000);
    },
  );

  test(
    'projections count actual renewals, while monthly totals normalize',
    () async {
      await store.clearAll();
      await store.upsert(
        example('weekly', cents: 100, cycle: BillingCycle.weekly),
      );
      await store.upsert(
        example('yearly', cents: 12000, cycle: BillingCycle.yearly),
      );
      expect(
        store.projectedTotal(DateTime(2025, 1)),
        12400,
      ); // Jan 10, 17, 24, 31.
      expect(store.projectedTotal(DateTime(2025, 2)), 400);
      expect(store.monthlyTotal, closeTo(1433.333333, 0.0001));
      expect(
        store.categoryTotals[SubscriptionCategory.other],
        store.monthlyTotal,
      );
      expect(store.upcoming(0), hasLength(2));
      await store.setStatus(
        store.subscriptions.first,
        SubscriptionStatus.cancelled,
      );
      expect(store.projectedTotal(DateTime(2025, 2)), 0);
    },
  );

  test('backup import round trip replaces state atomically', () async {
    final backup = store.exportBackup();
    await store.clearAll();
    await store.importBackup(backup);
    expect(store.exportBackup(), backup);
    final before = preferences.getString(AppStore.storageKey);
    final decoded = jsonDecode(backup) as Map<String, dynamic>;
    (decoded['subscriptions'] as List).add(
      (decoded['subscriptions'] as List).first,
    );
    await expectLater(
      store.importBackup(jsonEncode(decoded)),
      throwsFormatException,
    );
    expect(store.exportBackup(), backup);
    expect(preferences.getString(AppStore.storageKey), before);
  });

  test(
    'invalid imports never partially replace settings or subscriptions',
    () async {
      final backup = store.exportBackup();
      for (final bad in [
        'not json',
        '[]',
        '{}',
        backup.replaceFirst('"version": 1', '"version": 9'),
        backup.replaceFirst('"currency": "USD"', '"currency": "BAD"'),
        backup.replaceFirst('"amountCents": 1549', '"amountCents": -1'),
        ' ' * (AppStore.maxBackupBytes + 1),
      ]) {
        await expectLater(store.importBackup(bad), throwsFormatException);
        expect(store.exportBackup(), backup);
      }
    },
  );

  test(
    'maximum plan count and amounts retain exact annual and actual charges',
    () async {
      final data = jsonDecode(store.exportBackup()) as Map<String, dynamic>;
      data['subscriptions'] = List.generate(
        AppStore.maxSubscriptions,
        (index) => example(
          '$index',
          cents: 100000000,
          cycle: BillingCycle.weekly,
        ).copyWith(note: 'a' * 4000).toJson(),
      );
      await store.importBackup(jsonEncode(data));
      expect(store.subscriptions, hasLength(AppStore.maxSubscriptions));
      expect(store.annualTotal, 5200000000000);
      expect(store.projectedTotal(DateTime(2025, 1)), 400000000000);
      expect(store.monthlyTotal, closeTo(5200000000000 / 12, 0.01));
      final backup = store.exportBackup();
      expect(
        utf8.encode(backup).length,
        lessThanOrEqualTo(AppStore.maxBackupBytes),
      );
      await store.importBackup(backup);
      expect(store.exportBackup(), backup);
      await expectLater(
        store.upsert(example('too-many')),
        throwsFormatException,
      );
      expect(store.subscriptions, hasLength(AppStore.maxSubscriptions));
    },
  );

  test(
    'near-limit Unicode backups round trip and oversized edits are rejected',
    () async {
      final data = jsonDecode(store.exportBackup()) as Map<String, dynamic>;
      final entries = List.generate(
        AppStore.maxSubscriptions,
        (index) => example('$index').toJson(),
      );
      data['subscriptions'] = entries;
      final overhead = utf8.encode(jsonEncode(data)).length;
      final noteLength =
          (AppStore.maxBackupBytes - overhead - 100) ~/
          (AppStore.maxSubscriptions * utf8.encode('中').length);
      for (final entry in entries) {
        entry['note'] = '中' * noteLength;
      }
      await store.importBackup(jsonEncode(data));
      final backup = store.exportBackup();
      expect(
        utf8.encode(backup).length,
        lessThanOrEqualTo(AppStore.maxBackupBytes),
      );
      await store.importBackup(backup);
      await expectLater(
        store.upsert(store.subscriptions.first.copyWith(note: '中' * 4000)),
        throwsFormatException,
      );
      expect(store.exportBackup(), backup);
      await store.load();
      expect(store.exportBackup(), backup);
    },
  );

  test(
    'corrupt persisted data is preserved for recovery and changes are blocked',
    () async {
      const corrupt = '{"broken":true';
      await preferences.setString(AppStore.storageKey, corrupt);
      final fresh = AppStore(preferences, clock: () => testToday);
      await fresh.load();
      expect(fresh.storageError, isNotNull);
      expect(fresh.subscriptions, isEmpty);
      expect(fresh.exportBackup(), corrupt);
      await expectLater(fresh.upsert(example('one')), throwsStateError);
      expect(preferences.getString(AppStore.storageKey), corrupt);
      await fresh.clearAll();
      expect(fresh.storageError, isNull);
      expect(fresh.isDemo, isFalse);
      fresh.dispose();
    },
  );

  test(
    'write rejection and exception preserve state and permit retry',
    () async {
      // Reset the singleton before replacing its platform backend.
      SharedPreferences.setMockInitialValues({});
      final backend = FailingPreferencesStore();
      SharedPreferencesStorePlatform.instance = backend;
      final diskPreferences = await SharedPreferences.getInstance();
      final durableStore = AppStore(diskPreferences, clock: () => testToday);
      await durableStore.load();
      await durableStore.clearAll();
      final before = durableStore.exportBackup();
      backend.fail = true;
      await expectLater(durableStore.upsert(example('one')), throwsStateError);
      expect(durableStore.exportBackup(), before);
      expect(durableStore.storageError, isNotNull);
      await durableStore.load();
      expect(durableStore.subscriptions, isEmpty);
      backend.fail = false;
      backend.throwFailure = true;
      await expectLater(durableStore.upsert(example('two')), throwsStateError);
      expect(durableStore.subscriptions, isEmpty);
      backend.throwFailure = false;
      await durableStore.upsert(example('one'));
      expect(durableStore.subscriptions.single.id, 'one');
      expect(durableStore.storageError, isNull);
      durableStore.dispose();
    },
  );

  test(
    'CSV quotes text and neutralizes spreadsheet formula injection',
    () async {
      await store.clearAll();
      await store.upsert(
        example('one').copyWith(name: '=SUM(A1,A2)', note: 'Say "hi", please'),
      );
      final csv = store.exportCsv();
      expect(csv, contains('"\'=SUM(A1,A2)"'));
      expect(csv, contains('"Say ""hi"", please"'));
      expect(csv.endsWith('\r\n'), isTrue);
    },
  );

  test(
    'ICS has real dates, escaped text, reminders and UTF-8 safe folded lines',
    () async {
      await store.clearAll();
      await store.upsert(
        example('one').copyWith(
          name: 'Studio, Plus; membership',
          note: '${'é' * 80}\nPath \\ folder',
          renewalDate: DateTime(2025, 1, 31),
          reminderDays: 5,
        ),
      );
      final ics = store.exportCalendar(months: 3);
      expect(ics, contains('DTSTART;VALUE=DATE:20250131\r\n'));
      expect(ics, contains('DTSTART;VALUE=DATE:20250228\r\n'));
      expect(ics, contains('DTSTART;VALUE=DATE:20250331\r\n'));
      expect(ics, contains(r'SUMMARY:Studio\, Plus\; membership renewal'));
      expect(ics, contains('TRIGGER:-P5D\r\n'));
      expect(ics.replaceAll('\r\n ', ''), contains(r'\nPath \\ folder'));
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(() => store.exportCalendar(months: 0), throwsArgumentError);
    },
  );
}
