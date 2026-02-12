import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabCtrl;

  final _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Pending'),
    Tab(text: 'In Transit'),
    Tab(text: 'Delivered'),
    Tab(text: 'Failed'),
  ];
  final _statusFilters = [null, 'pending', 'in_transit', 'delivered', 'failed'];

  List<DeliveryItem> _deliveries = [];
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
      final items = await _repo.getDeliveries(
        status: _statusFilters[_tabCtrl.index],
      );
      if (mounted) setState(() => _deliveries = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
                      'Deliveries',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track and manage meal deliveries',
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
                  : _deliveries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_shipping, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No deliveries found',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deliveries.length,
                            itemBuilder: (context, index) {
                              return _DeliveryCard(delivery: _deliveries[index]);
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryItem delivery;
  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_statusIcon, color: _statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery #${delivery.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #${delivery.orderId ?? '—'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Driver: ${delivery.driverName?.isNotEmpty == true ? delivery.driverName : 'Unassigned'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (delivery.notes != null && delivery.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      delivery.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(delivery.status),
                if (delivery.pickupTime != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pickup: ${_formatTime(delivery.pickupTime!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
                if (delivery.deliveryTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Delivered: ${_formatTime(delivery.deliveryTime!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _statusColor => switch (delivery.status) {
        'pending' => Colors.orange,
        'in_transit' => Colors.blue,
        'delivered' => Colors.green,
        'failed' => Colors.red,
        _ => Colors.grey,
      };

  IconData get _statusIcon => switch (delivery.status) {
        'pending' => Icons.schedule,
        'in_transit' => Icons.local_shipping,
        'delivered' => Icons.check_circle,
        'failed' => Icons.error,
        _ => Icons.help_outline,
      };

  String _formatTime(String dt) {
    try {
      final parsed = DateTime.parse(dt);
      return '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final label = status.replaceAll('_', ' ');
    final (color, bgColor) = switch (status) {
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'in_transit' => (Colors.blue.shade800, Colors.blue.shade50),
      'delivered' => (Colors.green.shade800, Colors.green.shade50),
      'failed' => (Colors.red.shade800, Colors.red.shade50),
      _ => (Colors.grey.shade800, Colors.grey.shade100),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
