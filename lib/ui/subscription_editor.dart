import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

Future<void> openSubscriptionEditor(
  BuildContext context,
  AppStore store, {
  Subscription? subscription,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) =>
      _SubscriptionEditor(store: store, subscription: subscription),
);

class _SubscriptionEditor extends StatefulWidget {
  const _SubscriptionEditor({required this.store, this.subscription});
  final AppStore store;
  final Subscription? subscription;

  @override
  State<_SubscriptionEditor> createState() => _SubscriptionEditorState();
}

class _SubscriptionEditorState extends State<_SubscriptionEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _website;
  late final TextEditingController _note;
  late BillingCycle _cycle;
  late SubscriptionCategory _category;
  late SubscriptionStatus _status;
  late DateTime _renewal;
  late int _reminder;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final item = widget.subscription;
    _name = TextEditingController(text: item?.name ?? '');
    _amount = TextEditingController(
      text: item == null
          ? ''
          : '${item.amountCents ~/ 100}.${(item.amountCents % 100).toString().padLeft(2, '0')}',
    );
    _website = TextEditingController(text: item?.website ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _cycle = item?.cycle ?? BillingCycle.monthly;
    _category = item?.category ?? SubscriptionCategory.other;
    _status = item?.status ?? SubscriptionStatus.active;
    _renewal = item?.renewalDate ?? widget.store.today;
    _reminder = item?.reminderDays ?? widget.store.settings.reminderDays;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _website.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _parseAmount(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole > 1000000) return null;
    final cents =
        whole * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    return cents <= 100000000 ? cents : null;
  }

  String? _websiteError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp(r'\s').hasMatch(text)) {
      return 'Enter a complete https:// provider address.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final item = Subscription(
      id:
          widget.subscription?.id ??
          'sub-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}',
      name: _name.text.trim(),
      amountCents: _parseAmount(_amount.text)!,
      cycle: _cycle,
      category: _category,
      status: _status,
      renewalDate: _renewal,
      reminderDays: _reminder,
      website: _website.text.trim(),
      note: _note.text.trim(),
    );
    await _perform(() => widget.store.upsert(item));
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? error.message
            : 'Your change could not be saved. Check available storage and try again.';
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _renewal,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: _status == SubscriptionStatus.trial
          ? 'FIRST PAID RENEWAL'
          : 'BILLING DATE',
    );
    if (selected != null && mounted) setState(() => _renewal = selected);
  }

  Future<void> _delete() async {
    final approved = await confirmAction(
      context,
      title: 'Delete this subscription?',
      message:
          'Remove ${widget.subscription!.name} from Tally? This does not cancel your plan with the provider.',
      confirm: 'Delete subscription',
    );
    if (!approved || !mounted) return;
    await _perform(() => widget.store.remove(widget.subscription!.id));
  }

  Future<void> _changeTracking(SubscriptionStatus status) async {
    final approved = await confirmAction(
      context,
      title: status == SubscriptionStatus.cancelled
          ? 'Stop tracking this subscription?'
          : status == SubscriptionStatus.paused
          ? 'Pause this subscription in Tally?'
          : 'Resume tracking?',
      message: status == SubscriptionStatus.active
          ? '${widget.subscription!.name} will be included in your spending totals and renewal calendar again. Other unsaved edits will be discarded.'
          : 'This only changes tracking in Tally. Manage or cancel your actual plan with the provider. Other unsaved edits will be discarded.',
      confirm: status == SubscriptionStatus.cancelled
          ? 'Stop tracking'
          : status == SubscriptionStatus.paused
          ? 'Pause tracking'
          : 'Resume tracking',
    );
    if (!approved || !mounted) return;
    await _perform(() => widget.store.setStatus(widget.subscription!, status));
  }

  Future<void> _openProvider() async {
    final website = _website.text.trim();
    final validation = _websiteError(website);
    if (validation != null || website.isEmpty) {
      setState(
        () => _error = validation ?? 'Add the provider’s website first.',
      );
      return;
    }
    try {
      if (!await launchUrl(
        Uri.parse(website),
        mode: LaunchMode.externalApplication,
      )) {
        if (mounted) {
          setState(() => _error = 'The provider website could not be opened.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The provider website could not be opened.');
      }
    }
  }

  void _selectProvider(
    String name,
    SubscriptionCategory category,
    String website,
  ) {
    setState(() {
      _name.text = name;
      _category = category;
      _website.text = website;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = <int>{0, 1, 3, 7, _reminder}.toList()..sort();
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 590,
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing
                                ? 'Subscription details'
                                : 'Add a subscription',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.6,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _editing
                                ? 'Keep the details up to date.'
                                : 'A few details. One less thing to remember.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_editing) ...[
                          const Text(
                            'QUICK ADD',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              color: Palette.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _providerChip(
                                'Netflix',
                                SubscriptionCategory.entertainment,
                                'https://www.netflix.com/youraccount',
                              ),
                              _providerChip(
                                'Spotify',
                                SubscriptionCategory.entertainment,
                                'https://www.spotify.com/account',
                              ),
                              _providerChip(
                                'Notion',
                                SubscriptionCategory.productivity,
                                'https://www.notion.so',
                              ),
                              _providerChip(
                                'Figma',
                                SubscriptionCategory.productivity,
                                'https://www.figma.com',
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                        ],
                        TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Subscription name',
                            hintText: 'e.g. Spotify Premium',
                            counterText: '',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a subscription name.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        _fieldPair(
                          TextFormField(
                            controller: _amount,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText:
                                  'Price (${widget.store.settings.currency})',
                              hintText: '0.00',
                            ),
                            validator: (value) =>
                                _parseAmount(value ?? '') == null
                                ? 'Enter 0–1,000,000 with up to 2 decimals.'
                                : null,
                          ),
                          DropdownButtonFormField<BillingCycle>(
                            initialValue: _cycle,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Billing cycle',
                            ),
                            items: BillingCycle.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _cycle = value!),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _fieldPair(
                          DropdownButtonFormField<SubscriptionCategory>(
                            key: ValueKey(_category),
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: SubscriptionCategory.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _category = value!),
                          ),
                          DropdownButtonFormField<SubscriptionStatus>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: SubscriptionStatus.values
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _status = value!),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _fieldPair(
                          Semantics(
                            button: true,
                            label: 'Choose billing date',
                            child: InkWell(
                              onTap: _busy ? null : _pickDate,
                              borderRadius: BorderRadius.circular(9),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: _status == SubscriptionStatus.trial
                                      ? 'First paid renewal'
                                      : 'Billing date',
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                  ),
                                  enabled: !_busy,
                                ),
                                child: Text(
                                  DateFormat('MMM d, y').format(_renewal),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                          DropdownButtonFormField<int>(
                            initialValue: _reminder,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Remind me',
                            ),
                            items: reminders
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value == 0
                                          ? 'On renewal day'
                                          : '$value ${value == 1 ? 'day' : 'days'} before',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (value) => setState(() => _reminder = value!),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status == SubscriptionStatus.trial
                              ? 'Enter the price you’ll pay after the trial. Forecasts include this amount from the first paid renewal.'
                              : 'Use a known billing date. Future renewals keep this day where the month allows.',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Palette.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Reminders appear in Tally. Export your renewal calendar from Calendar or Settings to enable calendar app alerts.',
                          style: TextStyle(fontSize: 10, color: Palette.muted),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _website,
                          enabled: !_busy,
                          maxLength: 2048,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Provider website (optional)',
                            hintText: 'https://',
                            counterText: '',
                          ),
                          validator: _websiteError,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _note,
                          enabled: !_busy,
                          maxLength: 4000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText:
                                'Plan, shared members, or anything useful',
                            counterText: '',
                          ),
                        ),
                        if (_editing) ...[
                          const SizedBox(height: 22),
                          const Divider(),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busy ? null : _openProvider,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 15,
                                ),
                                label: const Text('Open provider'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _changeTracking(
                                        widget.subscription!.isBillable
                                            ? SubscriptionStatus.paused
                                            : SubscriptionStatus.active,
                                      ),
                                icon: Icon(
                                  widget.subscription!.isBillable
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 17,
                                ),
                                label: Text(
                                  widget.subscription!.isBillable
                                      ? 'Pause tracking'
                                      : 'Resume tracking',
                                ),
                              ),
                              if (widget.subscription!.status !=
                                  SubscriptionStatus.cancelled)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _changeTracking(
                                          SubscriptionStatus.cancelled,
                                        ),
                                  child: const Text('Cancel tracking'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Tally does not cancel subscriptions with providers. Manage your actual plan on the provider’s website.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final remove = IconButton(
                      onPressed: _busy ? null : _delete,
                      tooltip: 'Delete subscription',
                      color: Theme.of(context).colorScheme.error,
                      icon: const Icon(Icons.delete_outline_rounded, size: 21),
                    );
                    final cancel = TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    );
                    final save = FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _editing ? 'Save changes' : 'Add subscription',
                            ),
                    );
                    if (constraints.maxWidth < 310) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              if (_editing) remove,
                              const Spacer(),
                              cancel,
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(width: double.infinity, child: save),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        if (_editing) remove,
                        const Spacer(),
                        cancel,
                        const SizedBox(width: 10),
                        save,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerChip(
    String name,
    SubscriptionCategory category,
    String website,
  ) => ActionChip(
    onPressed: _busy ? null : () => _selectProvider(name, category, website),
    label: Text(name, style: const TextStyle(fontSize: 11)),
    backgroundColor: Colors.white,
    avatar: Icon(categoryIcon(category), size: 15, color: Palette.green),
  );

  Widget _fieldPair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 360) {
        return Column(children: [first, const SizedBox(height: 18), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );
}
