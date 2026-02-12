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
  late final TabController _tabCtrl;

  final _tabs = const [
    Tab(text: 'Deliveries'),
    Tab(text: 'Drivers'),
    Tab(text: 'Zones & Routes'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery Management',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage deliveries, drivers, zones and routes',
                style: TextStyle(color: Colors.grey[600]),
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
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _DeliveriesTab(),
              _DriversTab(),
              _ZonesRoutesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DELIVERIES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _DeliveriesTab extends StatefulWidget {
  const _DeliveriesTab();

  @override
  State<_DeliveriesTab> createState() => _DeliveriesTabState();
}

class _DeliveriesTabState extends State<_DeliveriesTab> {
  final _repo = AdminRepository();
  List<DeliveryItem> _deliveries = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter;

  final _statusOptions = ['All', 'Pending', 'In Transit', 'Delivered', 'Failed'];
  final _statusValues = [null, 'pending', 'in_transit', 'delivered', 'failed'];

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
      final items = await _repo.getDeliveries(status: _statusFilter);
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
      children: [
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_statusOptions.length, (i) {
                      final selected = _statusFilter == _statusValues[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(_statusOptions[i]),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _statusFilter = _statusValues[i]);
                            _load();
                          },
                          selectedColor:
                              Theme.of(context).primaryColor.withValues(alpha: 0.15),
                          checkmarkColor: Theme.of(context).primaryColor,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : _deliveries.isEmpty
                      ? _EmptyView(
                          icon: Icons.local_shipping,
                          message: 'No deliveries found',
                          subtitle:
                              'Deliveries will appear here when orders are placed',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deliveries.length,
                            itemBuilder: (_, i) =>
                                _DeliveryCard(delivery: _deliveries[i], onRefresh: _load),
                          ),
                        ),
        ),
      ],
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryItem delivery;
  final VoidCallback onRefresh;
  const _DeliveryCard({required this.delivery, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDeliveryDetails(context),
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
                          fontWeight: FontWeight.bold, fontSize: 15),
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
                        Expanded(
                          child: Text(
                            delivery.driverName?.isNotEmpty == true
                                ? delivery.driverName!
                                : 'Unassigned',
                            style: TextStyle(
                              fontSize: 13,
                              color: delivery.driverName?.isNotEmpty == true
                                  ? Colors.grey[700]
                                  : Colors.orange[700],
                              fontWeight: delivery.driverName?.isNotEmpty == true
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (delivery.customerName?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.restaurant, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            delivery.customerName!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
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
                      'Pickup: ${_fmtTime(delivery.pickupTime!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  if (delivery.deliveryTime != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Delivered: ${_fmtTime(delivery.deliveryTime!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeliveryDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DeliveryDetailSheet(
        delivery: delivery,
        onRefresh: onRefresh,
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

  String _fmtTime(String dt) {
    try {
      final parsed = DateTime.parse(dt);
      return '${parsed.hour.toString().padLeft(2, '0')}:'
          '${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dt;
    }
  }
}

class _DeliveryDetailSheet extends StatelessWidget {
  final DeliveryItem delivery;
  final VoidCallback onRefresh;
  const _DeliveryDetailSheet({required this.delivery, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Delivery #${delivery.id}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              _StatusChip(delivery.status),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Order', value: '#${delivery.orderId ?? '—'}'),
          _DetailRow(
            label: 'Driver',
            value: delivery.driverName?.isNotEmpty == true
                ? delivery.driverName!
                : 'Unassigned',
          ),
          if (delivery.customerName?.isNotEmpty == true)
            _DetailRow(label: 'Customer', value: delivery.customerName!),
          if (delivery.deliveryAddress?.isNotEmpty == true)
            _DetailRow(label: 'Address', value: delivery.deliveryAddress!),
          if (delivery.pickupTime != null)
            _DetailRow(label: 'Pickup Time', value: delivery.pickupTime!),
          if (delivery.deliveryTime != null)
            _DetailRow(label: 'Delivery Time', value: delivery.deliveryTime!),
          if (delivery.notes?.isNotEmpty == true)
            _DetailRow(label: 'Notes', value: delivery.notes!),
          const SizedBox(height: 24),
          if (delivery.status != 'delivered' && delivery.status != 'failed') ...[
            const Text('Update Status',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (delivery.status == 'pending')
                  _ActionButton(
                    label: 'Mark In Transit',
                    color: Colors.blue,
                    icon: Icons.local_shipping,
                    onTap: () => _updateStatus(context, 'in_transit'),
                  ),
                if (delivery.status == 'in_transit')
                  _ActionButton(
                    label: 'Mark Delivered',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    onTap: () => _updateStatus(context, 'delivered'),
                  ),
                _ActionButton(
                  label: 'Mark Failed',
                  color: Colors.red,
                  icon: Icons.error,
                  onTap: () => _updateStatus(context, 'failed'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      await AdminRepository().updateDeliveryStatus(delivery.id, newStatus);
      if (context.mounted) {
        Navigator.pop(context);
        onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery status updated to ${newStatus.replaceAll('_', ' ')}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRIVERS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _DriversTab extends StatefulWidget {
  const _DriversTab();

  @override
  State<_DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<_DriversTab> {
  final _repo = AdminRepository();
  List<DeliveryDriver> _drivers = [];
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
      final items = await _repo.getDrivers();
      if (mounted) setState(() => _drivers = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                '${_drivers.length} driver${_drivers.length != 1 ? 's' : ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _showDriverDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Driver'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorView(message: _error!, onRetry: _load)
                  : _drivers.isEmpty
                      ? _EmptyView(
                          icon: Icons.directions_car,
                          message: 'No drivers yet',
                          subtitle: 'Add your first delivery driver to get started',
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _drivers.length,
                            itemBuilder: (_, i) =>
                                _DriverCard(driver: _drivers[i], onRefresh: _load),
                          ),
                        ),
        ),
      ],
    );
  }

  void _showDriverDialog(BuildContext context, {DeliveryDriver? driver}) {
    showDialog(
      context: context,
      builder: (_) => _DriverFormDialog(driver: driver, onSaved: _load),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final DeliveryDriver driver;
  final VoidCallback onRefresh;
  const _DriverCard({required this.driver, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: driver.isActive
                  ? Colors.teal.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              child: Icon(
                Icons.directions_car,
                color: driver.isActive ? Colors.teal : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: driver.isActive
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          driver.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: driver.isActive
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(driver.phone,
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      if (driver.vehicleNumber != null &&
                          driver.vehicleNumber!.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.directions_car,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(driver.vehicleNumber!,
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                  if (driver.vehicleType != null &&
                      driver.vehicleType!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(driver.vehicleType!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => _onAction(context, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(driver.isActive ? 'Deactivate' : 'Activate'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onAction(BuildContext context, String action) async {
    final repo = AdminRepository();
    switch (action) {
      case 'edit':
        showDialog(
          context: context,
          builder: (_) => _DriverFormDialog(driver: driver, onSaved: onRefresh),
        );
      case 'toggle':
        try {
          await repo.toggleDriverActive(driver.id);
          onRefresh();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Driver'),
            content: Text('Delete driver "${driver.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (ok == true) {
          try {
            await repo.deleteDriver(driver.id);
            onRefresh();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }
    }
  }
}

class _DriverFormDialog extends StatefulWidget {
  final DeliveryDriver? driver;
  final VoidCallback onSaved;
  const _DriverFormDialog({this.driver, required this.onSaved});

  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<_DriverFormDialog> {
  final _form = GlobalKey<FormState>();
  final _repo = AdminRepository();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _vehicleNumCtrl;
  late final TextEditingController _vehicleTypeCtrl;
  bool _saving = false;

  bool get _isEdit => widget.driver != null;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _vehicleNumCtrl = TextEditingController(text: d?.vehicleNumber ?? '');
    _vehicleTypeCtrl = TextEditingController(text: d?.vehicleType ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'vehicle_number': _vehicleNumCtrl.text.trim(),
      'vehicle_type': _vehicleTypeCtrl.text.trim(),
      'is_active': true,
    };
    try {
      if (_isEdit) {
        await _repo.updateDriver(widget.driver!.id, data);
      } else {
        await _repo.createDriver(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Driver' : 'Add Driver'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Update' : 'Add Driver'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ZONES & ROUTES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ZonesRoutesTab extends StatefulWidget {
  const _ZonesRoutesTab();

  @override
  State<_ZonesRoutesTab> createState() => _ZonesRoutesTabState();
}

class _ZonesRoutesTabState extends State<_ZonesRoutesTab> {
  final _repo = AdminRepository();
  List<DeliveryZone> _zones = [];
  List<DeliveryRoute> _routes = [];
  bool _loading = true;
  String? _error;
  int? _selectedZoneId;

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
      final zones = await _repo.getZones();
      final routes = await _repo.getRoutes();
      if (mounted) {
        setState(() {
          _zones = zones;
          _routes = routes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<DeliveryRoute> get _filteredRoutes {
    if (_selectedZoneId == null) return _routes;
    return _routes.where((r) => r.zoneId == _selectedZoneId).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!, onRetry: _load);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth * 0.45,
                child: _zonesPanel(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _routesPanel()),
            ],
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _zonesPanel(),
              const SizedBox(height: 16),
              _routesPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _zonesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.map, size: 20, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Text('Zones',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showZoneDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _load,
              ),
            ],
          ),
        ),
        if (_zones.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.map, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No zones yet',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Add delivery zones to organize routes',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ..._zones.map((z) => _ZoneCard(
                zone: z,
                selected: z.id == _selectedZoneId,
                onTap: () {
                  setState(() {
                    _selectedZoneId = _selectedZoneId == z.id ? null : z.id;
                  });
                },
                onEdit: () => _showZoneDialog(context, zone: z),
                onDelete: () => _deleteZone(z),
              )),
      ],
    );
  }

  Widget _routesPanel() {
    final selectedZone = _selectedZoneId != null
        ? _zones.where((z) => z.id == _selectedZoneId).firstOrNull
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.route, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedZone != null
                      ? 'Routes in ${selectedZone.name}'
                      : 'All Routes',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (_selectedZoneId != null)
                TextButton(
                  onPressed: () => setState(() => _selectedZoneId = null),
                  child: const Text('Show All'),
                ),
              TextButton.icon(
                onPressed: _zones.isEmpty
                    ? null
                    : () => _showRouteDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        if (_filteredRoutes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.route, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No routes yet',
                      style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text(
                    _zones.isEmpty
                        ? 'Create a zone first, then add routes'
                        : 'Add routes to organize deliveries within zones',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ..._filteredRoutes.map((r) => _RouteCard(
                route: r,
                onEdit: () => _showRouteDialog(context, route: r),
                onDelete: () => _deleteRoute(r),
              )),
      ],
    );
  }

  void _showZoneDialog(BuildContext context, {DeliveryZone? zone}) {
    showDialog(
      context: context,
      builder: (_) => _ZoneFormDialog(zone: zone, onSaved: _load),
    );
  }

  void _showRouteDialog(BuildContext context, {DeliveryRoute? route}) {
    showDialog(
      context: context,
      builder: (_) =>
          _RouteFormDialog(zones: _zones, route: route, onSaved: _load),
    );
  }

  Future<void> _deleteZone(DeliveryZone zone) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Zone'),
        content: Text(
            'Delete zone "${zone.name}" and all its routes? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.deleteZone(zone.id);
        if (_selectedZoneId == zone.id) _selectedZoneId = null;
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteRoute(DeliveryRoute route) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Delete route "${route.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.deleteRoute(route.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _ZoneCard extends StatelessWidget {
  final DeliveryZone zone;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ZoneCard({
    required this.zone,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? Theme.of(context).primaryColor : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      color: selected
          ? Theme.of(context).primaryColor.withValues(alpha: 0.04)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.map, color: Colors.deepOrange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(zone.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        if (!zone.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Inactive',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600])),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoBadge(
                          icon: Icons.attach_money,
                          label: 'AED ${zone.deliveryFee.toStringAsFixed(0)}',
                        ),
                        const SizedBox(width: 12),
                        _InfoBadge(
                          icon: Icons.timer,
                          label: '${zone.estimatedDeliveryTime} min',
                        ),
                        const SizedBox(width: 12),
                        _InfoBadge(
                          icon: Icons.route,
                          label: '${zone.routeCount} routes',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final DeliveryRoute route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RouteCard({
    required this.route,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.route, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(route.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      if (!route.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Inactive',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[600])),
                        ),
                      ],
                    ],
                  ),
                  if (route.zoneName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.map, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(route.zoneName!,
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                  if (route.description != null &&
                      route.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(route.description!,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneFormDialog extends StatefulWidget {
  final DeliveryZone? zone;
  final VoidCallback onSaved;
  const _ZoneFormDialog({this.zone, required this.onSaved});

  @override
  State<_ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<_ZoneFormDialog> {
  final _form = GlobalKey<FormState>();
  final _repo = AdminRepository();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _feeCtrl;
  late final TextEditingController _timeCtrl;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final z = widget.zone;
    _nameCtrl = TextEditingController(text: z?.name ?? '');
    _descCtrl = TextEditingController(text: z?.description ?? '');
    _feeCtrl = TextEditingController(
        text: z != null ? z.deliveryFee.toStringAsFixed(2) : '0.00');
    _timeCtrl = TextEditingController(
        text: z != null ? z.estimatedDeliveryTime.toString() : '30');
    _isActive = z?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _feeCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'delivery_fee': _feeCtrl.text.trim(),
      'estimated_delivery_time':
          int.tryParse(_timeCtrl.text.trim()) ?? 30,
      'is_active': _isActive,
    };
    try {
      if (_isEdit) {
        await _repo.updateZone(widget.zone!.id, data);
      } else {
        await _repo.createZone(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Zone' : 'Add Zone'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Zone Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Fee (AED) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Fee is required';
                        }
                        if (double.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _timeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Est. Time (min) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Time is required';
                        }
                        if (int.tryParse(v) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Update' : 'Add Zone'),
        ),
      ],
    );
  }
}

class _RouteFormDialog extends StatefulWidget {
  final List<DeliveryZone> zones;
  final DeliveryRoute? route;
  final VoidCallback onSaved;
  const _RouteFormDialog({
    required this.zones,
    this.route,
    required this.onSaved,
  });

  @override
  State<_RouteFormDialog> createState() => _RouteFormDialogState();
}

class _RouteFormDialogState extends State<_RouteFormDialog> {
  final _form = GlobalKey<FormState>();
  final _repo = AdminRepository();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  int? _selectedZoneId;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.route != null;

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _selectedZoneId = r?.zoneId ?? widget.zones.firstOrNull?.id;
    _isActive = r?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedZoneId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a zone'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final data = {
      'name': _nameCtrl.text.trim(),
      'zone': _selectedZoneId,
      'description': _descCtrl.text.trim(),
      'is_active': _isActive,
    };
    try {
      if (_isEdit) {
        await _repo.updateRoute(widget.route!.id, data);
      } else {
        await _repo.createRoute(data);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Route' : 'Add Route'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.route),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedZoneId,
                decoration: const InputDecoration(
                  labelText: 'Zone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
                items: widget.zones
                    .map((z) => DropdownMenuItem(
                          value: z.id,
                          child: Text(z.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedZoneId = v),
                validator: (v) => v == null ? 'Zone is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Update' : 'Add Route'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

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
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[500]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  const _EmptyView({required this.icon, required this.message, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.red[700])),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
