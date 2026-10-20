import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/app_store.dart';
import '../core/file_transfer.dart';
import '../core/models.dart';
import 'calendar_page.dart';
import 'dashboard_page.dart';
import 'design.dart';
import 'insights_page.dart';
import 'settings_page.dart';
import 'subscription_editor.dart';
import 'subscriptions_page.dart';
import 'tools_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AppStore store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _page = 0;
  String _query = '';
  final _scroll = ScrollController();
  final _search = TextEditingController();
  static const _names = [
    'Overview',
    'Subscriptions',
    'Renewal calendar',
    'Insights',
    'Smart tools',
    'Settings',
  ];
  static const _icons = [
    Icons.grid_view_outlined,
    Icons.layers_outlined,
    Icons.calendar_month_outlined,
    Icons.bar_chart_rounded,
    Icons.tune_rounded,
    Icons.settings_outlined,
  ];

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _navigate(int page) {
    setState(() {
      _page = page;
      if (page != 1) {
        _query = '';
        _search.clear();
      }
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _edit([Subscription? item]) =>
      openSubscriptionEditor(context, widget.store, subscription: item);

  void _performSearch(String query) {
    setState(() {
      _query = query.trim();
      _page = 1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _exportCalendar() async {
    try {
      await deliverFile(
        context,
        content: widget.store.exportCalendar(),
        filename: 'tally-renewals.ics',
        mimeType: 'text/calendar',
      );
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Calendar export failed. Check file permissions and try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
          _navigate(1),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
          _edit(),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
          _navigate(1),
    },
    child: Focus(
      autofocus: true,
      child: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final store = widget.store;
          final wide = MediaQuery.sizeOf(context).width >= 1040;
          final content = switch (_page) {
            0 => DashboardPage(
              store: store,
              onAdd: () => _edit(),
              onSelect: _edit,
              onNavigate: _navigate,
            ),
            1 => SubscriptionsPage(
              key: ValueKey(_query),
              store: store,
              onAdd: () => _edit(),
              onSelect: _edit,
              initialQuery: _query,
            ),
            2 => CalendarPage(
              store: store,
              onSelect: _edit,
              onExport: _exportCalendar,
            ),
            3 => InsightsPage(store: store),
            4 => ToolsPage(store: store),
            _ => SettingsPage(store: store),
          };
          return Scaffold(
            body: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide) _sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        _header(wide),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scroll,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1380,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 34 : 20,
                                    wide ? 30 : 24,
                                    wide ? 34 : 20,
                                    28,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (store.storageError != null) ...[
                                        _storageNotice(),
                                        const SizedBox(height: 20),
                                      ],
                                      if (store.isDemo) ...[
                                        _demoNotice(),
                                        const SizedBox(height: 23),
                                      ],
                                      content,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _page < 5 ? _page : 0,
                    onDestinationSelected: _navigate,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        label: 'Overview',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.layers_outlined),
                        label: 'Plans',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        label: 'Calendar',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.bar_chart_rounded),
                        label: 'Insights',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.tune_rounded),
                        label: 'Tools',
                      ),
                    ],
                  ),
          );
        },
      ),
    ),
  );

  Widget _header(bool wide) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: wide ? 34 : 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Palette.border)),
    ),
    child: Row(
      children: [
        if (wide) ...[
          const Text(
            'Workspace',
            style: TextStyle(fontSize: 11, color: Palette.muted),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('/', style: TextStyle(color: Palette.border)),
          ),
          Text(
            _names[_page],
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ] else
          const _Brand(compact: true),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width > 760) ...[
          SizedBox(
            width: 204,
            child: TextField(
              controller: _search,
              onSubmitted: _performSearch,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Search subscriptions…',
                hintStyle: const TextStyle(fontSize: 10, color: Palette.muted),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: Palette.muted,
                ),
                fillColor: Palette.background,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(7),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
        ] else
          IconButton(
            tooltip: 'Search subscriptions',
            onPressed: () => _navigate(1),
            icon: const Icon(Icons.search_rounded, size: 20),
          ),
        IconButton(
          tooltip: 'Renewal inbox',
          onPressed: _showRenewals,
          icon: Badge(
            isLabelVisible: widget.store.upcoming(7).isNotEmpty,
            smallSize: 5,
            backgroundColor: Palette.coral,
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: Palette.ink,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (!wide)
          IconButton(
            tooltip: 'Settings',
            onPressed: () => _navigate(5),
            icon: const Icon(Icons.settings_outlined, size: 20),
          )
        else ...[
          Container(width: 1, height: 23, color: Palette.border),
          const SizedBox(width: 22),
          const Icon(
            Icons.calendar_today_outlined,
            size: 13,
            color: Palette.muted,
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('d MMM yyyy').format(widget.store.today),
            style: const TextStyle(fontSize: 10, color: Palette.muted),
          ),
        ],
      ],
    ),
  );

  Widget _sidebar() => Container(
    width: 222,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: Palette.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(27, 25, 24, 34),
          child: _Brand(),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(26, 8, 24, 13),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.3,
              color: Palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...List.generate(4, _navItem),
        const Padding(
          padding: EdgeInsets.fromLTRB(26, 31, 24, 13),
          child: Text(
            'MAKE IT YOURS',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 1.3,
              color: Palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _navItem(4),
        _navItem(5),
        const Spacer(),
        if (MediaQuery.sizeOf(context).height > 680)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.filter_vintage_outlined,
                    size: 24,
                    color: Palette.green,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Less overhead.\nMore living.',
                    style: TextStyle(
                      fontFamily: 'Newsreader',
                      fontSize: 24,
                      height: 1.15,
                      color: Palette.green,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Small subscriptions add up.\nA little awareness goes a long way.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.8,
                      color: Palette.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _navigate(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        'Find your savings  ↗',
                        style: TextStyle(
                          color: Palette.green,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const Divider(),
        InkWell(
          onTap: () => _navigate(5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE9DFCE),
                  child: Text(
                    _initials(widget.store.settings.displayName),
                    style: const TextStyle(
                      color: Color(0xFF7D6C4E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.store.settings.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Personal workspace',
                        style: TextStyle(fontSize: 9, color: Palette.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 16,
                  color: Palette.muted,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _navItem(int index) {
    final selected = _page == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: selected ? Palette.lightGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () => _navigate(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Icon(
                  _icons[index],
                  size: 18,
                  color: selected ? Palette.green : Palette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _names[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? Palette.green : Palette.muted,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (index == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Palette.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${widget.store.subscriptions.length}',
                      style: const TextStyle(fontSize: 9, color: Palette.muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demoNotice() => LayoutBuilder(
    builder: (context, constraints) {
      const badge = Pill(
        'SAMPLE WORKSPACE',
        background: Color(0xFFEEECE6),
        color: Color(0xFF83765B),
      );
      const description = Text(
        'A few familiar subscriptions to show you around.',
        style: TextStyle(color: Palette.muted, fontSize: 10),
      );
      final action = TextButton(
        onPressed: () => _navigate(5),
        child: const Text('Make it yours →'),
      );
      if (constraints.maxWidth < 600) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [badge, action],
            ),
            const SizedBox(height: 4),
            description,
          ],
        );
      }
      return Row(
        children: [
          badge,
          const SizedBox(width: 9),
          const Expanded(child: description),
          action,
        ],
      );
    },
  );

  Widget _storageNotice() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEE7),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.store.storageError!,
          style: const TextStyle(color: Color(0xFF8C3C2C), fontSize: 12),
        ),
        TextButton(
          onPressed: () => _navigate(5),
          child: const Text('Open backup and recovery'),
        ),
      ],
    ),
  );

  Future<void> _showRenewals() async {
    final upcoming = widget.store.upcoming(7);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your renewal inbox'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled in the next 7 days. Import your calendar export to receive reminders in your calendar app.',
                  style: TextStyle(color: Palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                if (upcoming.isEmpty)
                  const EmptyState(
                    title: 'Nothing on the horizon',
                    message: 'You have no renewals in the next 7 days.',
                    icon: Icons.event_available_outlined,
                  ),
                ...upcoming.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ServiceIcon(item),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      DateFormat(
                        'EEE, MMM d',
                      ).format(item.nextRenewal(widget.store.today)),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                      ),
                    ),
                    trailing: Text(
                      money(widget.store, item.amountCents),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      _edit(item);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _exportCalendar();
            },
            child: const Text('Export calendar'),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .take(2)
    .map((word) => word.characters.first.toUpperCase())
    .join();

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 29 : 33,
        height: compact ? 29 : 33,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(height: 12, width: 3, color: const Color(0xFFD4E0C8)),
            const SizedBox(width: 3),
            Container(height: 18, width: 3, color: Colors.white),
            const SizedBox(width: 3),
            Container(height: 15, width: 3, color: const Color(0xFFD4E0C8)),
          ],
        ),
      ),
      const SizedBox(width: 9),
      Text(
        'tally',
        style: TextStyle(
          fontSize: compact ? 26 : 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.4,
          height: 1,
        ),
      ),
    ],
  );
}
