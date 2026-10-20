import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.monthlyTotal;
    final categories =
        store.categoryTotals.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final billable = store.billable.toList()
      ..sort((a, b) => b.monthlyCents.compareTo(a.monthlyCents));
    final today = store.today;
    final months = List.generate(
      6,
      (index) => DateTime(today.year, today.month + index),
    );
    final forecast = months.map(store.projectedTotal).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'Spending insights',
          subtitle: 'Understand the small commitments that add up.',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _InsightMetric(
                label: 'MONTHLY EQUIVALENT',
                value: money(store, total),
                detail: 'Recurring costs, normalized per month',
                icon: Icons.calendar_view_month_outlined,
              ),
              _InsightMetric(
                label: 'ANNUAL EQUIVALENT',
                value: money(store, store.annualTotal),
                detail: 'At your current subscription rates',
                icon: Icons.timeline_rounded,
              ),
              _InsightMetric(
                label: 'THIS MONTH’S SCHEDULE',
                value: money(store, forecast.first),
                detail:
                    '${DateFormat.MMMM().format(today)} renewal dates, including past dates',
                icon: Icons.event_note_outlined,
              ),
            ];
            if (constraints.maxWidth < 740) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    cards[i],
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 18),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final categoryPanel = _buildCategories(categories, total);
            final budgetPanel = _buildBudget(total);
            if (constraints.maxWidth < 860) {
              return Column(
                children: [
                  categoryPanel,
                  const SizedBox(height: 22),
                  budgetPanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: categoryPanel),
                const SizedBox(width: 22),
                Expanded(flex: 5, child: budgetPanel),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _buildForecast(months, forecast),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final cycles = _buildCycles(total);
            final concentration = _buildConcentration(billable, total);
            if (constraints.maxWidth < 820) {
              return Column(
                children: [cycles, const SizedBox(height: 22), concentration],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cycles),
                const SizedBox(width: 22),
                Expanded(child: concentration),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        const Text(
          'Estimates include active subscriptions and trials at their expected renewal price. Paused and cancelled subscriptions are excluded. No payment or bank history is collected.',
          style: TextStyle(color: Palette.muted, fontSize: 11, height: 1.7),
        ),
      ],
    );
  }

  Widget _buildCategories(
    List<MapEntry<SubscriptionCategory, double>> entries,
    double total,
  ) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Where your money goes',
          subtitle: 'Monthly equivalent by category',
        ),
        const SizedBox(height: 27),
        if (entries.isEmpty)
          const EmptyState(
            title: 'Your spending, in perspective',
            message:
                'Paid subscriptions will appear in your spending breakdown.',
            icon: Icons.donut_large_rounded,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExcludeSemantics(
                      child: CustomPaint(
                        size: const Size(190, 190),
                        painter: _CategoryDonut(entries),
                      ),
                    ),
                    SizedBox(
                      width: 133,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PER MONTH',
                            style: TextStyle(
                              fontSize: 9,
                              color: Palette.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 7),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              money(store, total),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              final legend = Column(
                children: [
                  for (final entry in entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Semantics(
                        label:
                            '${entry.key.label}: ${money(store, entry.value)} per month, ${(entry.value / total * 100).toStringAsFixed(1)} percent of total',
                        excludeSemantics: true,
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
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${(entry.value / total * 100).round()}%',
                              style: const TextStyle(
                                color: Palette.muted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Text(
                              money(store, entry.value),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    Center(child: chart),
                    const SizedBox(height: 22),
                    legend,
                  ],
                );
              }
              return Row(
                children: [
                  chart,
                  const SizedBox(width: 26),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        const SizedBox(height: 4),
      ],
    ),
  );

  Widget _buildBudget(double total) {
    final budget = store.settings.budgetCents;
    final positiveBudget = budget > 0;
    final remaining = budget - total;
    final over = remaining < 0;
    final ratio = positiveBudget
        ? total / budget
        : over
        ? 1.0
        : 0.0;
    final budgetStatus = positiveBudget
        ? '${(ratio * 100).round()} percent'
        : over
        ? '${money(store, total)} above the zero-spend budget'
        : 'Zero-spend budget met';
    final guidance = !positiveBudget
        ? over
              ? 'Your budget is set to zero. Review your recurring costs below to meet your zero-spend target.'
              : 'Your zero-spend budget is on track. There are no recurring costs.'
        : over
        ? 'Review your largest commitments below to find room to save.'
        : '${(ratio * 100).round()}% of your monthly budget is allocated to subscriptions.';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Room in your budget',
            subtitle: 'Based on monthly equivalent spending',
            trailing: Icon(
              Icons.account_balance_wallet_outlined,
              color: Palette.green,
              size: 19,
            ),
          ),
          const SizedBox(height: 29),
          Text(
            money(store, remaining.abs()),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -.9,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            over ? 'above your monthly budget' : 'left in your monthly budget',
            style: const TextStyle(
              color: Palette.muted,
              fontSize: 12,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 26),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: Palette.background,
              color: over ? Palette.coral : Palette.green,
              semanticsLabel: 'Monthly budget used',
              semanticsValue: budgetStatus,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${money(store, total)} allocated',
                  style: const TextStyle(color: Palette.muted, fontSize: 10),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${money(store, budget)} budget',
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: Palette.muted, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 23),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: over ? const Color(0xFFFAF0EC) : Palette.lightGreen,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              guidance,
              style: TextStyle(
                fontSize: 11,
                color: over ? const Color(0xFFA3624E) : Palette.green,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecast(List<DateTime> months, List<double> amounts) {
    final maximum = amounts.fold<double>(0, math.max);
    final sum = amounts.fold<double>(0, (sum, value) => sum + value);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            title: 'The months ahead',
            subtitle: 'Scheduled charges from actual renewal dates',
            trailing: const Pill('6 months'),
          ),
          const SizedBox(height: 19),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(
                money(store, sum),
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8,
                ),
              ),
              const Text(
                'scheduled across these months',
                style: TextStyle(color: Palette.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 27),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 400;
              return SizedBox(
                height: 180 + MediaQuery.textScalerOf(context).scale(40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < months.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: narrow ? 4 : 13,
                          ),
                          child: Semantics(
                            label:
                                '${DateFormat.yMMMM().format(months[i])}, ${money(store, amounts[i])} in scheduled charges',
                            excludeSemantics: true,
                            child: Tooltip(
                              message:
                                  '${DateFormat.yMMMM().format(months[i])}: ${money(store, amounts[i])}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: 19,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        money(store, amounts[i], decimals: 0),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Palette.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    height: maximum > 0
                                        ? math.max(
                                            3.0,
                                            amounts[i] / maximum * 125,
                                          )
                                        : 3,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: i == 0
                                          ? Palette.green
                                          : Palette.lightGreen,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    DateFormat.MMM().format(months[i]),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: i == 0
                                          ? Palette.green
                                          : Palette.muted,
                                      fontWeight: i == 0
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${months[i].year}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 21),
          const Divider(),
          const SizedBox(height: 14),
          const Text(
            'Each bar shows a full calendar month, including past renewal dates in the current month. These are scheduled charges, not payment history. Annual renewals and months with extra weekly charges can create peaks. This projection assumes your current subscriptions continue.',
            style: TextStyle(color: Palette.muted, fontSize: 10, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildCycles(double total) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Your billing rhythm',
          subtitle: 'Compare cycles using their monthly equivalent',
        ),
        const SizedBox(height: 23),
        for (final cycle in BillingCycle.values) ...[
          Builder(
            builder: (context) {
              final subscriptions = store.billable
                  .where((subscription) => subscription.cycle == cycle)
                  .toList();
              final amount = subscriptions.fold<double>(
                0,
                (sum, subscription) => sum + subscription.monthlyCents,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          cycle.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${subscriptions.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Palette.muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          money(store, amount),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: total > 0
                            ? (amount / total).clamp(0.0, 1.0).toDouble()
                            : 0,
                        minHeight: 5,
                        backgroundColor: Palette.background,
                        color: Palette.green.withValues(alpha: .75),
                        semanticsLabel:
                            '${cycle.label} share of monthly spending',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    ),
  );

  Widget _buildConcentration(List<Subscription> subscriptions, double total) {
    final largest = subscriptions.take(3).toList();
    final subtotal = largest.fold<double>(
      0,
      (sum, subscription) => sum + subscription.monthlyCents,
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Your biggest commitments',
            subtitle: 'Ranked by monthly equivalent cost',
          ),
          const SizedBox(height: 20),
          if (largest.isEmpty)
            const EmptyState(
              title: 'Start with the full picture',
              message: 'Your largest subscriptions will appear here.',
              icon: Icons.stacked_bar_chart_rounded,
            )
          else ...[
            for (var index = 0; index < largest.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 19),
                child: Row(
                  children: [
                    SizedBox(
                      width: 19,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Palette.muted,
                        ),
                      ),
                    ),
                    ServiceIcon(largest[index], size: 33),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            largest[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            largest[index].category.label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Palette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${money(store, largest[index].monthlyCents)} / mo',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            const SizedBox(height: 17),
            Text(
              'Your top ${largest.length} ${largest.length == 1 ? 'subscription accounts' : 'subscriptions account'} for ${total > 0 ? (subtotal / total * 100).round() : 0}% of your recurring spending.',
              style: const TextStyle(
                fontSize: 11,
                color: Palette.muted,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });
  final String label, value, detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Palette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Icon(icon, size: 17, color: Palette.muted),
          ],
        ),
        const SizedBox(height: 19),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 10,
            color: Palette.muted,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class _CategoryDonut extends CustomPainter {
  _CategoryDonut(this.entries);
  final List<MapEntry<SubscriptionCategory, double>> entries;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 19.0;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width - stroke,
      height: size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final entry in entries) {
      final sweep = entry.value / total * math.pi * 2;
      final gap = entries.length > 1 ? math.min(.04, sweep * .2) : 0.0;
      paint.color = categoryColor(entry.key);
      canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonut oldDelegate) => true;
}
