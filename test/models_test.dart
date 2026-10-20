import 'package:flutter_test/flutter_test.dart';

import 'package:tally/core/models.dart';

Subscription plan({
  DateTime? date,
  BillingCycle cycle = BillingCycle.monthly,
  int cents = 1200,
  SubscriptionStatus status = SubscriptionStatus.active,
}) => Subscription(
  id: 'test-plan',
  name: 'Example',
  amountCents: cents,
  renewalDate: date ?? DateTime(2024, 1, 31),
  cycle: cycle,
  status: status,
);

void main() {
  group('calendar recurrence', () {
    test('month-end anchor returns to 31st after short months', () {
      final subscription = plan();
      expect(
        subscription.occurrences(DateTime(2024, 1), DateTime(2024, 5, 31)),
        [
          DateTime(2024, 1, 31),
          DateTime(2024, 2, 29),
          DateTime(2024, 3, 31),
          DateTime(2024, 4, 30),
          DateTime(2024, 5, 31),
        ],
      );
      expect(
        subscription.nextRenewal(DateTime(2025, 2, 1)),
        DateTime(2025, 2, 28),
      );
      expect(
        subscription.nextRenewal(DateTime(2025, 3, 1)),
        DateTime(2025, 3, 31),
      );
    });

    test('leap-day annual anchor recovers leap day after non-leap years', () {
      final subscription = plan(
        date: DateTime(2024, 2, 29),
        cycle: BillingCycle.yearly,
      );
      expect(
        subscription.nextRenewal(DateTime(2025, 1)),
        DateTime(2025, 2, 28),
      );
      expect(
        subscription.nextRenewal(DateTime(2028, 1)),
        DateTime(2028, 2, 29),
      );
      expect(
        subscription.nextRenewal(DateTime(2100, 1)),
        DateTime(2100, 2, 28),
      );
    });

    test('quarterly recurrence uses the original day anchor', () {
      final subscription = plan(
        date: DateTime(2024, 8, 31),
        cycle: BillingCycle.quarterly,
      );
      expect(subscription.occurrences(DateTime(2024, 9), DateTime(2025, 9)), [
        DateTime(2024, 11, 30),
        DateTime(2025, 2, 28),
        DateTime(2025, 5, 31),
        DateTime(2025, 8, 31),
      ]);
    });

    test('weekly recurrence crosses year boundaries by calendar date', () {
      final subscription = plan(
        date: DateTime(2024, 12, 28),
        cycle: BillingCycle.weekly,
      );
      expect(
        subscription.occurrences(DateTime(2024, 12, 28), DateTime(2025, 1, 11)),
        [DateTime(2024, 12, 28), DateTime(2025, 1, 4), DateTime(2025, 1, 11)],
      );
    });

    test(
      'today is inclusive and a future anchor has no historical charges',
      () {
        final subscription = plan(date: DateTime(2025, 6, 10, 15));
        expect(
          subscription.nextRenewal(DateTime(2025, 6, 10, 23)),
          DateTime(2025, 6, 10),
        );
        expect(subscription.nextRenewal(DateTime(2020)), DateTime(2025, 6, 10));
        expect(
          subscription.occurrences(DateTime(2025, 1), DateTime(2025, 5, 31)),
          isEmpty,
        );
        expect(
          subscription.occurrences(DateTime(2025, 8), DateTime(2025, 6)),
          isEmpty,
        );
      },
    );

    test('paused and cancelled plans produce no projected charges', () {
      for (final status in [
        SubscriptionStatus.paused,
        SubscriptionStatus.cancelled,
      ]) {
        final subscription = plan(status: status);
        expect(subscription.isBillable, isFalse);
        expect(
          subscription.occurrences(DateTime(2024), DateTime(2026)),
          isEmpty,
        );
      }
      expect(plan(status: SubscriptionStatus.trial).isBillable, isTrue);
    });
  });

  group('financial values and validation', () {
    test(
      'cycle normalization uses integer input without rounding each plan',
      () {
        expect(plan(cents: 1099).monthlyCents, 1099);
        expect(
          plan(cents: 7999, cycle: BillingCycle.yearly).annualCents,
          closeTo(7999, 1e-8),
        );
        expect(
          plan(cents: 1500, cycle: BillingCycle.quarterly).monthlyCents,
          500,
        );
        expect(plan(cents: 100, cycle: BillingCycle.weekly).annualCents, 5200);
      },
    );

    test('JSON round trip preserves all fields and a date-only anchor', () {
      final original = plan().copyWith(
        name: '  Design tools  ',
        note: 'First line\nSecond line',
        website: 'https://example.com/account',
        reminderDays: 7,
        category: SubscriptionCategory.productivity,
      );
      final decoded = Subscription.fromJson(original.toJson());
      expect(decoded.name, 'Design tools');
      expect(decoded.note, original.note);
      expect(decoded.renewalDate, original.renewalDate);
      expect(decoded.website, original.website);
      expect(decoded.reminderDays, 7);
      expect(decoded.category, SubscriptionCategory.productivity);
    });

    test('invalid calendar dates do not overflow silently', () {
      for (final value in [
        '2025-02-29',
        '2024-13-01',
        '2024-04-31',
        '2024-01-01T00:00:00Z',
        '1800-01-01',
        '2201-01-01',
      ]) {
        expect(() => parseDate(value), throwsFormatException, reason: value);
      }
      expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
    });

    test(
      'rejects invalid monetary values, names, reminders, enum values and URLs',
      () {
        for (final change in <Map<String, dynamic>>[
          {'amountCents': -1},
          {'amountCents': 12.5},
          {'amountCents': '1200'},
          {'amountCents': 100000001},
          {'name': ' '},
          {'name': 'bad\nname'},
          {'reminderDays': -1},
          {'reminderDays': 366},
          {'cycle': 'every-so-often'},
          {'status': 'unknown'},
          {'category': 'unknown'},
          {'id': ''},
          {'website': 'javascript:alert(1)'},
          {'website': 'http://example.com/account'},
          {'website': 'https://user:pass@example.com'},
        ]) {
          expect(
            () => Subscription.fromJson({...plan().toJson(), ...change}),
            throwsFormatException,
            reason: change.toString(),
          );
        }
      },
    );

    test('settings reject unsupported currency and malformed budgets', () {
      final json = const AppSettings().toJson();
      expect(
        () => AppSettings.fromJson({...json, 'currency': 'BTC'}),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({...json, 'budgetCents': -1}),
        throwsFormatException,
      );
      expect(
        () => AppSettings.fromJson({...json, 'displayName': ''}),
        throwsFormatException,
      );
      expect(AppSettings.fromJson(json).currency, 'USD');
    });
  });
}
