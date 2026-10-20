import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore(this._preferences, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'tally.state.v1';
  static const maxSubscriptions = 1000;
  static const maxBackupBytes = 8 * 1024 * 1024;

  final SharedPreferences _preferences;
  final DateTime Function() _clock;
  _Snapshot _state = const _Snapshot([], AppSettings(), false);
  Future<void> _pending = Future<void>.value();
  String? _storageError;
  String? _unreadableBackup;
  bool _loadFailed = false;

  List<Subscription> get subscriptions =>
      List.unmodifiable(_state.subscriptions);
  AppSettings get settings => _state.settings;
  bool get isDemo => _state.isDemo;
  String? get storageError => _storageError;
  DateTime get today => dateOnly(_clock());

  List<Subscription> get billable =>
      subscriptions.where((item) => item.isBillable).toList(growable: false);
  int get activeCount => billable.length;
  double get monthlyTotal =>
      billable.fold(0.0, (total, item) => total + item.monthlyCents);
  double get annualTotal =>
      billable.fold(0.0, (total, item) => total + item.annualCents);

  Map<SubscriptionCategory, double> get categoryTotals {
    final totals = <SubscriptionCategory, double>{};
    for (final item in billable) {
      totals.update(
        item.category,
        (value) => value + item.monthlyCents,
        ifAbsent: () => item.monthlyCents,
      );
    }
    return Map.unmodifiable(totals);
  }

  List<Subscription> upcoming([int days = 30]) {
    final start = today;
    final end = DateTime(start.year, start.month, start.day + days);
    final items = billable
        .where((item) => !item.nextRenewal(start).isAfter(end))
        .toList();
    items.sort((a, b) {
      final dateOrder = a.nextRenewal(start).compareTo(b.nextRenewal(start));
      return dateOrder == 0 ? a.name.compareTo(b.name) : dateOrder;
    });
    return items;
  }

  /// Actual charges in a calendar month, rather than normalized monthly spend.
  double projectedTotal(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    return billable.fold(
      0.0,
      (total, item) =>
          total + item.occurrences(start, end).length * item.amountCents,
    );
  }

  Future<void> load() async {
    await _pending;
    try {
      await _preferences.reload();
      final stored = _preferences.get(storageKey);
      if (stored == null) {
        final demo = _Snapshot(
          _demoSubscriptions(today),
          const AppSettings(),
          true,
        );
        if (!await _preferences.setString(storageKey, _encode(demo))) {
          throw StateError('Device storage rejected the write.');
        }
        _state = demo;
      } else {
        _unreadableBackup = stored is String ? stored : jsonEncode(stored);
        if (stored is! String) {
          throw const FormatException('Saved data has an unexpected type.');
        }
        _state = _decode(stored);
      }
      _storageError = null;
      _unreadableBackup = null;
      _loadFailed = false;
    } catch (_) {
      _loadFailed = true;
      _storageError =
          'Saved data could not be loaded. Your stored data has been preserved. '
          'Export a backup to recover it, or explicitly import, clear, or restore demo data.';
    }
    notifyListeners();
  }

  Future<void> upsert(Subscription subscription) => _commit(() {
    final item = Subscription.fromJson(subscription.toJson());
    final entries = [..._state.subscriptions];
    final index = entries.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      if (entries.length >= maxSubscriptions) {
        throw const FormatException(
          'A maximum of 1,000 subscriptions is supported.',
        );
      }
      entries.add(item);
    } else {
      entries[index] = item;
    }
    return _Snapshot(entries, settings, isDemo);
  });

  Future<void> remove(String id) => _commit(
    () => _Snapshot(
      _state.subscriptions.where((item) => item.id != id).toList(),
      settings,
      isDemo,
    ),
  );

  Future<void> setStatus(
    Subscription subscription,
    SubscriptionStatus status,
  ) => _commit(() {
    final index = _state.subscriptions.indexWhere(
      (item) => item.id == subscription.id,
    );
    if (index < 0) {
      throw StateError('This subscription has already been removed.');
    }
    final entries = [..._state.subscriptions];
    entries[index] = entries[index].copyWith(status: status);
    return _Snapshot(entries, settings, isDemo);
  });

  Future<void> updateSettings(AppSettings value) => _commit(() {
    if (value.currency != settings.currency && subscriptions.isNotEmpty) {
      throw const FormatException(
        'Start with an empty list before changing currency. Amounts are not converted.',
      );
    }
    return _Snapshot(
      _state.subscriptions,
      AppSettings.fromJson(value.toJson()),
      isDemo,
    );
  });

  Future<void> clearAll() =>
      _commit(() => _Snapshot([], settings, false), allowRecovery: true);

  Future<void> restoreDemo() => _commit(
    () => _Snapshot(
      _demoSubscriptions(today),
      settings.copyWith(
        currency: 'USD',
        budgetCents: settings.currency == 'USD'
            ? settings.budgetCents
            : const AppSettings().budgetCents,
      ),
      true,
    ),
    allowRecovery: true,
  );

  /// Validates the complete backup before publishing or replacing saved state.
  Future<void> importBackup(String contents) =>
      _commit(() => _decode(contents), allowRecovery: true);

  /// Corrupt persisted content is returned intact to allow external recovery.
  String exportBackup() => _unreadableBackup ?? _encode(_state, pretty: true);

  Future<void> _commit(
    _Snapshot Function() build, {
    bool allowRecovery = false,
  }) {
    final operation = _pending.then((_) async {
      if (_loadFailed && !allowRecovery) {
        throw StateError('Recover your saved data before making changes.');
      }
      final next = build();
      final encoded = _encode(next);
      try {
        if (!await _preferences.setString(storageKey, encoded)) {
          throw StateError('Device storage rejected the write.');
        }
      } catch (_) {
        // The legacy preferences API updates its in-memory cache before the
        // platform write completes. Refresh it so a failed write cannot appear
        // successful on a later load in the same process.
        try {
          await _preferences.reload();
        } catch (_) {
          // The committed application snapshot remains the authoritative state.
        }
        _storageError =
            'Your change could not be saved. The previous app state is unchanged. '
            'Check available device storage and try again.';
        notifyListeners();
        rethrow;
      }
      _state = next;
      _storageError = null;
      _unreadableBackup = null;
      _loadFailed = false;
      notifyListeners();
    });
    // Serializing mutations prevents simultaneous saves from losing each other.
    // Recover the queue after a rejected operation so future attempts can proceed.
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  String exportCsv() {
    final rows = <List<String>>[
      [
        'Name',
        'Amount',
        'Currency',
        'Billing cycle',
        'Category',
        'Status',
        'Next renewal',
        'Reminder days',
        'Website',
        'Notes',
      ],
      for (final item in subscriptions)
        [
          item.name,
          (item.amountCents / 100).toStringAsFixed(2),
          settings.currency,
          item.cycle.label,
          item.category.label,
          item.status.label,
          item.isBillable ? formatDate(item.nextRenewal(today)) : '',
          item.reminderDays.toString(),
          item.website,
          item.note,
        ],
    ];
    return '${rows.map((row) => row.map(_csvCell).join(',')).join('\r\n')}\r\n';
  }

  /// Explicit occurrences preserve month-end and leap-day anchors across clients.
  /// Import this file into a calendar app to activate its reminder notifications.
  String exportCalendar({int months = 12}) {
    if (months < 1 || months > 60) {
      throw ArgumentError.value(
        months,
        'months',
        'Use between 1 and 60 months.',
      );
    }
    final start = today;
    final endExclusive = addMonthsClamped(start, months);
    final end = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day - 1,
    );
    final now = _clock().toUtc();
    final stamp =
        '${_icsDate(now)}T'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Tally//Subscription Monitor//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:Tally renewals',
    ];
    for (final item in billable) {
      for (final date in item.occurrences(start, end)) {
        final next = DateTime(date.year, date.month, date.day + 1);
        final description =
            '${settings.currency} ${(item.amountCents / 100).toStringAsFixed(2)} '
            '· ${item.cycle.label}'
            '${item.note.isEmpty ? '' : '\n${item.note}'}';
        // Encode the arbitrary user-supplied ID into a safe UID token.
        final id = base64Url.encode(utf8.encode(item.id)).replaceAll('=', '');
        lines.addAll([
          'BEGIN:VEVENT',
          'UID:$id-${_icsDate(date)}@tally.local',
          'DTSTAMP:$stamp',
          'DTSTART;VALUE=DATE:${_icsDate(date)}',
          'DTEND;VALUE=DATE:${_icsDate(next)}',
          'SUMMARY:${_icsText('${item.name} renewal')}',
          'DESCRIPTION:${_icsText(description)}',
          'TRANSP:TRANSPARENT',
          'BEGIN:VALARM',
          'ACTION:DISPLAY',
          'DESCRIPTION:${_icsText('${item.name} renews soon')}',
          'TRIGGER:-P${item.reminderDays}D',
          'END:VALARM',
          'END:VEVENT',
        ]);
      }
    }
    lines.add('END:VCALENDAR');
    return '${lines.map(_foldIcsLine).join('\r\n')}\r\n';
  }

  static String _encode(_Snapshot value, {bool pretty = false}) {
    final json = <String, Object?>{
      'format': 'tally-backup',
      'version': 1,
      'isDemo': value.isDemo,
      'settings': value.settings.toJson(),
      'subscriptions': value.subscriptions
          .map((item) => item.toJson())
          .toList(),
    };
    final compact = jsonEncode(json);
    _checkBackupSize(compact);
    if (!pretty) return compact;
    final readable = const JsonEncoder.withIndent('  ').convert(json);
    // A valid saved workspace must always export to a re-importable backup.
    // Pretty printing is optional when whitespace would exceed the size limit.
    return _fitsBackupLimit(readable) ? readable : compact;
  }

  static _Snapshot _decode(String raw) {
    _checkBackupSize(raw);
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'tally-backup' ||
        decoded['version'] != 1 ||
        decoded['version'] is! int ||
        decoded['isDemo'] is! bool ||
        decoded['settings'] is! Map<String, dynamic> ||
        decoded['subscriptions'] is! List) {
      throw const FormatException(
        'This is not a supported Tally backup (version 1).',
      );
    }
    final values = decoded['subscriptions'] as List;
    if (values.length > maxSubscriptions) {
      throw const FormatException(
        'A backup may contain up to 1,000 subscriptions.',
      );
    }
    final ids = <String>{};
    final subscriptions = <Subscription>[];
    for (final value in values) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid subscription in backup.');
      }
      final item = Subscription.fromJson(value);
      if (!ids.add(item.id)) {
        throw const FormatException(
          'Backup contains duplicate subscription IDs.',
        );
      }
      subscriptions.add(item);
    }
    return _Snapshot(
      subscriptions,
      AppSettings.fromJson(decoded['settings'] as Map<String, dynamic>),
      decoded['isDemo'] as bool,
    );
  }

  static bool _fitsBackupLimit(String value) =>
      value.length <= maxBackupBytes &&
      utf8.encode(value).length <= maxBackupBytes;

  static void _checkBackupSize(String value) {
    if (!_fitsBackupLimit(value)) {
      throw const FormatException(
        'Workspace exceeds the 8 MB limit. Shorten notes or remove unused subscriptions.',
      );
    }
  }
}

class _Snapshot {
  const _Snapshot(this.subscriptions, this.settings, this.isDemo);
  final List<Subscription> subscriptions;
  final AppSettings settings;
  final bool isDemo;
}

String _csvCell(String value) {
  // CSV quoting alone does not prevent spreadsheet formula evaluation.
  final safe = RegExp(r'^\s*[=+@\-\t\r]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}

String _icsDate(DateTime date) => formatDate(date).replaceAll('-', '');

String _icsText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\n', r'\n')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

String _foldIcsLine(String line) {
  final result = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final length = utf8.encode(char).length;
    if (bytes + length > 75) {
      result.write('\r\n ');
      bytes = 1;
    }
    result.write(char);
    bytes += length;
  }
  return result.toString();
}

List<Subscription> _demoSubscriptions(DateTime today) {
  DateTime due(int days) => DateTime(today.year, today.month, today.day + days);
  return [
    Subscription(
      id: 'demo-netflix',
      name: 'Netflix',
      amountCents: 1549,
      renewalDate: due(2),
      category: SubscriptionCategory.entertainment,
      website: 'https://www.netflix.com/youraccount',
      note: 'Standard plan',
    ),
    Subscription(
      id: 'demo-spotify',
      name: 'Spotify',
      amountCents: 1099,
      renewalDate: due(5),
      category: SubscriptionCategory.entertainment,
      website: 'https://www.spotify.com/account',
      note: 'Premium Individual',
    ),
    Subscription(
      id: 'demo-figma',
      name: 'Figma',
      amountCents: 1500,
      renewalDate: due(8),
      category: SubscriptionCategory.productivity,
      website: 'https://www.figma.com',
      note: 'Professional · one seat',
    ),
    Subscription(
      id: 'demo-notion',
      name: 'Notion',
      amountCents: 1000,
      renewalDate: due(13),
      category: SubscriptionCategory.productivity,
      website: 'https://www.notion.so',
      note: 'Plus plan',
    ),
    Subscription(
      id: 'demo-adobe',
      name: 'Adobe',
      amountCents: 2299,
      renewalDate: due(17),
      category: SubscriptionCategory.productivity,
      website: 'https://account.adobe.com/plans',
      note: 'Creative Cloud · Photography',
    ),
    Subscription(
      id: 'demo-icloud',
      name: 'iCloud+',
      amountCents: 299,
      renewalDate: due(21),
      category: SubscriptionCategory.utilities,
      website: 'https://support.apple.com/icloud',
      note: '200 GB storage',
    ),
    Subscription(
      id: 'demo-strava',
      name: 'Strava',
      amountCents: 7999,
      renewalDate: due(25),
      cycle: BillingCycle.yearly,
      category: SubscriptionCategory.lifestyle,
      website: 'https://www.strava.com/settings/subscription',
      note: 'Annual membership',
    ),
    Subscription(
      id: 'demo-headspace',
      name: 'Headspace',
      amountCents: 1299,
      renewalDate: due(4),
      status: SubscriptionStatus.trial,
      category: SubscriptionCategory.lifestyle,
      website: 'https://www.headspace.com',
      note: 'Trial ends on the next renewal date',
    ),
  ];
}
