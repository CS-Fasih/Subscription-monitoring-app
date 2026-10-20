import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.store,
    required this.onAdd,
    required this.onSelect,
    required this.onNavigate,
  });
  final AppStore store;
  final VoidCallback onAdd;
  final ValueChanged<Subscription> onSelect;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final due = store.upcoming(30);
    final nearest = due.isEmpty ? null : due.first;
    final remaining = store.settings.budgetCents - store.monthlyTotal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          title: 'A little clarity. A lot more control.',
          subtitle:
              'Hello, ${store.settings.displayName}. Here’s your subscription picture.',
          action: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 17),
            label: const Text('Add subscription'),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 530
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
            final cards = [
              _Metric(
                label: 'MONTHLY SPEND',
                value: money(store, store.monthlyTotal),
                caption: 'Across ${store.activeCount} active subscriptions',
                icon: Icons.account_balance_wallet_outlined,
                highlighted: true,
                footer: 'Monthly equivalent',
                footerIcon: Icons.equalizer_rounded,
              ),
              _Metric(
                label: 'YEARLY OUTLOOK',
                value: money(store, store.annualTotal),
                caption: 'At your current subscription rates',
                icon: Icons.trending_up_rounded,
                footer: 'A little planning goes a long way',
                footerIcon: Icons.north_east_rounded,
              ),
              _Metric(
                label: 'NEXT RENEWAL',
                value: nearest == null
                    ? 'All clear'
                    : money(store, nearest.amountCents),
                caption: nearest == null
                    ? 'Nothing due in the next 30 days'
                    : '${nearest.name} · ${DateFormat('MMM d').format(nearest.nextRenewal(store.today))}',
                icon: Icons.event_outlined,
                footer: nearest == null
                    ? 'Your calendar is up to date'
                    : _daysUntil(nearest.nextRenewal(store.today), store.today),
                footerIcon: Icons.schedule_rounded,
              ),
              _Metric(
                label: 'BUDGET REMAINING',
                value: money(store, remaining.abs()),
                caption: remaining >= 0
                    ? 'Of your ${money(store, store.settings.budgetCents, decimals: 0)} monthly budget'
                    : 'Over your monthly budget',
                icon: Icons.donut_large_rounded,
                footer: remaining >= 0
                    ? 'Room to breathe'
                    : 'Time for a subscription review',
                footerIcon: remaining >= 0
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                warning: remaining < 0,
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = _ForecastPanel(
              store: store,
              onInsights: () => onNavigate(3),
            );
            final upcoming = _UpcomingPanel(
              store: store,
              onSelect: onSelect,
              onCalendar: () => onNavigate(2),
            );
            return constraints.maxWidth >= 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: chart),
                      const SizedBox(width: 22),
                      Expanded(flex: 5, child: upcoming),
                    ],
                  )
                : Column(
                    children: [chart, const SizedBox(height: 20), upcoming],
                  );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final list = _SubscriptionsPreview(
              store: store,
              onSelect: onSelect,
              onAll: () => onNavigate(1),
              onAdd: onAdd,
            );
            final categories = _CategoriesPanel(
              store: store,
              onInsights: () => onNavigate(3),
            );
            return constraints.maxWidth >= 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 8, child: list),
                      const SizedBox(width: 22),
                      Expanded(flex: 5, child: categories),
                    ],
                  )
                : Column(
                    children: [list, const SizedBox(height: 20), categories],
                  );
          },
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1EB),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.spa_outlined, color: Palette.green, size: 22),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make every subscription earn its place.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Compare plans, split bills, and find a little more room in your budget.',
                      style: TextStyle(fontSize: 11, color: Palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () => onNavigate(4),
                child: const Text('Explore tools →'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: Palette.muted,
            ),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'Your finances, your business. Data stays on this device.',
                style: TextStyle(color: Palette.muted, fontSize: 10),
              ),
            ),
            if (MediaQuery.sizeOf(context).width > 700)
              const Text(
                'A little less overhead.',
                style: TextStyle(
                  color: Palette.muted,
                  fontFamily: 'Newsreader',
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _daysUntil(DateTime date, DateTime today) {
  final days = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return days == 0
      ? 'Due today'
      : days == 1
      ? 'Due tomorrow'
      : 'Due in $days days';
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.footer,
    required this.footerIcon,
    this.highlighted = false,
    this.warning = false,
  });
  final String label, value, caption, footer;
  final IconData icon, footerIcon;
  final bool highlighted, warning;
  @override
  Widget build(BuildContext context) {
    final color = highlighted ? Colors.white : Palette.ink;
    final muted = highlighted ? const Color(0xFFC2D8CB) : Palette.muted;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: highlighted ? Palette.green : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: highlighted ? Palette.green : Palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: highlighted
                        ? const Color(0xFFD6E5DB)
                        : Palette.muted,
                  ),
                ),
              ),
              Icon(icon, color: muted, size: 17),
            ],
          ),
          const SizedBox(height: 17),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 29,
                fontWeight: FontWeight.w500,
                letterSpacing: -1.2,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            caption,
            style: TextStyle(fontSize: 10, color: muted),
            maxLines: 2,
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              Icon(
                footerIcon,
                size: 12,
                color: warning
                    ? const Color(0xFFB35C43)
                    : highlighted
                    ? const Color(0xFFD8E4CC)
                    : Palette.green,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  footer,
                  style: TextStyle(
                    fontSize: 9,
                    color: highlighted
                        ? const Color(0xFFD8E4CC)
                        : warning
                        ? const Color(0xFFB35C43)
                        : Palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({required this.store, required this.onInsights});
  final AppStore store;
  final VoidCallback onInsights;
  @override
  Widget build(BuildContext context) {
    final months = List.generate(
      6,
      (i) => DateTime(store.today.year, store.today.month + i),
    );
    final totals = months.map(store.projectedTotal).toList();
    final total = totals.fold<double>(0, (a, b) => a + b);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'The bigger picture',
            subtitle: 'Your scheduled spending, mapped out.',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: Palette.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '6-month outlook',
                style: TextStyle(fontSize: 10, color: Palette.muted),
              ),
            ),
          ),
          const SizedBox(height: 23),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                money(store, total),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -.8,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  'projected total',
                  style: TextStyle(fontSize: 10, color: Palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const Text(
            'Full calendar months, including elapsed dates this month.',
            style: TextStyle(fontSize: 9, color: Palette.muted),
          ),
          const SizedBox(height: 12),
          Semantics(
            label:
                'Projected renewal charges: ${List.generate(6, (i) => '${DateFormat('MMMM').format(months[i])} ${money(store, totals[i])}').join(', ')}',
            child: SizedBox(
              height: 153,
              width: double.infinity,
              child: CustomPaint(
                painter: _ForecastPainter(totals, store.settings.currency),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 43, top: 10, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: months
                  .map(
                    (month) => Text(
                      DateFormat('MMM').format(month),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Palette.muted,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 11),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.green,
                ),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Scheduled renewals · current rates',
                  style: TextStyle(fontSize: 9, color: Palette.muted),
                ),
              ),
              TextButton(
                onPressed: onInsights,
                child: const Text('View insights →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter(this.values, this.currency);
  final List<double> values;
  final String currency;
  @override
  void paint(Canvas canvas, Size size) {
    final ceiling = math.max(5000.0, values.fold<double>(0, math.max) * 1.3);
    final width = size.width - 52;
    final height = size.height - 10;
    for (var i = 0; i <= 3; i++) {
      final y = i * height / 3;
      canvas.drawLine(
        Offset(43, y),
        Offset(size.width - 8, y),
        Paint()
          ..color = Palette.border
          ..strokeWidth = 1,
      );
      final text = TextPainter(
        text: TextSpan(
          text: NumberFormat.compactSimpleCurrency(
            name: currency,
            decimalDigits: 0,
          ).format(ceiling * (3 - i) / 3 / 100),
          style: const TextStyle(
            fontSize: 9,
            color: Palette.muted,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 40);
      text.paint(canvas, Offset(0, y - (i == 0 ? 0 : 6)));
    }
    final points = List.generate(
      values.length,
      (i) => Offset(
        44 + i * width / (values.length - 1),
        height - values[i] / ceiling * height,
      ),
    );
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1], next = points[i];
      final mid = (prev.dx + next.dx) / 2;
      line.cubicTo(mid, prev.dy, mid, next.dy, next.dx, next.dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, height)
      ..lineTo(points.first.dx, height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2620634C), Color(0x0220634C)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = Palette.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.3,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 2.3, Paint()..color = Palette.green);
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.currency != currency;
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({
    required this.store,
    required this.onSelect,
    required this.onCalendar,
  });
  final AppStore store;
  final ValueChanged<Subscription> onSelect;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context) {
    final upcoming = store.upcoming(30).take(4).toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'Coming up next',
            subtitle: 'No more surprise renewals.',
            trailing: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Palette.background,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Palette.muted,
              ),
            ),
          ),
          const SizedBox(height: 17),
          if (upcoming.isEmpty)
            const EmptyState(
              title: 'A clear calendar',
              message: 'No renewals in the next 30 days.',
              icon: Icons.event_available_outlined,
            ),
          ...upcoming.map(
            (subscription) => InkWell(
              onTap: () => onSelect(subscription),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    ServiceIcon(subscription, size: 33),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subscription.name,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            DateFormat(
                              'MMM d, EEE',
                            ).format(subscription.nextRenewal(store.today)),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      money(store, subscription.amountCents),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCalendar,
              child: const Text('View renewal calendar →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionsPreview extends StatelessWidget {
  const _SubscriptionsPreview({
    required this.store,
    required this.onSelect,
    required this.onAll,
    required this.onAdd,
  });
  final AppStore store;
  final ValueChanged<Subscription> onSelect;
  final VoidCallback onAll, onAdd;
  @override
  Widget build(BuildContext context) => Panel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 18, 18),
          child: SectionHeading(
            title: 'Your subscriptions',
            subtitle: 'The things you choose to keep.',
            trailing: TextButton(
              onPressed: onAll,
              child: const Text('View all →'),
            ),
          ),
        ),
        if (store.subscriptions.isEmpty)
          EmptyState(
            title: 'Start with one subscription',
            message:
                'A clearer picture begins with your first recurring expense.',
            action: FilledButton(
              onPressed: onAdd,
              child: const Text('Add subscription'),
            ),
          )
        else
          ...store.subscriptions
              .take(4)
              .map(
                (subscription) => Column(
                  children: [
                    const Divider(),
                    InkWell(
                      onTap: () => onSelect(subscription),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            ServiceIcon(subscription, size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subscription.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    subscription.category.label,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (MediaQuery.sizeOf(context).width > 580) ...[
                              Pill(subscription.status.label, dot: true),
                              const SizedBox(width: 20),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money(store, subscription.amountCents),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  subscription.cycle.label.toLowerCase(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Palette.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Palette.muted,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    ),
  );
}

class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel({required this.store, required this.onInsights});
  final AppStore store;
  final VoidCallback onInsights;
  @override
  Widget build(BuildContext context) {
    final totals =
        store.categoryTotals.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'A place for every penny',
            subtitle: 'Monthly spending by category.',
          ),
          const SizedBox(height: 24),
          if (totals.isEmpty)
            const EmptyState(
              title: 'Your mix, at a glance',
              message: 'Add subscriptions to see your categories.',
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 13,
                child: Row(
                  children: totals
                      .map(
                        (e) => Expanded(
                          flex: math.max(1, (e.value * 100).round()),
                          child: Container(color: categoryColor(e.key)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 23),
            ...totals.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: categoryColor(entry.key),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.key.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Palette.muted,
                        ),
                      ),
                    ),
                    Text(
                      money(store, entry.value),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 3),
          const Divider(),
          const SizedBox(height: 7),
          TextButton(
            onPressed: onInsights,
            child: const Text('See your spending breakdown →'),
          ),
        ],
      ),
    );
  }
}
