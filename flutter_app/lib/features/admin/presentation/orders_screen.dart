import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabCtrl;

  final _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Pending'),
    Tab(text: 'Confirmed'),
    Tab(text: 'Preparing'),
    Tab(text: 'Ready'),
    Tab(text: 'Delivered'),
    Tab(text: 'Cancelled'),
  ];
  final _statusFilters = [
    null,
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'delivered',
    'cancelled',
  ];

  List<OrderItem> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _repo.getOrders(
        status: _statusFilters[_tabCtrl.index],
      );
      if (mounted) setState(() => _orders = orders);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(OrderItem order, String newStatus) async {
    try {
      await _repo.updateOrderStatus(order.id, newStatus);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.id} → $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Orders',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage and track all customer orders',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: _tabs,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabAlignment: TabAlignment.start,
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: Colors.red[700])),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No orders found',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              return _OrderCard(
                                order: _orders[index],
                                onUpdateStatus: _updateStatus,
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderItem order;
  final Future<void> Function(OrderItem, String) onUpdateStatus;

  const _OrderCard({required this.order, required this.onUpdateStatus});

  /// True when delivery_date is today (preparing/ready only allowed then).
  static bool _isDueToday(OrderItem order) {
    final d = order.deliveryDate;
    if (d == null || d.isEmpty) return false;
    try {
      final delivery = DateTime.parse(d);
      final now = DateTime.now();
      return delivery.year == now.year &&
          delivery.month == now.month &&
          delivery.day == now.day;
    } catch (_) {
      return false;
    }
  }

  List<String> _nextStatuses() {
    final dueToday = _isDueToday(order);
    final raw = switch (order.status) {
      'pending' => ['confirmed', 'cancelled'],
      'confirmed' => ['preparing', 'cancelled'],
      'preparing' => ['ready', 'cancelled'],
      'ready' => ['delivered'],
      _ => <String>[],
    };
    // Only allow preparing/ready when delivery date is today
    if (!dueToday) {
      return raw.where((s) => s != 'preparing' && s != 'ready').toList();
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final nextStatuses = _nextStatuses();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                _StatusChip(order.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(order.customerName ?? 'Unknown',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 20),
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(order.customerPhone ?? '—',
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Delivery: ${order.deliveryDate ?? order.orderDate ?? '—'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                const SizedBox(width: 20),
                const Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Qty: ${order.quantity}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                if (order.subscriptionId != null) ...[
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.card_membership, size: 12, color: Colors.deepOrange[400]),
                      const SizedBox(width: 4),
                      Text('Sub #${order.subscriptionId}',
                          style: TextStyle(fontSize: 11, color: Colors.deepOrange[700], fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ],
              ],
            ),
            if (order.specialInstructions != null &&
                order.specialInstructions!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${order.specialInstructions}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
            if (nextStatuses.isNotEmpty ||
                (order.status == 'confirmed' &&
                    !_OrderCard._isDueToday(order))) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (order.status == 'confirmed' &&
                  !_OrderCard._isDueToday(order) &&
                  order.deliveryDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Preparing & Ready available on delivery day (${order.deliveryDate})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (nextStatuses.isNotEmpty)
              Wrap(
                spacing: 8,
                children: nextStatuses.map((s) {
                  final isCancel = s == 'cancelled';
                  return isCancel
                      ? OutlinedButton(
                          onPressed: () => onUpdateStatus(order, s),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Cancel'),
                        )
                      : FilledButton(
                          onPressed: () => onUpdateStatus(order, s),
                          child: Text(
                            s[0].toUpperCase() + s.substring(1),
                          ),
                        );
                }).toList(),
              ),
            ],
          ],
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
