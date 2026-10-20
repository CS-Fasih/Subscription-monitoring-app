import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_store.dart';
import '../core/models.dart';
import 'design.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({
    super.key,
    required this.store,
    required this.onAdd,
    required this.onSelect,
    this.initialQuery = '',
  });

  final AppStore store;
  final VoidCallback onAdd;
  final ValueChanged<Subscription> onSelect;
  final String initialQuery;

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

enum _SortOrder { renewal, amount, name }

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  late final TextEditingController _search;
  SubscriptionCategory? _category;
  SubscriptionStatus? _status;
  _SortOrder _sort = _SortOrder.renewal;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didUpdateWidget(covariant SubscriptionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery) {
      _search.text = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Subscription> get _filtered {
    final query = _search.text.trim().toLowerCase();
    final entries = widget.store.subscriptions.where((item) {
      return (_category == null || item.category == _category) &&
          (_status == null || item.status == _status) &&
          (query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.note.toLowerCase().contains(query));
    }).toList();
    entries.sort((a, b) {
      // Archived plans follow subscriptions with a real upcoming charge.
      if (_sort == _SortOrder.renewal && a.isBillable != b.isBillable) {
        return a.isBillable ? -1 : 1;
      }
      final order = switch (_sort) {
        _SortOrder.renewal =>
          a
              .nextRenewal(widget.store.today)
              .compareTo(b.nextRenewal(widget.store.today)),
        _SortOrder.amount => b.monthlyCents.compareTo(a.monthlyCents),
        _SortOrder.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return order == 0 ? a.name.compareTo(b.name) : order;
    });
    return entries;
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _category = null;
    _status = null;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final items = _filtered;
      final hasFilters =
          _search.text.isNotEmpty || _category != null || _status != null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            title: 'Your subscriptions',
            subtitle: 'A little more clarity on everything you subscribe to.',
            action: FilledButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text('Add subscription'),
            ),
          ),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeading(
                        title: 'Subscription library',
                        subtitle:
                            '${widget.store.subscriptions.length} total · '
                            '${widget.store.activeCount} active or on trial',
                        trailing: const Icon(
                          Icons.layers_outlined,
                          size: 20,
                          color: Palette.muted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final search = TextField(
                            controller: _search,
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Search subscriptions',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () => setState(_search.clear),
                                      tooltip: 'Clear search',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                      ),
                                    ),
                            ),
                          );
                          final category = DropdownButtonFormField<String>(
                            initialValue: _category?.name ?? 'all',
                            key: ValueKey(_category),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All categories'),
                              ),
                              ...SubscriptionCategory.values.map(
                                (value) => DropdownMenuItem(
                                  value: value.name,
                                  child: Text(value.label),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _category = value == 'all'
                                  ? null
                                  : SubscriptionCategory.values.byName(value!);
                            }),
                          );
                          final sort = DropdownButtonFormField<_SortOrder>(
                            initialValue: _sort,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sort by',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: _SortOrder.renewal,
                                child: Text('Next renewal'),
                              ),
                              DropdownMenuItem(
                                value: _SortOrder.amount,
                                child: Text('Monthly cost'),
                              ),
                              DropdownMenuItem(
                                value: _SortOrder.name,
                                child: Text('Name A–Z'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _sort = value!),
                          );
                          if (constraints.maxWidth < 680) {
                            return Column(
                              children: [
                                search,
                                const SizedBox(height: 14),
                                if (constraints.maxWidth < 330) ...[
                                  category,
                                  const SizedBox(height: 14),
                                  sort,
                                ] else
                                  Row(
                                    children: [
                                      Expanded(child: category),
                                      const SizedBox(width: 12),
                                      Expanded(child: sort),
                                    ],
                                  ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: category),
                              const SizedBox(width: 14),
                              Expanded(flex: 2, child: sort),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 17),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusChip(null, 'All subscriptions'),
                          ...SubscriptionStatus.values.map(
                            (status) => _statusChip(status, status.label),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (items.isEmpty)
                  EmptyState(
                    title: hasFilters
                        ? 'No matching subscriptions'
                        : 'Make room for a clearer picture',
                    message: hasFilters
                        ? 'Try a different search or remove a filter.'
                        : 'Add your first subscription to keep its cost and renewal in view.',
                    action: hasFilters
                        ? OutlinedButton(
                            onPressed: _clearFilters,
                            child: const Text('Clear filters'),
                          )
                        : FilledButton(
                            onPressed: widget.onAdd,
                            child: const Text('Add your first subscription'),
                          ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 760) {
                        return Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              _mobileRow(items[i]),
                              if (i < items.length - 1)
                                const Divider(indent: 22, endIndent: 22),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Container(
                            color: const Color(0xFFFCFDFC),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 34,
                                  child: _ColumnTitle('SUBSCRIPTION'),
                                ),
                                Expanded(
                                  flex: 20,
                                  child: _ColumnTitle('CATEGORY'),
                                ),
                                Expanded(
                                  flex: 20,
                                  child: _ColumnTitle('NEXT RENEWAL'),
                                ),
                                Expanded(flex: 20, child: _ColumnTitle('COST')),
                                Expanded(
                                  flex: 16,
                                  child: _ColumnTitle('STATUS'),
                                ),
                                SizedBox(width: 20),
                              ],
                            ),
                          ),
                          const Divider(),
                          for (var i = 0; i < items.length; i++) ...[
                            _desktopRow(items[i]),
                            if (i < items.length - 1)
                              const Divider(indent: 24, endIndent: 24),
                          ],
                        ],
                      );
                    },
                  ),
                if (items.isNotEmpty) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 17,
                    ),
                    child: Text(
                      'Showing ${items.length} of ${widget.store.subscriptions.length} subscriptions',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Paused and cancelled subscriptions are excluded from spending totals.',
            style: TextStyle(fontSize: 11, color: Palette.muted),
          ),
        ],
      );
    },
  );

  Widget _statusChip(SubscriptionStatus? status, String label) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    selected: _status == status,
    showCheckmark: false,
    selectedColor: Palette.lightGreen,
    backgroundColor: Colors.white,
    labelStyle: TextStyle(
      color: _status == status ? Palette.green : Palette.muted,
    ),
    onSelected: (_) => setState(() => _status = status),
  );

  Widget _desktopRow(Subscription item) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => widget.onSelect(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          children: [
            Expanded(
              flex: 34,
              child: Row(
                children: [
                  ServiceIcon(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.note.isEmpty ? item.cycle.label : item.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                item.category.label,
                style: const TextStyle(fontSize: 11, color: Palette.muted),
              ),
            ),
            Expanded(flex: 20, child: _renewal(item)),
            Expanded(flex: 20, child: _cost(item)),
            Expanded(
              flex: 16,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _statusPill(item.status),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Palette.muted,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mobileRow(Subscription item) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => widget.onSelect(item),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                ServiceIcon(item),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.category.label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _cost(item, rightAlign: true),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _renewal(item)),
                _statusPill(item.status),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Palette.muted,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _cost(Subscription item, {bool rightAlign = false}) => Column(
    crossAxisAlignment: rightAlign
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        money(widget.store, item.amountCents),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 3),
      Text(
        '/ ${item.cycle.shortLabel}',
        style: const TextStyle(fontSize: 10, color: Palette.muted),
      ),
    ],
  );

  Widget _renewal(Subscription item) {
    if (!item.isBillable) {
      return const Text(
        'Not scheduled',
        style: TextStyle(fontSize: 11, color: Palette.muted),
      );
    }
    final next = item.nextRenewal(widget.store.today);
    final today = widget.store.today;
    final days = DateTime.utc(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMM d, y').format(next),
          style: const TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          days == 0
              ? 'Today'
              : days == 1
              ? 'Tomorrow'
              : 'In $days days',
          style: TextStyle(
            fontSize: 10,
            color: days <= 3 ? Palette.green : Palette.muted,
          ),
        ),
      ],
    );
  }

  Widget _statusPill(SubscriptionStatus status) => switch (status) {
    SubscriptionStatus.active => Pill(status.label, dot: true),
    SubscriptionStatus.trial => Pill(
      status.label,
      color: const Color(0xFF9A742A),
      background: const Color(0xFFFBF4E5),
      dot: true,
    ),
    SubscriptionStatus.paused => Pill(
      status.label,
      color: const Color(0xFF657B8E),
      background: const Color(0xFFEEF3F7),
      dot: true,
    ),
    SubscriptionStatus.cancelled => Pill(
      status.label,
      color: Palette.muted,
      background: const Color(0xFFF0F2F1),
      dot: true,
    ),
  };
}

class _ColumnTitle extends StatelessWidget {
  const _ColumnTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      letterSpacing: .7,
      fontWeight: FontWeight.w500,
      color: Palette.muted,
    ),
  );
}
