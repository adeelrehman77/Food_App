import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _repo = AdminRepository();
  List<StaffUser> _staff = [];
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
      final staff = await _repo.getStaffUsers();
      if (mounted) setState(() => _staff = staff);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddStaffDialog() {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    String role = 'staff';
    final formKey = GlobalKey<FormState>();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dialogError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: lastNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Username *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Password *',
                        border: OutlineInputBorder(),
                        helperText: 'Min 8 characters',
                      ),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Min 8 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                        DropdownMenuItem(value: 'manager', child: Text('Manager')),
                        DropdownMenuItem(
                          value: 'kitchen_staff',
                          child: Text('Kitchen Staff'),
                        ),
                        DropdownMenuItem(value: 'driver', child: Text('Driver')),
                      ],
                      onChanged: (v) => role = v ?? 'staff',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _repo.createStaffUser({
                    'username': usernameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passwordCtrl.text,
                    'first_name': firstNameCtrl.text,
                    'last_name': lastNameCtrl.text,
                    'role': role,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Staff member added'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    dialogError = e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeRoleDialog(StaffUser user) {
    String role = user.role;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Change Role — ${user.fullName}'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
              DropdownMenuItem(
                value: 'kitchen_staff',
                child: Text('Kitchen Staff'),
              ),
              DropdownMenuItem(value: 'driver', child: Text('Driver')),
            ],
            onChanged: (v) => setDialogState(() => role = v ?? 'staff'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _repo.changeStaffRole(user.id, role);
                  _load();
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
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateUser(StaffUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate Staff?'),
        content: Text(
          'Are you sure you want to deactivate ${user.fullName}? '
          'They will lose access immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deactivateStaffUser(user.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} deactivated'),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Management',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage kitchen staff, managers, and drivers',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _showAddStaffDialog,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Staff'),
              ),
            ],
          ),
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
                  : _staff.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.badge, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No staff members',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _staff.length,
                            itemBuilder: (context, index) {
                              final user = _staff[index];
                              return _StaffCard(
                                user: user,
                                onChangeRole: () => _showChangeRoleDialog(user),
                                onDeactivate: () => _deactivateUser(user),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final StaffUser user;
  final VoidCallback onChangeRole;
  final VoidCallback onDeactivate;

  const _StaffCard({
    required this.user,
    required this.onChangeRole,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _roleColor.withValues(alpha: 0.15),
              child: Icon(_roleIcon, color: _roleColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username} · ${user.email}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      _RoleChip(user.role),
                      if (user.lastLogin != null)
                        Text(
                          'Last login: ${_formatDate(user.lastLogin!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'role') onChangeRole();
                if (v == 'deactivate') onDeactivate();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'role',
                  child: ListTile(
                    leading: Icon(Icons.swap_horiz),
                    title: Text('Change Role'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'deactivate',
                  child: ListTile(
                    leading: Icon(Icons.block, color: Colors.red),
                    title: Text('Deactivate', style: TextStyle(color: Colors.red)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color get _roleColor => switch (user.role) {
        'admin' => Colors.deepPurple,
        'manager' => Colors.blue,
        'kitchen_staff' => Colors.orange,
        'driver' => Colors.teal,
        _ => Colors.blueGrey,
      };

  IconData get _roleIcon => switch (user.role) {
        'admin' => Icons.admin_panel_settings,
        'manager' => Icons.manage_accounts,
        'kitchen_staff' => Icons.restaurant,
        'driver' => Icons.directions_car,
        _ => Icons.person,
      };

  String _formatDate(String dt) {
    try {
      final parsed = DateTime.parse(dt);
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return dt;
    }
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip(this.role);

  @override
  Widget build(BuildContext context) {
    final label = role.replaceAll('_', ' ');
    final (color, bgColor) = switch (role) {
      'admin' => (Colors.deepPurple.shade800, Colors.deepPurple.shade50),
      'manager' => (Colors.blue.shade800, Colors.blue.shade50),
      'kitchen_staff' => (Colors.orange.shade800, Colors.orange.shade50),
      'driver' => (Colors.teal.shade800, Colors.teal.shade50),
      _ => (Colors.blueGrey.shade800, Colors.blueGrey.shade50),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
