import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import 'daily_menu_editor_dialog.dart';

/// Weekly daily-menu planner.
/// Displays a grid: rows = meal slots, columns = days of the week.
/// Each cell shows item count + status chip; tapping opens the editor dialog.
class DailyPlannerScreen extends StatefulWidget {
  const DailyPlannerScreen({super.key});

  @override
  State<DailyPlannerScreen> createState() => _DailyPlannerScreenState();
}

class _DailyPlannerScreenState extends State<DailyPlannerScreen> {
  final AdminRepository _repo = AdminRepository();

  bool _loading = true;
  String? _error;

  late DateTime _weekStart; // Monday
  List<MealSlot> _slots = [];
  List<DailyMenu> _menus = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final slots = await _repo.getMealSlots();
      final weekData = await _repo.getWeekMenus(
        DateFormat('yyyy-MM-dd').format(_weekStart),
      );
      final rawMenus = weekData['menus'] as List? ?? [];
      final menus =
          rawMenus.map((e) => DailyMenu.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _slots = slots;
          _menus = menus;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _load();
  }

  void _goToCurrentWeek() {
    final now = DateTime.now();
    setState(() => _weekStart = now.subtract(Duration(days: now.weekday - 1)));
    _load();
  }

  DailyMenu? _findMenu(DateTime date, int slotId) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    for (final m in _menus) {
      if (m.menuDate == dateStr && m.mealSlotId == slotId) return m;
    }
    return null;
  }

  Future<void> _openEditor(DateTime date, MealSlot slot, DailyMenu? existing) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => DailyMenuEditorDialog(
        date: date,
        mealSlot: slot,
        existingMenu: existing,
        repo: _repo,
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _publishMenu(DailyMenu menu) async {
    try {
      await _repo.publishDailyMenu(menu.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu published'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _closeMenu(DailyMenu menu) async {
    try {
      await _repo.closeDailyMenu(menu.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu closed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('MMM d');
    final label = '${fmt.format(_weekStart)} – ${fmt.format(weekEnd)}, ${_weekStart.year}';

    return Row(
      children: [
        Text(
          'Daily Planner',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          onPressed: _prevWeek,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous week',
        ),
        TextButton(
          onPressed: _goToCurrentWeek,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: _nextWeek,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next week',
        ),
        const SizedBox(width: 8),
        if (!_loading)
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_slots.isEmpty) {
      return const Center(child: Text('No meal slots configured.'));
    }

    return _buildWeekGrid();
  }

  Widget _buildWeekGrid() {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final dayFmt = DateFormat('EEE');
    final dateFmt = DateFormat('MMM d');

    return SingleChildScrollView(
      child: Table(
        border: TableBorder.all(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        columnWidths: {
          0: const FixedColumnWidth(90), // slot label column
          for (int i = 1; i <= 7; i++) i: const FlexColumnWidth(),
        },
        children: [
          // ── Header row (day names) ──
          TableRow(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            children: [
              _headerCell(''),
              for (final d in days)
                _headerCell(
                  '${dayFmt.format(d)}\n${dateFmt.format(d)}',
                  isToday: DateFormat('yyyy-MM-dd').format(d) == todayStr,
                ),
            ],
          ),
          // ── One row per meal slot ──
          for (final slot in _slots)
            TableRow(
              children: [
                _slotLabel(slot),
                for (final d in days)
                  _menuCell(d, slot, _findMenu(d, slot.id)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {bool isToday = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: isToday ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }

  Widget _slotLabel(MealSlot slot) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        slot.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }

  Widget _menuCell(DateTime date, MealSlot slot, DailyMenu? menu) {
    final Color bg;
    final String label;
    final Color labelColor;
    final IconData? icon;

    if (menu == null) {
      bg = Colors.grey.shade50;
      label = 'Empty';
      labelColor = Colors.grey;
      icon = Icons.add_circle_outline;
    } else {
      switch (menu.status) {
        case 'published':
          bg = Colors.green.shade50;
          label = '${menu.itemCount} items';
          labelColor = Colors.green.shade800;
          icon = Icons.check_circle;
        case 'closed':
          bg = Colors.grey.shade100;
          label = 'Closed';
          labelColor = Colors.grey.shade600;
          icon = Icons.lock;
        default: // draft
          bg = Colors.orange.shade50;
          label = menu.itemCount > 0 ? '${menu.itemCount} items' : 'Draft';
          labelColor = Colors.orange.shade800;
          icon = Icons.edit_note;
      }
    }

    return InkWell(
      onTap: () => _openEditor(date, slot, menu),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        color: bg,
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: labelColor),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: labelColor,
                fontWeight: FontWeight.w600,
                decoration: menu?.status == 'closed'
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (menu != null && menu.status == 'draft') ...[
              const SizedBox(height: 4),
              _statusChip('Draft', Colors.orange),
            ],
            if (menu != null && menu.status == 'published') ...[
              const SizedBox(height: 4),
              _statusChip('Published', Colors.green),
            ],
            if (menu != null) ...[
              const SizedBox(height: 4),
              _buildActionButtons(menu),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildActionButtons(DailyMenu menu) {
    final actions = <Widget>[];

    if (menu.status == 'draft') {
      actions.add(
        _tinyButton(Icons.publish, 'Publish', Colors.green, () => _publishMenu(menu)),
      );
    }
    if (menu.status == 'published') {
      actions.add(
        _tinyButton(Icons.lock, 'Close', Colors.grey, () => _closeMenu(menu)),
      );
    }
    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 2,
      children: actions,
    );
  }

  Widget _tinyButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
