import 'package:flutter/material.dart';

import '../../models/api_models.dart';
import '../../services/zedgift_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import '../../widgets/app_header.dart';
import '../../widgets/search_field.dart';

/// Icon + accent colour for an activity's module (log_name).
({IconData icon, Color color}) moduleStyle(String module) {
  switch (module.toLowerCase()) {
    case 'advance':
      return (icon: Icons.account_balance_wallet_rounded, color: Color(0xFFE8923B));
    case 'loan':
      return (icon: Icons.account_balance_rounded, color: Color(0xFF2BB673));
    case 'salary':
      return (icon: Icons.payments_rounded, color: Color(0xFF8B5CF6));
    case 'leave':
      return (icon: Icons.calendar_month_rounded, color: Color(0xFF7C5CFC));
    case 'deduction':
      return (icon: Icons.remove_circle_outline_rounded, color: AppColors.primary);
    case 'attendance':
    case 'punch':
      return (icon: Icons.fingerprint_rounded, color: Color(0xFF3B82C4));
    case 'employee':
      return (icon: Icons.groups_2_rounded, color: AppColors.primary);
    case 'feedback':
      return (icon: Icons.chat_bubble_outline_rounded, color: Color(0xFF3B82C4));
    default:
      return (icon: Icons.history_rounded, color: AppColors.textSecondary);
  }
}

/// Label + colours for an activity's event (created / updated / deleted).
({String label, Color color, Color bg}) _eventStyle(String event) {
  switch (event.toLowerCase()) {
    case 'created':
      return (label: 'Created', color: Color(0xFF2BB673), bg: Color(0xFFE7F7EF));
    case 'updated':
      return (label: 'Updated', color: Color(0xFFE8923B), bg: Color(0xFFFCEFE0));
    case 'deleted':
      return (label: 'Deleted', color: AppColors.primary, bg: AppColors.softRedTint);
    default:
      return (
        label: event.isEmpty ? 'Log' : event,
        color: AppColors.textSecondary,
        bg: Color(0xFFEDEFF4),
      );
  }
}

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "11:49 AM" from a DateTime.
String _timeLabel(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Card for a single activity-log row. Shared by the home feed and the full
/// Activity Logs page. [compact] shrinks it for the home dashboard.
class ActivityLogCard extends StatelessWidget {
  const ActivityLogCard({super.key, required this.log, this.compact = false});

  final ActivityLog log;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final m = moduleStyle(log.module);
    final e = _eventStyle(log.event);
    final detail = log.detail;

    // Size tokens — everything smaller in compact (home) mode.
    final pad = compact ? 9.0 : 13.0;
    final tile = compact ? 28.0 : 40.0;
    final iconSize = compact ? 15.0 : 20.0;
    final gap = compact ? 8.0 : 11.0;
    final titleSize = compact ? 11.5 : 13.5;
    final detailSize = compact ? 10.0 : 11.5;
    final metaSize = compact ? 9.5 : 11.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(compact ? 13 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module icon tile.
          Container(
            width: tile,
            height: tile,
            decoration: BoxDecoration(
              color: m.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 9 : 12),
            ),
            child: Icon(m.icon, color: m.color, size: iconSize),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        log.text,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _eventBadge(e),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  SizedBox(height: compact ? 2 : 5),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: detailSize,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                SizedBox(height: compact ? 3 : 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: compact ? 10.5 : 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      log.dateTime == null
                          ? log.rawDate
                          : '${log.dateTime!.day} ${_monthsShort[log.dateTime!.month - 1]}, ${_timeLabel(log.dateTime!)}',
                      style:
                          TextStyle(fontSize: metaSize, color: AppColors.textMuted),
                    ),
                    if (log.causer.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline_rounded,
                          size: compact ? 10.5 : 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          log.causer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: metaSize, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventBadge(({String label, Color color, Color bg}) e) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 9, vertical: compact ? 2.5 : 4),
      decoration: BoxDecoration(
        color: e.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        e.label,
        style: TextStyle(
          fontSize: compact ? 9 : 10.5,
          fontWeight: FontWeight.w700,
          color: e.color,
        ),
      ),
    );
  }
}

/// Full activity feed — grouped by day, filterable by module, with a search
/// box and infinite-scroll pagination over `GET /activity-logs/summary`.
class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();

  final List<ActivityLog> _all = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  String? _filter; // null = All
  String _q = '';

  // (label, module-key-or-null, icon, colour)
  static const _chips = <(String, String?, IconData, Color)>[
    ('All', null, Icons.dashboard_rounded, AppColors.primary),
    ('Advance', 'advance', Icons.account_balance_wallet_rounded, Color(0xFFE8923B)),
    ('Loan', 'loan', Icons.account_balance_rounded, Color(0xFF2BB673)),
    ('Salary', 'salary', Icons.payments_rounded, Color(0xFF8B5CF6)),
    ('Leave', 'leave', Icons.calendar_month_rounded, Color(0xFF7C5CFC)),
    ('Deduction', 'deduction', Icons.remove_circle_outline_rounded, AppColors.primary),
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ZedgiftApi.instance.activityLogs(page: 1);
      if (!mounted) return;
      setState(() {
        _all
          ..clear()
          ..addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _total = res.total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load activity logs.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading) return;
    if (_page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await ZedgiftApi.instance.activityLogs(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _all.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<ActivityLog> get _filtered {
    final q = _q.trim().toLowerCase();
    return _all.where((l) {
      if (_filter != null && l.module != _filter) return false;
      if (q.isEmpty) return true;
      return l.text.toLowerCase().contains(q) ||
          l.causer.toLowerCase().contains(q) ||
          l.module.toLowerCase().contains(q) ||
          l.detail.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      bottomNavigationBar: AdminBottomNav(
        currentIndex: 0,
        onTap: (i) => goToAdminTab(context, i),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppHeader(leadingIcon: Icons.arrow_back),
            _titleRow(),
            _searchBar(),
            const SizedBox(height: 10),
            _filterChips(),
            const SizedBox(height: 10),
            Expanded(child: _listArea()),
          ],
        ),
      ),
    );
  }

  Widget _titleRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity Logs',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Daily audit trail of all changes',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (_total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.softRedTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_total total',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SearchField(
        controller: _searchCtl,
        hint: 'Search activity, employee or user...',
        hasText: _q.isNotEmpty,
        onChanged: (v) => setState(() => _q = v),
        onClear: () {
          _searchCtl.clear();
          setState(() => _q = '');
        },
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, key, icon, accent) = _chips[i];
          final selected = _filter == key;
          return Material(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filter = key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.fieldBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 16, color: selected ? Colors.white : accent),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _listArea() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final list = _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text('No activity found.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    // Build a flat list where date-header strings are interleaved with rows.
    final rows = <Object>[];
    String? lastDay;
    for (final l in list) {
      final day = _dayLabel(l.dateTime);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(l);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: rows.length + 1, // +1 footer (loader / end)
        itemBuilder: (context, i) {
          if (i == rows.length) return _footer();
          final row = rows[i];
          if (row is String) return _dayHeader(row);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActivityLogCard(log: row as ActivityLog),
          );
        },
      ),
    );
  }

  Widget _dayHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppColors.primary),
          ),
        ),
      );
    }
    if (_page >= _lastPage && _filter == null && _q.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text('— End of activity —',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ),
      );
    }
    return const SizedBox(height: 8);
  }

  /// "Today" / "Yesterday" / "6 Jul 2026".
  String _dayLabel(DateTime? t) {
    if (t == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${t.day} ${_monthsShort[t.month - 1]} ${t.year}';
  }
}
