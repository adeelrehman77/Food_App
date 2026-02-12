import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = AdminRepository();
  DashboardSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _repo.getDashboardSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final s = _summary!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Dashboard Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back! Here\'s what\'s happening today.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // ── Primary Metric Cards ──
          _buildCardGrid(context, [
            _MetricData(
              'Today\'s Orders',
              '${s.orders.today}',
              Icons.receipt_long_rounded,
              Colors.blue,
              onTap: () => context.go('/orders'),
            ),
            _MetricData(
              'Pending Orders',
              '${s.orders.pending}',
              Icons.hourglass_empty_rounded,
              Colors.orange,
              onTap: () => context.go('/orders'),
            ),
            _MetricData(
              'Today\'s Deliveries',
              '${s.deliveries.today}',
              Icons.local_shipping_rounded,
              Colors.teal,
              subtitle: '${s.deliveries.completed} completed',
              onTap: () => context.go('/delivery'),
            ),
            _MetricData(
              'Monthly Revenue',
              'AED ${s.revenue.monthly.toStringAsFixed(0)}',
              Icons.account_balance_wallet_rounded,
              Colors.green,
              onTap: () => context.go('/finance'),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Secondary Metric Cards ──
          _buildCardGrid(context, [
            _MetricData(
              'Total Customers',
              '${s.customers.total}',
              Icons.people_rounded,
              Colors.indigo,
              subtitle: '${s.customers.activeSubscriptions} active subs',
              onTap: () => context.go('/customers'),
            ),
            _MetricData(
              'Pending Registrations',
              '${s.customers.pendingRegistrations}',
              Icons.person_add_rounded,
              Colors.purple,
              onTap: () => context.go('/customers'),
            ),
            _MetricData(
              'Low Stock Items',
              '${s.inventory.lowStockCount}',
              Icons.inventory_2_rounded,
              s.inventory.lowStockCount > 0 ? Colors.red : Colors.grey,
              onTap: () => context.go('/inventory'),
            ),
            _MetricData(
              'Staff Members',
              '${s.staff.total}',
              Icons.badge_rounded,
              Colors.blueGrey,
              onTap: () => context.go('/staff'),
            ),
          ]),
          const SizedBox(height: 16),

          // ── Invoice Alerts ──
          if (s.revenue.pendingInvoices > 0 || s.revenue.overdueInvoices > 0)
            Card(
              color: s.revenue.overdueInvoices > 0
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: s.revenue.overdueInvoices > 0
                      ? Colors.red
                      : Colors.orange,
                ),
                title: Text(
                  s.revenue.overdueInvoices > 0
                      ? '${s.revenue.overdueInvoices} overdue invoice(s)'
                      : '${s.revenue.pendingInvoices} pending invoice(s)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Tap to view invoices'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/finance'),
              ),
            ),
          const SizedBox(height: 24),

          // ── Recent Orders ──
          Text(
            'Recent Orders',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          if (s.recentOrders.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No orders yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              ),
            )
          else
            Card(
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Colors.grey.shade100,
                  ),
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: s.recentOrders.map((o) {
                    return DataRow(cells: [
                      DataCell(Text('#${o.id}')),
                      DataCell(Text(o.customerName ?? '—')),
                      DataCell(Text(o.deliveryDate ?? o.orderDate ?? '—')),
                      DataCell(Text('${o.quantity}')),
                      DataCell(_StatusChip(o.status)),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardGrid(BuildContext context, List<_MetricData> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: metrics.map((m) => _MetricCard(data: m)).toList(),
        );
      },
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  _MetricData(
    this.title,
    this.value,
    this.icon,
    this.color, {
    this.subtitle,
    this.onTap,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        data.value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (data.subtitle != null) ...[
                      Text(
                        data.subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (status) {
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'confirmed' => (Colors.blue.shade800, Colors.blue.shade50),
      'preparing' => (Colors.purple.shade800, Colors.purple.shade50),
      'ready' => (Colors.teal.shade800, Colors.teal.shade50),
      'delivered' => (Colors.green.shade800, Colors.green.shade50),
      'cancelled' => (Colors.red.shade800, Colors.red.shade50),
      _ => (Colors.grey.shade800, Colors.grey.shade100),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
