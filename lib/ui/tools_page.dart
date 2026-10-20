import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key, required this.store});
  final AppStore store;

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _monthly = TextEditingController(text: '12.99');
  final _yearly = TextEditingController(text: '119.99');
  final _bill = TextEditingController(text: '29.99');
  final _people = TextEditingController(text: '3');
  final Set<String> _selected = {};

  @override
  void dispose() {
    _monthly.dispose();
    _yearly.dispose();
    _bill.dispose();
    _people.dispose();
    super.dispose();
  }

  int? _cents(String text, {bool allowZero = false}) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final parts = text.trim().split('.');
    final value =
        int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return value > 0 || allowZero && value == 0 ? value : null;
  }

  Widget _amountField(
    String label,
    TextEditingController controller, {
    bool allowZero = false,
  }) {
    final valid = _cents(controller.text, allowZero: allowZero) != null;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '${widget.store.settings.currency}  ',
        errorText: valid
            ? null
            : 'Enter ${allowZero ? 'zero or ' : ''}a positive amount (up to 2 decimals).',
        errorMaxLines: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        title: 'A little more clarity.',
        subtitle:
            'Thoughtful tools for the decisions behind your subscriptions.',
        action: Pill('YOUR MONEY, YOUR CALL', background: Colors.white),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final annual = _annualCalculator();
          final splitter = _splitCalculator();
          return constraints.maxWidth >= 780
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: annual),
                    const SizedBox(width: 22),
                    Expanded(child: splitter),
                  ],
                )
              : Column(
                  children: [annual, const SizedBox(height: 20), splitter],
                );
        },
      ),
      const SizedBox(height: 24),
      _savingsPlanner(),
      const SizedBox(height: 22),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Palette.muted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'These tools are estimates. Check taxes, plan benefits, and cancellation terms with your provider before making a change.',
              style: TextStyle(fontSize: 11, height: 1.7, color: Palette.muted),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _toolTitle(IconData icon, String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: Palette.lightGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Palette.green, size: 21),
      ),
      const SizedBox(height: 18),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -.3,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        description,
        style: const TextStyle(fontSize: 12, color: Palette.muted, height: 1.7),
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget _annualCalculator() {
    final monthly = _cents(_monthly.text);
    final yearly = _cents(_yearly.text, allowZero: true);
    final valid = monthly != null && yearly != null;
    final baseline = (monthly ?? 0) * 12;
    final savings = baseline - (yearly ?? 0);
    final breakEven = valid ? (yearly / monthly).ceil() : 0;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolTitle(
            Icons.compare_arrows_rounded,
            'Monthly or annual?',
            'See whether paying upfront is worth it. Start with the two prices offered by your provider.',
          ),
          _amountField('Monthly plan', _monthly),
          const SizedBox(height: 18),
          _amountField('Annual plan', _yearly, allowZero: true),
          const SizedBox(height: 24),
          if (valid) ...[
            _detail('12 monthly payments', money(widget.store, baseline)),
            const SizedBox(height: 12),
            _detail('One annual payment', money(widget.store, yearly)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Palette.lightGreen,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    savings > 0
                        ? 'SAVE WITH ANNUAL BILLING'
                        : savings < 0
                        ? 'MONTHLY BILLING COSTS LESS'
                        : 'SAME COST OVER A YEAR',
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: Palette.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Text(
                        money(widget.store, savings.abs()),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          color: Palette.green,
                        ),
                      ),
                      Text(
                        savings == 0
                            ? 'difference'
                            : 'per year · ${(savings.abs() / (savings < 0 ? yearly : baseline) * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Palette.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    savings > 0
                        ? yearly == 0
                              ? 'The annual plan is free at this price.'
                              : 'The upfront cost equals $breakEven ${breakEven == 1 ? 'month' : 'months'} of monthly payments, rounded up.'
                        : savings < 0
                        ? 'You would pay less by staying on the monthly plan for a full year.'
                        : 'Choose the flexibility and terms that work best for you.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.7,
                      color: Palette.green,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const Text(
              'Enter both plan prices to compare their yearly cost.',
              style: TextStyle(color: Palette.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _splitCalculator() {
    final total = _cents(_bill.text);
    final people = int.tryParse(_people.text.trim());
    final validPeople = people != null && people >= 1 && people <= 100;
    final valid = total != null && validPeople;
    final each = valid ? total ~/ people : 0;
    final extra = valid ? total % people : 0;
    final baseCount = valid ? people - extra : 0;
    final splitText = valid
        ? [
            if (extra > 0)
              '$extra ${extra == 1 ? 'person pays' : 'people pay'} ${money(widget.store, each + 1)}',
            if (baseCount > 0)
              '$baseCount ${baseCount == 1 ? 'person pays' : 'people pay'} ${money(widget.store, each)}',
          ].join('\n')
        : '';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _toolTitle(
            Icons.people_outline_rounded,
            'Share the bill.',
            'Split a family plan or a shared subscription fairly, down to the last cent.',
          ),
          _amountField('Total bill', _bill),
          const SizedBox(height: 18),
          TextField(
            controller: _people,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Number of people',
              suffixIcon: const Icon(Icons.people_outline_rounded, size: 19),
              errorText: validPeople
                  ? null
                  : 'Enter a whole number from 1 to 100.',
            ),
          ),
          const SizedBox(height: 24),
          if (valid) ...[
            _detail('Total to split', money(widget.store, total)),
            const SizedBox(height: 12),
            _detail(
              'Shared between',
              '$people ${people == 1 ? 'person' : 'people'}',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F0),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'EVERY CENT ACCOUNTED FOR',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                      color: Palette.muted,
                    ),
                  ),
                  const SizedBox(height: 11),
                  Text(
                    splitText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    extra > 0
                        ? 'The extra ${extra == 1 ? 'cent goes' : '$extra cents go'} to the first $extra ${extra == 1 ? 'person' : 'people'}. The shares add up exactly.'
                        : 'An even split. No rounding adjustment needed.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Palette.muted,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'Shared subscription · ${money(widget.store, total)}\n$splitText',
                      ),
                    );
                    if (mounted) {
                      showMessage(
                        context,
                        'Split copied. Send it to your group.',
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      showMessage(
                        context,
                        'Could not access the clipboard. You can copy the amounts above.',
                      );
                    }
                  }
                },
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                label: const Text('Copy split'),
              ),
            ),
          ] else
            const Text(
              'Enter a bill and group size to calculate each share.',
              style: TextStyle(color: Palette.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _savingsPlanner() {
    final subscriptions = widget.store.billable;
    final selected = subscriptions
        .where((sub) => _selected.contains(sub.id))
        .toList();
    final monthly = selected.fold<double>(
      0,
      (sum, sub) => sum + sub.monthlyCents,
    );
    final annual = selected.fold<double>(
      0,
      (sum, sub) => sum + sub.annualCents,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'What could you put back in your pocket?',
            subtitle:
                'Build a savings scenario. Your subscriptions stay exactly as they are.',
          ),
          const SizedBox(height: 24),
          if (subscriptions.isEmpty)
            const EmptyState(
              title: 'Your next decision starts here.',
              message:
                  'Add an active subscription to explore your potential savings.',
              icon: Icons.savings_outlined,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final list = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PLANS TO CONSIDER LETTING GO',
                      style: TextStyle(
                        color: Palette.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final sub in subscriptions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: CheckboxListTile(
                          value: _selected.contains(sub.id),
                          onChanged: (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(sub.id);
                            } else {
                              _selected.remove(sub.id);
                            }
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sub.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${money(widget.store, sub.monthlyCents)}/mo',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Palette.muted,
                                ),
                              ),
                            ],
                          ),
                          subtitle: sub.status == SubscriptionStatus.trial
                              ? const Text(
                                  'Includes the price after your trial',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Palette.muted,
                                  ),
                                )
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    if (selected.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Clear selection'),
                      ),
                  ],
                );
                final summary = Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Palette.ink,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR POTENTIAL SAVINGS',
                        style: TextStyle(
                          color: Color(0xFFB5C9BC),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        money(widget.store, annual),
                        style: const TextStyle(
                          fontSize: 38,
                          fontFamily: 'Newsreader',
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'over a year · ${money(widget.store, monthly)} per month',
                        style: const TextStyle(
                          color: Color(0xFFB5C9BC),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(color: Color(0xFF3C4F45)),
                      const SizedBox(height: 18),
                      Text(
                        '${selected.length} ${selected.length == 1 ? 'plan' : 'plans'} selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated monthly spend after changes: ${money(widget.store, widget.store.monthlyTotal - monthly)}',
                        style: const TextStyle(
                          color: Color(0xFFB5C9BC),
                          fontSize: 11,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'A planning estimate only. Cancel directly with each provider. Prepaid plans may not offer a refund.',
                        style: TextStyle(
                          color: Color(0xFFB5C9BC),
                          fontSize: 10,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                );
                return constraints.maxWidth >= 720
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: list),
                          const SizedBox(width: 36),
                          Expanded(flex: 5, child: summary),
                        ],
                      )
                    : Column(
                        children: [list, const SizedBox(height: 22), summary],
                      );
              },
            ),
        ],
      ),
    );
  }
}
