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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
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

  // ─── Add Customer Dialog ───────────────────────────────────────────────────

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
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ─── Approve / Reject ──────────────────────────────────────────────────────

  Future<void> _approveRequest(RegistrationRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text(
          'Approve ${req.name} and create a customer account?\n\n'
          'Phone: ${req.contactNumber}\n'
          'Meal: ${req.mealType ?? "N/A"} ${req.mealSelection ?? ""}\n'
          'Quantity: ${req.quantity}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
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
            content: Text('${req.name} approved & customer account created'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
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
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
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
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Customer Detail ───────────────────────────────────────────────────────

  void _showCustomerDetail(CustomerItem c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => _CustomerDetailSheet(
          customer: c,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

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
                      'Customers',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage customers and registration requests',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
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
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Search bar (only for Customers tab)
        if (_tabCtrl.index == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: SizedBox(
              width: 360,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, phone...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        )
                      : null,
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'All Customers'),
            Tab(text: 'Pending Requests'),
            Tab(text: 'All Requests'),
          ],
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
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
                  : _tabCtrl.index == 0
                      ? _buildCustomersList()
                      : _buildRequestsList(),
        ),
      ],
    );
  }

  Widget _buildCustomersList() {
    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No customers yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first customer to get started',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _showAddCustomerDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Customer'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final c = _customers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => _showCustomerDetail(c),
              leading: CircleAvatar(
                backgroundColor: _tierColor(c.loyaltyTier).withValues(alpha: 0.15),
                child: Text(
                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _tierColor(c.loyaltyTier),
                  ),
                ),
              ),
              title: Text(
                c.name.isNotEmpty ? c.name : (c.fullName ?? c.username ?? '—'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${c.phone ?? ''} · ${c.email ?? ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'AED ${c.walletBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tierColor(c.loyaltyTier).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      c.loyaltyTier.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _tierColor(c.loyaltyTier),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No registration requests',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final r = _requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _RequestStatusChip(r.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    children: [
                      _InfoItem(Icons.phone, r.contactNumber),
                      if (r.mealType != null) _InfoItem(Icons.restaurant, r.mealType!),
                      if (r.mealSelection != null)
                        _InfoItem(Icons.schedule, r.mealSelection!),
                      _InfoItem(Icons.shopping_bag, 'Qty: ${r.quantity}'),
                    ],
                  ),
                  if (r.address != null && r.address!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      r.address!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (r.status == 'pending') ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => _rejectRequest(r),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _approveRequest(r),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                  if (r.status == 'rejected' &&
                      r.rejectionReason != null &&
                      r.rejectionReason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Reason: ${r.rejectionReason}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ],
              ),
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
      _ => Colors.brown, // bronze
    };
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
  final _addressCtrl = TextEditingController();
  String _preferredComm = 'whatsapp';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _emiratesIdCtrl.dispose();
    _zoneCtrl.dispose();
    _addressCtrl.dispose();
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
        'address': _addressCtrl.text.trim(),
        'preferred_communication': _preferredComm,
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
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add, size: 22),
          SizedBox(width: 10),
          Text('Add Customer'),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    hintText: '+971 XX XXX XXXX',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emiratesIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Emirates ID',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _zoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Delivery Zone',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _preferredComm,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Communication',
                    prefixIcon: Icon(Icons.message),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                    DropdownMenuItem(value: 'sms', child: Text('SMS')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                    DropdownMenuItem(value: 'none', child: Text('None')),
                  ],
                  onChanged: (v) => setState(() => _preferredComm = v ?? 'whatsapp'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Customer'),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Customer Detail Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerDetailSheet extends StatelessWidget {
  final CustomerItem customer;
  final ScrollController scrollController;

  const _CustomerDetailSheet({
    required this.customer,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle bar
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
        // Avatar + Name
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
              child: Text(
                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name.isNotEmpty ? c.name : (c.fullName ?? c.username ?? '—'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (c.email != null && c.email!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.email!, style: TextStyle(color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
            _LoyaltyBadge(tier: c.loyaltyTier),
          ],
        ),
        const SizedBox(height: 24),
        // Info cards
        _DetailCard(
          title: 'Contact',
          children: [
            _DetailRow('Phone', c.phone ?? '—'),
            _DetailRow('Email', c.email ?? '—'),
            _DetailRow('Preferred', _commLabel(c.preferredCommunication)),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Identity & Location',
          children: [
            _DetailRow('Emirates ID', c.emiratesId ?? '—'),
            _DetailRow('Delivery Zone', c.zone ?? '—'),
          ],
        ),
        const SizedBox(height: 12),
        _DetailCard(
          title: 'Account',
          children: [
            _DetailRow('Wallet Balance', 'AED ${c.walletBalance.toStringAsFixed(2)}'),
            _DetailRow('Loyalty Points', '${c.loyaltyPoints}'),
            _DetailRow('Loyalty Tier', c.loyaltyTier.toUpperCase()),
            if (c.createdAt != null) _DetailRow('Member Since', _formatDate(c.createdAt!)),
          ],
        ),
      ],
    );
  }

  String _commLabel(String? val) {
    return switch (val) {
      'whatsapp' => 'WhatsApp',
      'sms' => 'SMS',
      'email' => 'Email',
      'none' => 'None',
      _ => val ?? '—',
    };
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            tier.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small helpers ───────────────────────────────────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoItem(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }
}

class _RequestStatusChip extends StatelessWidget {
  final String status;
  const _RequestStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = switch (status) {
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'approved' => (Colors.green.shade800, Colors.green.shade50),
      'rejected' => (Colors.red.shade800, Colors.red.shade50),
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
