import 'dart:math' as math;

/// Calendar dates are represented at local midnight; amounts use integer cents.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Always pass the original anchor when calculating a repeating month-end date.
DateTime addMonthsClamped(DateTime anchor, int months) {
  final first = DateTime(anchor.year, anchor.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, math.min(anchor.day, lastDay));
}

enum BillingCycle {
  weekly('Weekly', 'week'),
  monthly('Monthly', 'month'),
  quarterly('Quarterly', 'quarter'),
  yearly('Yearly', 'year');

  const BillingCycle(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

enum SubscriptionCategory {
  entertainment('Entertainment'),
  productivity('Productivity'),
  lifestyle('Lifestyle'),
  utilities('Utilities'),
  education('Education'),
  other('Other');

  const SubscriptionCategory(this.label);
  final String label;
}

enum SubscriptionStatus {
  active('Active'),
  trial('Free trial'),
  paused('Paused'),
  cancelled('Cancelled');

  const SubscriptionStatus(this.label);
  final String label;
}

class Subscription {
  const Subscription({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.renewalDate,
    this.cycle = BillingCycle.monthly,
    this.category = SubscriptionCategory.other,
    this.status = SubscriptionStatus.active,
    this.note = '',
    this.website = '',
    this.reminderDays = 3,
  });

  final String id;
  final String name;
  final int amountCents;
  final BillingCycle cycle;
  final SubscriptionCategory category;
  final SubscriptionStatus status;

  /// The first known billing date, also used as the permanent recurrence anchor.
  /// For a trial, this is the first paid renewal after the trial ends.
  final DateTime renewalDate;
  final String note;
  final String website;
  final int reminderDays;

  bool get isBillable =>
      status == SubscriptionStatus.active || status == SubscriptionStatus.trial;

  double get monthlyCents => switch (cycle) {
    BillingCycle.weekly => amountCents * 52 / 12,
    BillingCycle.monthly => amountCents.toDouble(),
    BillingCycle.quarterly => amountCents / 3,
    BillingCycle.yearly => amountCents / 12,
  };

  double get annualCents => switch (cycle) {
    BillingCycle.weekly => (amountCents * 52).toDouble(),
    BillingCycle.monthly => (amountCents * 12).toDouble(),
    BillingCycle.quarterly => (amountCents * 4).toDouble(),
    BillingCycle.yearly => amountCents.toDouble(),
  };

  Subscription copyWith({
    String? id,
    String? name,
    int? amountCents,
    BillingCycle? cycle,
    SubscriptionCategory? category,
    SubscriptionStatus? status,
    DateTime? renewalDate,
    String? note,
    String? website,
    int? reminderDays,
  }) => Subscription(
    id: id ?? this.id,
    name: name ?? this.name,
    amountCents: amountCents ?? this.amountCents,
    cycle: cycle ?? this.cycle,
    category: category ?? this.category,
    status: status ?? this.status,
    renewalDate: renewalDate ?? this.renewalDate,
    note: note ?? this.note,
    website: website ?? this.website,
    reminderDays: reminderDays ?? this.reminderDays,
  );

  DateTime _occurrence(int index) {
    final anchor = dateOnly(renewalDate);
    return switch (cycle) {
      // Calendar arithmetic avoids DST shifts caused by adding 24-hour periods.
      BillingCycle.weekly => DateTime(
        anchor.year,
        anchor.month,
        anchor.day + index * 7,
      ),
      BillingCycle.monthly => addMonthsClamped(anchor, index),
      BillingCycle.quarterly => addMonthsClamped(anchor, index * 3),
      BillingCycle.yearly => addMonthsClamped(anchor, index * 12),
    };
  }

  int _firstIndex(DateTime from) {
    final start = dateOnly(from);
    final anchor = dateOnly(renewalDate);
    if (!start.isAfter(anchor)) return 0;
    final months = (start.year - anchor.year) * 12 + start.month - anchor.month;
    var index = switch (cycle) {
      BillingCycle.weekly =>
        DateTime.utc(start.year, start.month, start.day)
                .difference(DateTime.utc(anchor.year, anchor.month, anchor.day))
                .inDays ~/
            7,
      BillingCycle.monthly => months,
      BillingCycle.quarterly => months ~/ 3,
      BillingCycle.yearly => months ~/ 12,
    };
    while (_occurrence(index).isBefore(start)) {
      index++;
    }
    return index;
  }

  /// Returns the first renewal on or after [from], including today's renewal.
  DateTime nextRenewal(DateTime from) => _occurrence(_firstIndex(from));

  /// Includes both boundaries. Paused and cancelled plans have no charges.
  Iterable<DateTime> occurrences(DateTime start, DateTime end) sync* {
    if (!isBillable || dateOnly(end).isBefore(dateOnly(start))) return;
    final last = dateOnly(end);
    var index = _firstIndex(start);
    while (true) {
      final occurrence = _occurrence(index++);
      if (occurrence.isAfter(last)) return;
      yield occurrence;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'amountCents': amountCents,
    'cycle': cycle.name,
    'category': category.name,
    'status': status.name,
    'renewalDate': formatDate(renewalDate),
    'note': note,
    'website': website,
    'reminderDays': reminderDays,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final website = readText(json, 'website', 2048, fallback: '');
    if (website.isNotEmpty) {
      final uri = Uri.tryParse(website);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Website must be a valid HTTPS URL.');
      }
    }
    return Subscription(
      id: readText(json, 'id', 100, nonempty: true),
      name: readText(json, 'name', 120, nonempty: true),
      amountCents: readInteger(json, 'amountCents', 0, 100000000),
      cycle: readEnum(json, 'cycle', BillingCycle.values),
      category: readEnum(json, 'category', SubscriptionCategory.values),
      status: readEnum(json, 'status', SubscriptionStatus.values),
      renewalDate: parseDate(json['renewalDate']),
      note: readText(json, 'note', 4000, fallback: '', multiline: true),
      website: website,
      reminderDays: readInteger(json, 'reminderDays', 0, 365, fallback: 3),
    );
  }
}

class AppSettings {
  const AppSettings({
    this.displayName = 'Alex',
    this.currency = 'USD',
    this.budgetCents = 25000,
    this.reminderDays = 3,
  });

  static const supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'INR',
    'PKR',
    'JPY',
    'CHF',
    'AED',
    'SGD',
  ];

  final String displayName;
  final String currency;
  final int budgetCents;
  final int reminderDays;

  AppSettings copyWith({
    String? displayName,
    String? currency,
    int? budgetCents,
    int? reminderDays,
  }) => AppSettings(
    displayName: displayName ?? this.displayName,
    currency: currency ?? this.currency,
    budgetCents: budgetCents ?? this.budgetCents,
    reminderDays: reminderDays ?? this.reminderDays,
  );

  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'currency': currency,
    'budgetCents': budgetCents,
    'reminderDays': reminderDays,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final currency = readText(json, 'currency', 3, nonempty: true);
    if (!supportedCurrencies.contains(currency)) {
      throw const FormatException('Unsupported currency.');
    }
    return AppSettings(
      displayName: readText(json, 'displayName', 80, nonempty: true),
      currency: currency,
      budgetCents: readInteger(json, 'budgetCents', 0, 100000000),
      reminderDays: readInteger(json, 'reminderDays', 0, 365),
    );
  }
}

String formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime parseDate(Object? value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Renewal date must use YYYY-MM-DD.');
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year < 1900 ||
      date.year > 2200 ||
      formatDate(date) != value) {
    throw const FormatException('Renewal date is invalid or out of range.');
  }
  return dateOnly(date);
}

String readText(
  Map<String, dynamic> json,
  String key,
  int maxLength, {
  String? fallback,
  bool nonempty = false,
  bool multiline = false,
}) {
  final value = json[key] ?? fallback;
  final forbidden = multiline
      ? RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]')
      : RegExp(r'[\x00-\x1F\x7F]');
  if (value is! String ||
      value.length > maxLength ||
      (nonempty && value.trim().isEmpty) ||
      forbidden.hasMatch(value)) {
    throw FormatException('Invalid $key.');
  }
  return value.trim();
}

int readInteger(
  Map<String, dynamic> json,
  String key,
  int min,
  int max, {
  int? fallback,
}) {
  final value = json[key] ?? fallback;
  if (value is! int || value < min || value > max) {
    throw FormatException('$key must be a whole number between $min and $max.');
  }
  return value;
}

T readEnum<T extends Enum>(
  Map<String, dynamic> json,
  String key,
  List<T> values,
) {
  final name = json[key];
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Invalid $key.');
}
