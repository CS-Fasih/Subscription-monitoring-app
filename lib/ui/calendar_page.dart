import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.store,
    required this.onSelect,
    required this.onExport,
  });

  final AppStore store;
  final ValueChanged<Subscription> onSelect;
  final VoidCallback onExport;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = widget.store.today;
    _month = DateTime(today.year, today.month);
    _selected = DateTime(today.year, today.month, today.day);
  }

  void _moveMonth(int difference) => setState(() {
    _month = DateTime(_month.year, _month.month + difference);
    final today = widget.store.today;
    _selected = today.year == _month.year && today.month == _month.month
        ? DateTime(today.year, today.month, today.day)
        : _month;
  });

  void _goToToday() => setState(() {
    final today = widget.store.today;
    _month = DateTime(today.year, today.month);
    _selected = DateTime(today.year, today.month, today.day);
  });

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final Map<int, List<Subscription>> daily = {};
    var chargeCount = 0;
    var total = 0;
    for (final subscription in store.billable) {
      for (final date in subscription.occurrences(_month, lastDay)) {
        daily.putIfAbsent(date.day, () => []).add(subscription);
        chargeCount++;
        total += subscription.amountCents;
      }
    }
    for (final subscriptions in daily.values) {
      subscriptions.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    }
    final selected = daily[_selected.day] ?? <Subscription>[];
    final selectedTotal = selected.fold<int>(
      0,
      (sum, subscription) => sum + subscription.amountCents,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: 'Renewal calendar',
          subtitle: 'A clear view of what is coming, before it comes around.',
          action: OutlinedButton.icon(
            onPressed: widget.onExport,
            icon: const Icon(Icons.file_download_outlined, size: 17),
            label: const Text('Export 12 months'),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 500;
            return Panel(
              padding: EdgeInsets.all(compact ? 18 : 24),
              child: Wrap(
                spacing: compact ? 30 : 70,
                runSpacing: 20,
                children: [
                  _CalendarMetric(
                    label: '${DateFormat.MMMM().format(_month)} scheduled',
                    value: money(store, total),
                  ),
                  _CalendarMetric(
                    label: 'Renewals this month',
                    value: '$chargeCount',
                  ),
                  _CalendarMetric(
                    label: 'Days with renewals',
                    value: '${daily.length}',
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final calendar = _buildCalendar(
              daily,
              constraints.maxWidth >= 870
                  ? constraints.maxWidth * .65
                  : constraints.maxWidth,
            );
            final details = _buildDetails(selected, selectedTotal);
            if (constraints.maxWidth < 870) {
              return Column(
                children: [calendar, const SizedBox(height: 22), details],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: calendar),
                const SizedBox(width: 22),
                Expanded(flex: 4, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 15, color: Palette.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Scheduled charges are based on your renewal dates. They are estimates, not bank transactions. Paused and cancelled subscriptions are excluded.',
                style: TextStyle(
                  fontSize: 11,
                  color: Palette.muted,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendar(Map<int, List<Subscription>> daily, double width) {
    final compact = width < 530;
    final today = widget.store.today;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1;
    return Panel(
      padding: EdgeInsets.all(compact ? 12 : 22),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: _goToToday,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(40, 40),
                ),
                child: const Text('Today'),
              ),
              IconButton(
                onPressed: () => _moveMonth(-1),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded, size: 21),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _moveMonth(1),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded, size: 21),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: Palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: compact ? 57 : 78,
              crossAxisSpacing: compact ? 3 : 7,
              mainAxisSpacing: 7,
            ),
            itemCount: ((offset + days + 6) ~/ 7) * 7,
            itemBuilder: (context, index) {
              final day = index - offset + 1;
              if (day < 1 || day > days) return const SizedBox.shrink();
              final entries = daily[day] ?? <Subscription>[];
              final total = entries.fold<int>(
                0,
                (sum, subscription) => sum + subscription.amountCents,
              );
              final selected = day == _selected.day;
              final isToday =
                  _month.year == today.year &&
                  _month.month == today.month &&
                  day == today.day;
              final date = DateTime(_month.year, _month.month, day);
              return Semantics(
                label:
                    '${DateFormat.yMMMMEEEEd().format(date)}, ${entries.length} scheduled renewals${entries.isEmpty ? '' : ', ${money(widget.store, total)}'}',
                selected: selected,
                button: true,
                excludeSemantics: true,
                child: Tooltip(
                  message: entries.isEmpty
                      ? 'No renewals'
                      : '${entries.length} renewal${entries.length == 1 ? '' : 's'} · ${money(widget.store, total)}',
                  child: Material(
                    color: selected
                        ? Palette.green
                        : entries.isNotEmpty
                        ? Palette.lightGreen.withValues(alpha: .7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _selected = date),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isToday && !selected
                                ? Palette.green
                                : Colors.transparent,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 7,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? Colors.white : Palette.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (entries.isNotEmpty && !compact)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  money(widget.store, total, decimals: 0),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: selected
                                        ? Colors.white.withValues(alpha: .8)
                                        : Palette.green,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 6,
                                child: entries.isEmpty
                                    ? null
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          for (
                                            var i = 0;
                                            i < entries.length.clamp(0, 3);
                                            i++
                                          )
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 1,
                                                  ),
                                              child: Icon(
                                                Icons.circle,
                                                size: 4,
                                                color: selected
                                                    ? Colors.white
                                                    : Palette.green,
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.circle, size: 6, color: Palette.green),
              SizedBox(width: 7),
              Text(
                'Scheduled renewal',
                style: TextStyle(fontSize: 10, color: Palette.muted),
              ),
              Spacer(),
              Icon(Icons.crop_square_rounded, size: 13, color: Palette.green),
              SizedBox(width: 5),
              Text(
                'Today',
                style: TextStyle(fontSize: 10, color: Palette.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(List<Subscription> subscriptions, int total) => Panel(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat.EEEE().format(_selected).toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: Palette.muted,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat.MMMMd().format(_selected),
          style: const TextStyle(
            fontFamily: 'Newsreader',
            fontSize: 30,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${subscriptions.length} scheduled renewal${subscriptions.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Palette.muted, fontSize: 11),
        ),
        const SizedBox(height: 22),
        const Divider(),
        if (subscriptions.isEmpty)
          const EmptyState(
            title: 'A little breathing room',
            message:
                'There are no renewals on this day.\nChoose a marked date to see what is due.',
            icon: Icons.event_available_outlined,
          )
        else ...[
          const SizedBox(height: 8),
          for (final subscription in subscriptions)
            InkWell(
              onTap: () => widget.onSelect(subscription),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    ServiceIcon(subscription, size: 35),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subscription.status == SubscriptionStatus.trial &&
                                    dateOnly(subscription.renewalDate) ==
                                        _selected
                                ? 'Trial ends · ${subscription.cycle.label}'
                                : subscription.cycle.label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        money(widget.store, subscription.amountCents),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: Palette.muted,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 19),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Scheduled total',
                  style: TextStyle(fontSize: 12, color: Palette.muted),
                ),
              ),
              Flexible(
                child: Text(
                  money(widget.store, total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _CalendarMetric extends StatelessWidget {
  const _CalendarMetric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Palette.muted)),
      const SizedBox(height: 7),
      Text(
        value,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w600,
          letterSpacing: -.8,
        ),
      ),
    ],
  );
}
