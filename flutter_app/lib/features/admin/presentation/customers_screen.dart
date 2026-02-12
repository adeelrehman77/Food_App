import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  List<CustomerItem> _customers = [];
  List<RegistrationRequest> _requests = [];
  bool _loading = true;
  String? _error;
  CustomerItem? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _selectedCustomer = null);
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tabCtrl.index == 0) {
        _customers = await _repo.getCustomers(search: _searchCtrl.text);
      } else {
        final statusFilter = _tabCtrl.index == 1 ? 'pending' : null;
        _requests = await _repo.getRegistrationRequests(status: statusFilter);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddCustomerDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddCustomerDialog(repo: _repo),
    );
    if (result == true) {
      _tabCtrl.animateTo(0);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Customer created successfully'),
              backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _approveRequest(RegistrationRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text(
          'Approve "${req.name}" and create a customer account?\n\n'
          'Phone: ${req.contactNumber}\n'
          'Meal: ${req.mealType ?? "N/A"} ${req.mealSelection ?? ""}\n'
          'Quantity: ${req.quantity}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.approveRegistration(req.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${req.name} approved & account created'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectRequest(RegistrationRequest req) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${req.name}?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
              labelText: 'Reason (optional)', border: OutlineInputBorder()),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.rejectRegistration(req.id, reasonCtrl.text);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${req.name} rejected'),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 720;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customers',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Manage customers and registration requests',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Customer'),
              ),
              const SizedBox(width: 8),
              IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'All Customers'),
                Tab(text: 'Pending Requests'),
                Tab(text: 'All Requests'),
              ],
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              dividerColor: Colors.transparent,
            ),
          ),
        ),
        const Divider(height: 1),

        // Search (customers tab only)
        if (_tabCtrl.index == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
            child: SizedBox(
              width: wide ? 340 : double.infinity,
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          })
                      : null,
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
          ),

        // Content: master-detail on wide, list-only on narrow
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _tabCtrl.index == 0
                      ? wide
                          ? _buildMasterDetail()
                          : _buildCustomersList()
                      : _buildRequestsList(),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Colors.red[700]),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry')),
        ],
      ),
    );
  }

  // ─── Master-Detail (wide screen) ──────────────────────────────────────────

  Widget _buildMasterDetail() {
    return Row(
      children: [
        // Left: customer list
        SizedBox(
          width: 380,
          child: _buildCustomersList(),
        ),
        // Divider
        Container(width: 1, color: Colors.grey.shade200),
        // Right: detail panel
        Expanded(
          child: _selectedCustomer != null
              ? _CustomerDetailPanel(
                  customer: _selectedCustomer!,
                  onClose: () => setState(() => _selectedCustomer = null),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Select a customer to view details',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 14)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Customers List ────────────────────────────────────────────────────────

  Widget _buildCustomersList() {
    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No customers yet',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text('Add your first customer to get started',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _showAddCustomerDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Customer')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final c = _customers[index];
          final addr = c.defaultAddress;
          final selected = _selectedCustomer?.id == c.id;
          return Material(
            color: selected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _selectedCustomer = c),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          _tierColor(c.loyaltyTier).withValues(alpha: 0.12),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _tierColor(c.loyaltyTier)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              c.name.isNotEmpty
                                  ? c.name
                                  : (c.fullName ?? c.username ?? '—'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 1),
                          Text(
                            [c.phone, c.email]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (addr != null) ...[
                            const SizedBox(height: 1),
                            Text(addr.displayString,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[400]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('AED ${c.walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 3),
                        _MiniChip(c.loyaltyTier.toUpperCase(),
                            _tierColor(c.loyaltyTier)),
                      ],
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

  // ─── Requests List ─────────────────────────────────────────────────────────

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_disabled, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No registration requests',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: _requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final r = _requests[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(r.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14))),
                    _RequestStatusChip(r.status),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _InfoItem(Icons.phone, r.contactNumber),
                    if (r.mealType != null)
                      _InfoItem(Icons.restaurant, r.mealType!),
                    if (r.mealSelection != null)
                      _InfoItem(Icons.schedule, r.mealSelection!),
                    _InfoItem(Icons.shopping_bag, 'Qty: ${r.quantity}'),
                  ],
                ),
                if (r.address != null && r.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(r.address!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                ],
                if (r.status == 'pending') ...[
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton(
                        onPressed: () => _rejectRequest(r),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18)),
                        child: const Text('Reject', style: TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: () => _approveRequest(r),
                        style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 18)),
                        child: const Text('Approve', style: TextStyle(fontSize: 13))),
                  ]),
                ],
                if (r.status == 'rejected' &&
                    r.rejectionReason != null &&
                    r.rejectionReason!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Reason: ${r.rejectionReason}',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.red[400])),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Color _tierColor(String tier) {
    return switch (tier.toLowerCase()) {
      'gold' => Colors.amber.shade700,
      'silver' => Colors.blueGrey,
      'platinum' => Colors.deepPurple,
      _ => Colors.brown,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Customer Detail Panel (inline, right side)
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerDetailPanel extends StatelessWidget {
  final CustomerItem customer;
  final VoidCallback onClose;
  const _CustomerDetailPanel({required this.customer, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name.isNotEmpty
                            ? c.name
                            : (c.fullName ?? c.username ?? '—'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(c.phone ?? '',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _LoyaltyBadge(tier: c.loyaltyTier),
                const SizedBox(width: 4),
                IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close'),
              ],
            ),
          ),

          // Scrollable body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _Section(title: 'Contact', rows: [
                  _Row('Phone', c.phone ?? '—'),
                  _Row('Email', c.email ?? '—'),
                  _Row('Preferred', _commLabel(c.preferredCommunication)),
                ]),
                const SizedBox(height: 14),
                _Section(title: 'Identity & Location', rows: [
                  _Row('Emirates ID', c.emiratesId ?? '—'),
                  _Row('Delivery Zone', c.zone ?? '—'),
                ]),
                const SizedBox(height: 14),
                _addressSection(c),
                const SizedBox(height: 14),
                _Section(title: 'Account', rows: [
                  _Row('Wallet', 'AED ${c.walletBalance.toStringAsFixed(2)}'),
                  _Row('Loyalty Points', '${c.loyaltyPoints}'),
                  _Row('Tier', c.loyaltyTier.toUpperCase()),
                  if (c.createdAt != null)
                    _Row('Member Since', _fmtDate(c.createdAt!)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressSection(CustomerItem c) {
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
          Text('Delivery Addresses',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.grey[600],
                  letterSpacing: 0.2)),
          const Divider(height: 16),
          if (c.addresses.isEmpty)
            Text('No address on file',
                style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                    fontStyle: FontStyle.italic))
          else
            ...c.addresses.map((addr) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          addr.isDefault
                              ? Icons.home_filled
                              : Icons.location_on_outlined,
                          size: 15,
                          color: addr.isDefault
                              ? Colors.deepOrange
                              : Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(addr.displayString,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 13)),
                            const SizedBox(height: 3),
                            Row(children: [
                              if (addr.isDefault) ...[
                                _MiniChip('Default', Colors.deepOrange),
                                const SizedBox(width: 6),
                              ],
                              _MiniChip(
                                addr.status.toUpperCase(),
                                addr.status == 'active'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  String _commLabel(String? v) => switch (v) {
        'whatsapp' => 'WhatsApp',
        'sms' => 'SMS',
        'email' => 'Email',
        'none' => 'None',
        _ => v ?? '—',
      };

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

/// A section card used in the detail panel.
class _Section extends StatelessWidget {
  final String title;
  final List<_Row> rows;
  const _Section({required this.title, required this.rows});

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
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Add Customer Dialog
// ═══════════════════════════════════════════════════════════════════════════════

class _AddCustomerDialog extends StatefulWidget {
  final AdminRepository repo;
  const _AddCustomerDialog({required this.repo});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emiratesIdCtrl = TextEditingController();
  final _zoneCtrl = TextEditingController();
  String _preferredComm = 'whatsapp';
  final _buildingCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _phoneCtrl, _emailCtrl, _emiratesIdCtrl, _zoneCtrl,
      _buildingCtrl, _flatCtrl, _floorCtrl, _streetCtrl, _cityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repo.createCustomer({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'emirates_id': _emiratesIdCtrl.text.trim(),
        'zone': _zoneCtrl.text.trim(),
        'preferred_communication': _preferredComm,
        'building_name': _buildingCtrl.text.trim(),
        'flat_number': _flatCtrl.text.trim(),
        'floor_number': _floorCtrl.text.trim(),
        'street': _streetCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              decoration: BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: Colors.grey.shade200))),
              child: Row(children: [
                const Icon(Icons.person_add,
                    size: 20, color: Colors.deepOrange),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Add Customer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20)),
              ]),
            ),
            // Body
            Expanded(
              child: Form(
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
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 12)),
                      ),

                    _label('Personal Information'),
                    const SizedBox(height: 6),
                    _field(_nameCtrl, 'Full Name *', Icons.person,
                        required: true),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: _field(_phoneCtrl, 'Phone *', Icons.phone,
                              required: true, hint: '+971XXXXXXXXX',
                              keyboard: TextInputType.phone)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _field(_emailCtrl, 'Email', Icons.email,
                              keyboard: TextInputType.emailAddress)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child:
                              _field(_emiratesIdCtrl, 'Emirates ID', Icons.badge)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _preferredComm,
                          decoration: _deco('Preferred Contact', Icons.message),
                          items: const [
                            DropdownMenuItem(
                                value: 'whatsapp', child: Text('WhatsApp')),
                            DropdownMenuItem(value: 'sms', child: Text('SMS')),
                            DropdownMenuItem(
                                value: 'email', child: Text('Email')),
                            DropdownMenuItem(
                                value: 'none', child: Text('None')),
                          ],
                          onChanged: (v) =>
                              setState(() => _preferredComm = v ?? 'whatsapp'),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 16),
                    _label('Delivery Address'),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          flex: 3,
                          child: _field(
                              _buildingCtrl, 'Building Name', Icons.apartment)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_floorCtrl, 'Floor', null,
                          keyboard: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_flatCtrl, 'Flat', null)),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          flex: 2,
                          child: _field(
                              _streetCtrl, 'Street / Area', Icons.signpost)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _field(
                              _cityCtrl, 'City', Icons.location_city)),
                    ]),
                    const SizedBox(height: 8),
                    _field(_zoneCtrl, 'Delivery Zone', Icons.map,
                        hint: 'e.g. Al Barsha, JLT'),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              decoration: BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Create Customer'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData? icon,
      {bool required = false,
      String? hint,
      TextInputType? keyboard}) {
    return TextFormField(
      controller: ctrl,
      decoration: _deco(label, icon, hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
      keyboardType: keyboard,
      textCapitalization:
          label.contains('Name') ? TextCapitalization.words : TextCapitalization.none,
      style: const TextStyle(fontSize: 13),
    );
  }

  InputDecoration _deco(String label, IconData? icon, [String? hint]) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 18) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      isDense: true,
      contentPadding: EdgeInsets.fromLTRB(icon != null ? 0 : 12, 10, 10, 10),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          color: Colors.grey[600],
          letterSpacing: 0.3));
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Small shared widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _LoyaltyBadge extends StatelessWidget {
  final String tier;
  const _LoyaltyBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tier.toLowerCase()) {
      'gold' => (Colors.amber.shade700, Icons.star),
      'silver' => (Colors.blueGrey, Icons.star_half),
      'platinum' => (Colors.deepPurple, Icons.diamond),
      _ => (Colors.brown, Icons.star_border),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(tier.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey[500]),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ]);
  }
}

class _RequestStatusChip extends StatelessWidget {
  final String status;
  const _RequestStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'approved' => (Colors.green.shade800, Colors.green.shade50),
      'rejected' => (Colors.red.shade800, Colors.red.shade50),
      _ => (Colors.grey.shade800, Colors.grey.shade100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
