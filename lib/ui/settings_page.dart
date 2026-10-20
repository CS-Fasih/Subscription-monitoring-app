import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/app_store.dart';
import '../core/file_transfer.dart';
import '../core/models.dart';
import 'design.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _maxImportBytes = AppStore.maxBackupBytes;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _budget = TextEditingController();
  late String _currency;
  late int _reminderDays;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _readSettings();
  }

  void _readSettings() {
    final settings = widget.store.settings;
    _name.text = settings.displayName;
    _budget.text = (settings.budgetCents / 100).toStringAsFixed(2);
    _currency = settings.currency;
    _reminderDays = settings.reminderDays;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  int? _budgetCents() {
    final text = _budget.text.trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final value =
        int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return value <= 100000000 ? value : null;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
        showMessage(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              widget.store.storageError ??
              'This action could not be completed. Please try again. Your existing data has been kept.',
        );
        showMessage(context, _error!);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      await widget.store.updateSettings(
        widget.store.settings.copyWith(
          displayName: _name.text.trim(),
          budgetCents: _budgetCents()!,
          currency: _currency,
          reminderDays: _reminderDays,
        ),
      );
      if (mounted) showMessage(context, 'Preferences saved on this device.');
    });
  }

  String _filename(String extension) =>
      'tally-${formatDate(DateTime.now())}.$extension';

  Future<void> _export(String type) => _run(() async {
    final (content, extension, mimeType) = switch (type) {
      'csv' => (widget.store.exportCsv(), 'csv', 'text/csv'),
      'ics' => (widget.store.exportCalendar(), 'ics', 'text/calendar'),
      _ => (widget.store.exportBackup(), 'json', 'application/json'),
    };
    await deliverFile(
      context,
      content: content,
      filename: _filename(extension),
      mimeType: mimeType,
    );
  });

  Future<void> _import() => _run(() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: false,
      withReadStream: true,
    );
    if (result == null) return;
    final file = result.files.single;
    if (file.size > _maxImportBytes) {
      throw const FormatException('Choose a JSON backup no larger than 8 MB.');
    }
    final Uint8List bytes;
    if (file.readStream != null) {
      final buffer = BytesBuilder(copy: false);
      await for (final chunk in file.readStream!) {
        if (buffer.length + chunk.length > _maxImportBytes) {
          throw const FormatException(
            'Choose a JSON backup no larger than 8 MB.',
          );
        }
        buffer.add(chunk);
      }
      bytes = buffer.takeBytes();
    } else {
      bytes = file.bytes ?? await file.xFile.readAsBytes();
    }
    if (bytes.length > _maxImportBytes) {
      throw const FormatException('Choose a JSON backup no larger than 8 MB.');
    }
    final contents = utf8.decode(bytes);
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'tally-backup') {
      throw const FormatException('Choose a JSON backup exported from Tally.');
    }
    if (!mounted) return;
    final confirmed = await confirmAction(
      context,
      title: 'Restore this backup?',
      message:
          'This replaces all subscriptions and preferences on this device. Export a backup first if you want to keep your current list. The file will be validated before anything is replaced.',
      confirm: 'Restore backup',
    );
    if (!confirmed) return;
    await widget.store.importBackup(contents);
    if (!mounted) return;
    setState(_readSettings);
    showMessage(
      context,
      'Backup restored. Your subscriptions and preferences are ready.',
    );
  });

  Future<void> _clear() async {
    final confirmed = await confirmAction(
      context,
      title: widget.store.isDemo
          ? 'Start with a clean slate?'
          : 'Clear all subscriptions?',
      message:
          'This permanently removes every subscription saved on this device. Your preferences stay in place. Export a backup first if you may want to restore this list.',
      confirm: 'Clear subscriptions',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      await widget.store.clearAll();
      if (mounted) {
        showMessage(context, 'Subscriptions cleared. Ready for a fresh start.');
      }
    });
  }

  Future<void> _restoreDemo() async {
    if (widget.store.subscriptions.isNotEmpty ||
        widget.store.storageError != null) {
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: 'Explore a sample workspace?',
      message:
          'This adds eight sample subscriptions in USD. If you use another currency, your workspace switches to USD with a \$250 sample budget. Prices are examples, not live provider prices. You can clear the samples at any time.',
      confirm: 'Load sample data',
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      if (widget.store.subscriptions.isNotEmpty) {
        throw const FormatException(
          'Your list has changed. Clear it before loading sample data.',
        );
      }
      await widget.store.restoreDemo();
      if (mounted) {
        setState(_readSettings);
        showMessage(
          context,
          'Sample workspace loaded. All amounts are examples.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        title: 'Make yourself at home.',
        subtitle: 'Your preferences, your data, and a little peace of mind.',
      ),
      if (_error != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2EE),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: Color(0xFFB23D3D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB23D3D),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss error',
                onPressed: () => setState(() => _error = null),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final preferences = _preferences();
          final privacy = _privacyCard();
          return constraints.maxWidth >= 850
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: preferences),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: privacy),
                  ],
                )
              : Column(
                  children: [preferences, const SizedBox(height: 22), privacy],
                );
        },
      ),
      const SizedBox(height: 24),
      _dataControls(),
      const SizedBox(height: 24),
      _workspaceControls(),
      const SizedBox(height: 24),
      const Center(
        child: Text(
          'Tally · A considered home for your subscriptions.',
          style: TextStyle(fontSize: 10, color: Palette.muted),
        ),
      ),
    ],
  );

  Widget _preferences() {
    final currencyLocked = widget.store.subscriptions.isNotEmpty;
    final reminderValues = <int>{0, 1, 3, 7, _reminderDays}.toList()..sort();
    return Panel(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              title: 'Personal preferences',
              subtitle: 'Small details that make Tally feel like yours.',
            ),
            const SizedBox(height: 25),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Your name',
                counterText: '',
                helperText:
                    'Used in your personal dashboard. No account is created.',
                helperMaxLines: 2,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the name you would like to see.';
                }
                if (value.trim().length > 80 ||
                    RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
                  return 'Use up to 80 printable characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _budget,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monthly budget',
                prefixText: '$_currency  ',
                helperText:
                    'Your target for recurring spending. Zero sets a no-spend budget.',
                helperMaxLines: 2,
              ),
              validator: (_) => _budgetCents() == null
                  ? 'Enter 0–1,000,000 with up to two decimal places.'
                  : null,
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              key: ValueKey('currency-$_currency'),
              initialValue: _currency,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Currency',
                helperText: currencyLocked
                    ? 'Currency is fixed while subscriptions exist. Amounts are not converted.'
                    : 'Used for all prices. Changing it does not convert your budget.',
                helperMaxLines: 3,
              ),
              items: AppSettings.supportedCurrencies
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency,
                      child: Text(
                        _currencyLabel(currency),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy || currencyLocked
                  ? null
                  : (value) => setState(() => _currency = value!),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<int>(
              key: ValueKey('reminder-$_reminderDays'),
              initialValue: _reminderDays,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Default calendar reminder',
                helperText:
                    'For new subscriptions. Existing reminders stay as set.',
                helperMaxLines: 2,
              ),
              items: reminderValues
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: Text(
                        days == 0
                            ? 'On renewal day'
                            : '$days ${days == 1 ? 'day' : 'days'} before',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _reminderDays = value!),
            ),
            const SizedBox(height: 15),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: Palette.muted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reminders work through an exported calendar file. Import it into your calendar and enable alerts there.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Palette.muted,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : _saveSettings,
                  child: const Text('Save preferences'),
                ),
                if (_busy) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _currencyLabel(String currency) => switch (currency) {
    'USD' => 'USD · US dollar',
    'EUR' => 'EUR · Euro',
    'GBP' => 'GBP · British pound',
    'CAD' => 'CAD · Canadian dollar',
    'AUD' => 'AUD · Australian dollar',
    'PKR' => 'PKR · Pakistani rupee',
    'INR' => 'INR · Indian rupee',
    'JPY' => 'JPY · Japanese yen',
    'CHF' => 'CHF · Swiss franc',
    'AED' => 'AED · UAE dirham',
    'SGD' => 'SGD · Singapore dollar',
    _ => currency,
  };

  Widget _privacyCard() => Panel(
    color: const Color(0xFFF0F4F0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline_rounded, color: Palette.green, size: 25),
        const SizedBox(height: 20),
        const Text(
          'Your business.\nKept yours.',
          style: TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 32,
            height: 1.1,
            color: Palette.green,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Tally stores your subscription list on this device. There is no Tally account or cloud sync.',
          style: TextStyle(fontSize: 12, color: Palette.green, height: 1.8),
        ),
        const SizedBox(height: 23),
        for (final item in [
          (
            Icons.account_balance_outlined,
            'No bank connection',
            'You add and manage your own subscriptions.',
          ),
          (
            Icons.notifications_none_rounded,
            'Calendar-based reminders',
            'No background push alerts. Calendar imports provide reminders through your calendar app.',
          ),
          (
            Icons.backup_outlined,
            'Backups are in your hands',
            'Clearing browser data or uninstalling the app can remove your list. Keep regular JSON backups.',
          ),
        ]) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.$1, color: Palette.green, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Palette.green,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$3,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.green,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
        ],
        const Divider(color: Color(0xFFD8E3DA)),
        const SizedBox(height: 17),
        const Text(
          'Device storage and exported files are not encrypted by Tally. Avoid adding passwords, payment details, or other sensitive information.',
          style: TextStyle(fontSize: 10, color: Palette.green, height: 1.7),
        ),
      ],
    ),
  );

  Widget _dataControls() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Your data, to go',
          subtitle:
              'Keep a copy, take a closer look, or bring your renewals to your calendar.',
        ),
        const SizedBox(height: 22),
        _dataRow(
          icon: Icons.download_outlined,
          title: 'Back up your workspace',
          description:
              'A JSON file with your subscriptions and preferences. Keep it somewhere safe.',
          label: 'Export JSON',
          action: () => _export('json'),
        ),
        const Divider(),
        _dataRow(
          icon: Icons.upload_file_outlined,
          title: 'Restore from a backup',
          description:
              'Import a Tally JSON backup, up to 8 MB. Replaces the current workspace after confirmation.',
          label: 'Import backup',
          action: _import,
        ),
        const Divider(),
        _dataRow(
          icon: Icons.table_chart_outlined,
          title: 'Open it in a spreadsheet',
          description:
              'A readable CSV of all subscriptions. Use a JSON backup if you want to restore later.',
          label: 'Export CSV',
          action: widget.store.subscriptions.isEmpty
              ? null
              : () => _export('csv'),
        ),
        const Divider(),
        _dataRow(
          icon: Icons.event_available_outlined,
          title: 'Bring renewals to your calendar',
          description:
              'Export the next 12 months as an .ics file, then import it into your calendar app. Re-export after edits; calendar imports do not sync automatically.',
          label: 'Export calendar',
          action: widget.store.billable.isEmpty ? null : () => _export('ics'),
        ),
      ],
    ),
  );

  Widget _dataRow({
    required IconData icon,
    required String title,
    required String description,
    required String label,
    required VoidCallback? action,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 19),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final detail = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Palette.muted, size: 21),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Palette.muted,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final button = OutlinedButton(
          onPressed: _busy ? null : action,
          child: Text(label),
        );
        return constraints.maxWidth >= 610
            ? Row(
                children: [
                  Expanded(child: detail),
                  const SizedBox(width: 30),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  detail,
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: button,
                  ),
                ],
              );
      },
    ),
  );

  Widget _workspaceControls() {
    final canRestore =
        widget.store.subscriptions.isEmpty && widget.store.storageError == null;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Workspace',
            subtitle: 'Start fresh or explore with sample subscriptions.',
          ),
          const SizedBox(height: 4),
          _dataRow(
            icon: Icons.layers_clear_outlined,
            title: widget.store.isDemo
                ? 'Clear sample subscriptions'
                : 'Clear subscription data',
            description:
                'Remove every saved subscription from this device. Preferences are kept. This cannot be undone without a backup.',
            label: 'Clear subscriptions',
            action:
                widget.store.subscriptions.isEmpty &&
                    widget.store.storageError == null
                ? null
                : _clear,
          ),
          const Divider(),
          _dataRow(
            icon: Icons.auto_stories_outlined,
            title: 'Explore the sample workspace',
            description: canRestore
                ? 'Add eight example subscriptions to try out Tally.'
                : 'Available with an empty list. Clear your subscriptions first to load sample data.',
            label: 'Load sample data',
            action: canRestore ? _restoreDemo : null,
          ),
        ],
      ),
    );
  }
}
