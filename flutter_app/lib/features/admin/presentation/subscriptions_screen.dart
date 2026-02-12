import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabCtrl;

  static const _tabs = ['All', 'Active', 'Pending', 'Paused', 'Expired', 'Cancelled'];
  static const _statusFilters = [null, 'active', 'pending', 'paused', 'expired', 'cancelled'];

  List<SubscriptionItem> _subs = [];
  bool _loading = true;
  String? _error;
  SubscriptionItem? _selected;

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
      final subs = await _repo.getSubscriptions(
        status: _statusFilters[_tabCtrl.index],
      );
      if (mounted) setState(() => _subs = subs);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _SubscriptionFormDialog(repo: _repo),
    );
    if (result == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription created'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _doAction(SubscriptionItem sub, String action) async {
    try {
      SubscriptionItem updated;
      String msg;
      switch (action) {
        case 'activate':
          updated = await _repo.activateSubscription(sub.id);
          msg = 'Subscription activated';
          break;
        case 'pause':
          updated = await _repo.pauseSubscription(sub.id);
          msg = 'Subscription paused';
          break;
        case 'cancel':
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Cancel Subscription'),
              content: Text('Cancel subscription #${sub.id} for ${sub.customerName}?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (ok != true) return;
          updated = await _repo.cancelSubscription(sub.id);
          msg = 'Subscription cancelled';
          break;
        case 'generate_orders':
          final result = await _repo.generateOrders(sub.id);
          msg = result['detail'] ?? 'Orders generated';
          _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.green),
            );
          }
          return;
        default:
          return;
      }
      _load();
      if (mounted) {
        setState(() => _selected = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subscriptions',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Manage customer meal subscriptions',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Subscription'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepOrange,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _subs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.card_membership, size: 56, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No subscriptions found',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            // Left: list
                            SizedBox(
                              width: 420,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _subs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (_, i) {
                                  final s = _subs[i];
                                  final isSelected = _selected?.id == s.id;
                                  return _SubCard(
                                    sub: s,
                                    isSelected: isSelected,
                                    onTap: () async {
                                      // Load full detail
                                      try {
                                        final detail = await _repo.getSubscription(s.id);
                                        if (mounted) setState(() => _selected = detail);
                                      } catch (_) {
                                        if (mounted) setState(() => _selected = s);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            Container(width: 1, color: Colors.grey.shade200),
                            // Right: detail
                            Expanded(
                              child: _selected != null
                                  ? _DetailPanel(
                                      sub: _selected!,
                                      onAction: _doAction,
                                      onClose: () => setState(() => _selected = null),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.touch_app, size: 48, color: Colors.grey[300]),
                                          const SizedBox(height: 12),
                                          Text('Select a subscription to view details',
                                              style: TextStyle(color: Colors.grey[400])),
                                        ],
                                      ),
                                    ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Subscription Card (list item)
// ═══════════════════════════════════════════════════════════════════════════════

class _SubCard extends StatelessWidget {
  final SubscriptionItem sub;
  final bool isSelected;
  final VoidCallback onTap;
  const _SubCard({required this.sub, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.deepOrange.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.deepOrange.withValues(alpha: 0.3) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
                    child: Text(
                      sub.customerName.isNotEmpty ? sub.customerName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.customerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (sub.customerPhone != null)
                          Text(sub.customerPhone!,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  _StatusChip(sub.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('${_fmtDate(sub.startDate)} — ${_fmtDate(sub.endDate)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const Spacer(),
                  Text('AED ${sub.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (sub.timeSlotName != null && sub.timeSlotName!.isNotEmpty) ...[
                    Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(sub.timeSlotName!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(width: 10),
                  ],
                  Icon(Icons.receipt_long, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text('${sub.orderCount} orders',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  const SizedBox(width: 10),
                  ...sub.selectedDays.take(3).map((d) => Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(d.substring(0, 3),
                              style: TextStyle(fontSize: 9, color: Colors.blue[700])),
                        ),
                      )),
                  if (sub.selectedDays.length > 3)
                    Text('+${sub.selectedDays.length - 3}',
                        style: TextStyle(fontSize: 9, color: Colors.blue[400])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Detail Panel
// ═══════════════════════════════════════════════════════════════════════════════

class _DetailPanel extends StatelessWidget {
  final SubscriptionItem sub;
  final void Function(SubscriptionItem, String) onAction;
  final VoidCallback onClose;
  const _DetailPanel({required this.sub, required this.onAction, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Subscription #${sub.id}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          _StatusChip(sub.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${sub.customerName} • ${sub.customerPhone ?? ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Action buttons
                ..._actionButtons(sub),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionBox(title: 'Schedule', children: [
                  _InfoRow('Start Date', _fmtDate(sub.startDate)),
                  _InfoRow('End Date', _fmtDate(sub.endDate)),
                  _InfoRow('Time Slot', sub.timeSlotName ?? '—'),
                  _InfoRow('Delivery Days', sub.selectedDays.join(', ')),
                ]),
                const SizedBox(height: 14),
                _SectionBox(title: 'Pricing', children: [
                  _InfoRow('Cost per Meal', 'AED ${sub.costPerMeal.toStringAsFixed(2)}'),
                  _InfoRow('Total Cost', 'AED ${sub.totalCost.toStringAsFixed(2)}'),
                  _InfoRow('Payment Mode', _paymentLabel(sub.paymentMode)),
                ]),
                const SizedBox(height: 14),
                _SectionBox(title: 'Delivery Addresses', children: [
                  _InfoRow('Lunch', _addressStr(sub.lunchAddressDetails)),
                  _InfoRow('Dinner', _addressStr(sub.dinnerAddressDetails)),
                ]),
                const SizedBox(height: 14),
                _SectionBox(title: 'Preferences', children: [
                  _InfoRow('Dietary', sub.dietaryPreferences ?? '—'),
                  _InfoRow('Instructions', sub.specialInstructions ?? '—'),
                  _InfoRow('Notifications', sub.wantNotifications ? 'Yes' : 'No'),
                ]),
                const SizedBox(height: 14),
                _SectionBox(title: 'Orders', children: [
                  _InfoRow('Total Orders', '${sub.orderCount}'),
                  if (sub.status == 'active')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => onAction(sub, 'generate_orders'),
                          icon: const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Generate Orders'),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionButtons(SubscriptionItem s) {
    final buttons = <Widget>[];
    if (s.status == 'pending' || s.status == 'paused') {
      buttons.add(
        _ActionBtn(
          icon: Icons.play_arrow,
          label: 'Activate',
          color: Colors.green,
          onTap: () => onAction(s, 'activate'),
        ),
      );
    }
    if (s.status == 'active') {
      buttons.add(
        _ActionBtn(
          icon: Icons.pause,
          label: 'Pause',
          color: Colors.orange,
          onTap: () => onAction(s, 'pause'),
        ),
      );
    }
    if (s.status != 'cancelled' && s.status != 'expired') {
      buttons.add(
        _ActionBtn(
          icon: Icons.cancel,
          label: 'Cancel',
          color: Colors.red,
          onTap: () => onAction(s, 'cancel'),
        ),
      );
    }
    return buttons;
  }

  String _addressStr(Map<String, dynamic>? addr) {
    if (addr == null) return '—';
    final parts = <String>[];
    if (addr['building_name'] != null && addr['building_name'].toString().isNotEmpty) {
      parts.add(addr['building_name']);
    }
    if (addr['flat_number'] != null && addr['flat_number'].toString().isNotEmpty) {
      parts.add('Flat ${addr['flat_number']}');
    }
    if (addr['street'] != null && addr['street'].toString().isNotEmpty) {
      parts.add(addr['street']);
    }
    if (addr['city'] != null && addr['city'].toString().isNotEmpty) {
      parts.add(addr['city']);
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _paymentLabel(String mode) => switch (mode) {
        'wallet' => 'Wallet',
        'card' => 'Card',
        'cash' => 'Cash',
        _ => mode,
      };
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Create / Edit Subscription Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _SubscriptionFormDialog extends StatefulWidget {
  final AdminRepository repo;
  final SubscriptionItem? existing;
  const _SubscriptionFormDialog({required this.repo, this.existing});

  @override
  State<_SubscriptionFormDialog> createState() => _SubscriptionFormDialogState();
}

class _SubscriptionFormDialogState extends State<_SubscriptionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  // Loaded data
  List<CustomerItem> _customers = [];
  List<Map<String, dynamic>> _timeSlots = [];
  List<CustomerAddress> _addresses = [];
  bool _loadingData = true;

  // Form state
  int? _customerId;
  int? _timeSlotId;
  int? _lunchAddressId;
  int? _dinnerAddressId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _paymentMode = 'wallet';
  final Set<String> _selectedDays = {};
  final _dietCtrl = TextEditingController();
  final _instructCtrl = TextEditingController();
  bool _wantNotifications = true;
  String _status = 'pending';

  static const _allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.existing!;
      _customerId = s.customerId;
      _timeSlotId = s.timeSlot;
      _lunchAddressId = s.lunchAddress;
      _dinnerAddressId = s.dinnerAddress;
      _startDate = DateTime.tryParse(s.startDate);
      _endDate = DateTime.tryParse(s.endDate);
      _paymentMode = s.paymentMode;
      _selectedDays.addAll(s.selectedDays);
      _dietCtrl.text = s.dietaryPreferences ?? '';
      _instructCtrl.text = s.specialInstructions ?? '';
      _wantNotifications = s.wantNotifications;
      _status = s.status;
    }
    _loadFormData();
  }

  @override
  void dispose() {
    _dietCtrl.dispose();
    _instructCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final customers = await widget.repo.getCustomers();
      final timeSlots = await widget.repo.getTimeSlots();
      if (mounted) {
        setState(() {
          _customers = customers;
          _timeSlots = timeSlots;
          _loadingData = false;
        });
        // If editing and customer is selected, load addresses
        if (_customerId != null) _loadAddresses();
      }
    } catch (e) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadAddresses() async {
    if (_customerId == null) return;
    final customer = _customers.firstWhere((c) => c.id == _customerId, orElse: () => _customers.first);
    setState(() => _addresses = customer.addresses);
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      setState(() => _error = 'Please select a customer');
      return;
    }
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Please select start and end dates');
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Please select at least one delivery day');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final data = {
        'customer': _customerId,
        'status': _status,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'time_slot': _timeSlotId,
        'lunch_address': _lunchAddressId,
        'dinner_address': _dinnerAddressId,
        'selected_days': _selectedDays.toList(),
        'payment_mode': _paymentMode,
        'want_notifications': _wantNotifications,
        'dietary_preferences': _dietCtrl.text.trim(),
        'special_instructions': _instructCtrl.text.trim(),
      };

      if (_isEdit) {
        await widget.repo.updateSubscription(widget.existing!.id, data);
      } else {
        await widget.repo.createSubscription(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                const Icon(Icons.card_membership, size: 20, color: Colors.deepOrange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_isEdit ? 'Edit Subscription' : 'New Subscription',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20)),
              ]),
            ),
            // Body
            Expanded(
              child: _loadingData
                  ? const Center(child: CircularProgressIndicator())
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        children: [
                          if (_error != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200)),
                              child: Text(_error!,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                            ),

                          // Customer
                          _sectionLabel('Customer'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _customerId,
                            decoration: _inputDeco('Select Customer', Icons.person),
                            isExpanded: true,
                            items: _customers.map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.name} (${c.phone ?? ""})',
                                      style: const TextStyle(fontSize: 13)),
                                )).toList(),
                            onChanged: (v) {
                              setState(() {
                                _customerId = v;
                                _lunchAddressId = null;
                                _dinnerAddressId = null;
                              });
                              _loadAddresses();
                            },
                            validator: (v) => v == null ? 'Required' : null,
                          ),

                          const SizedBox(height: 14),
                          _sectionLabel('Schedule'),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                              child: _DateField(
                                label: 'Start Date *',
                                date: _startDate,
                                onTap: () => _pickDate(true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateField(
                                label: 'End Date *',
                                date: _endDate,
                                onTap: () => _pickDate(false),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          // Time slot
                          DropdownButtonFormField<int>(
                            value: _timeSlotId,
                            decoration: _inputDeco('Time Slot', Icons.schedule),
                            isExpanded: true,
                            items: _timeSlots.map((ts) => DropdownMenuItem(
                                  value: ts['id'] as int,
                                  child: Text('${ts['name']} (${ts['time'] ?? ''})',
                                      style: const TextStyle(fontSize: 13)),
                                )).toList(),
                            onChanged: (v) => setState(() => _timeSlotId = v),
                          ),
                          const SizedBox(height: 10),
                          // Days
                          Text('Delivery Days *',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: Colors.grey[600])),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: _allDays.map((day) {
                              final sel = _selectedDays.contains(day);
                              return FilterChip(
                                label: Text(day.substring(0, 3),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: sel ? Colors.white : Colors.grey[700])),
                                selected: sel,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedDays.add(day);
                                    } else {
                                      _selectedDays.remove(day);
                                    }
                                  });
                                },
                                selectedColor: Colors.deepOrange,
                                checkmarkColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 14),
                          _sectionLabel('Addresses & Payment'),
                          const SizedBox(height: 6),
                          // Lunch / Dinner address
                          if (_addresses.isNotEmpty) ...[
                            DropdownButtonFormField<int>(
                              value: _lunchAddressId,
                              decoration: _inputDeco('Lunch Address', Icons.home),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontSize: 13))),
                                ..._addresses.map((a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.displayString, style: const TextStyle(fontSize: 13)),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _lunchAddressId = v),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _dinnerAddressId,
                              decoration: _inputDeco('Dinner Address', Icons.home_work),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None', style: TextStyle(fontSize: 13))),
                                ..._addresses.map((a) => DropdownMenuItem(
                                      value: a.id,
                                      child: Text(a.displayString, style: const TextStyle(fontSize: 13)),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _dinnerAddressId = v),
                            ),
                            const SizedBox(height: 8),
                          ] else if (_customerId != null) ...[
                            Text('No addresses found for this customer.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),
                          ],
                          // Payment mode
                          DropdownButtonFormField<String>(
                            value: _paymentMode,
                            decoration: _inputDeco('Payment Mode', Icons.payment),
                            items: const [
                              DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                              DropdownMenuItem(value: 'card', child: Text('Card')),
                              DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            ],
                            onChanged: (v) => setState(() => _paymentMode = v ?? 'wallet'),
                          ),

                          if (_isEdit) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _status,
                              decoration: _inputDeco('Status', Icons.flag),
                              items: const [
                                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                                DropdownMenuItem(value: 'active', child: Text('Active')),
                                DropdownMenuItem(value: 'paused', child: Text('Paused')),
                                DropdownMenuItem(value: 'expired', child: Text('Expired')),
                                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? 'pending'),
                            ),
                          ],

                          const SizedBox(height: 14),
                          _sectionLabel('Preferences'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dietCtrl,
                            decoration: _inputDeco('Dietary Preferences', Icons.eco),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _instructCtrl,
                            decoration: _inputDeco('Special Instructions', Icons.note),
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            value: _wantNotifications,
                            onChanged: (v) => setState(() => _wantNotifications = v ?? true),
                            title: const Text('Send notifications', style: TextStyle(fontSize: 13)),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_isEdit ? Icons.check : Icons.add, size: 16),
                  label: Text(_isEdit ? 'Update' : 'Create Subscription'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[600], letterSpacing: 0.3));

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Small shared widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'active' => (Colors.green.shade800, Colors.green.shade50),
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'paused' => (Colors.blue.shade800, Colors.blue.shade50),
      'expired' => (Colors.grey.shade800, Colors.grey.shade200),
      'cancelled' => (Colors.red.shade800, Colors.red.shade50),
      _ => (Colors.grey.shade800, Colors.grey.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateField({required this.label, this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300)),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yyyy').format(date!) : 'Select',
          style: TextStyle(
              fontSize: 13, color: date != null ? Colors.black87 : Colors.grey[500]),
        ),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionBox({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 0.2)),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

String _fmtDate(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('dd MMM yyyy').format(d);
  } catch (_) {
    return iso;
  }
}
