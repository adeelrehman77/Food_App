import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  final _repo = AdminRepository();
  late final TabController _tabCtrl;

  final _tabs = const [
    Tab(text: 'All'),
    Tab(text: 'Pending'),
    Tab(text: 'Paid'),
    Tab(text: 'Failed'),
    Tab(text: 'Refunded'),
  ];
  final _statusFilters = [null, 'pending', 'paid', 'failed', 'refunded'];

  List<InvoiceItem> _invoices = [];
  InvoiceSummary? _summary;
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
      final results = await Future.wait([
        _repo.getInvoiceSummary(),
        _repo.getInvoices(status: _statusFilters[_tabCtrl.index]),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as InvoiceSummary;
          _invoices = results[1] as List<InvoiceItem>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _totalRevenue => _summary?.paidTotal ?? 0;
  double get _totalPending => _summary?.pendingTotal ?? 0;
  int get _totalInvoiceCount => _summary?.totalCount ?? 0;

  void _showInvoiceDetail(InvoiceItem invoice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text('Invoice ${invoice.invoiceNumber}')),
            _StatusChip(invoice.status),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow('Customer', invoice.customerName ?? '—'),
                _DetailRow('Date', invoice.date ?? '—'),
                _DetailRow('Due Date', invoice.dueDate ?? '—'),
                _DetailRow('Total', 'AED ${invoice.total.toStringAsFixed(2)}'),
                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  _DetailRow('Notes', invoice.notes!),
                const SizedBox(height: 16),
                if (invoice.items.isNotEmpty) ...[
                  const Text(
                    'Line Items',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 32,
                    dataRowMaxHeight: 40,
                    columns: const [
                      DataColumn(label: Text('Item')),
                      DataColumn(label: Text('Qty'), numeric: true),
                      DataColumn(label: Text('Unit Price'), numeric: true),
                      DataColumn(label: Text('Total'), numeric: true),
                    ],
                    rows: invoice.items.map((li) {
                      return DataRow(cells: [
                        DataCell(Text(li.menuName ?? '—')),
                        DataCell(Text('${li.quantity}')),
                        DataCell(Text(li.unitPrice.toStringAsFixed(2))),
                        DataCell(Text(li.totalPrice.toStringAsFixed(2))),
                      ]);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (invoice.status != 'paid')
            FilledButton.icon(
              onPressed: () async {
                try {
                  await _repo.markInvoicePaid(invoice.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Failed to mark paid: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark paid'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance & Invoices',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track invoices and revenue',
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
              const SizedBox(height: 16),
              // Summary cards
              if (!_loading && _error == null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SummaryChip(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      label: 'Paid',
                      value: 'AED ${_totalRevenue.toStringAsFixed(0)}',
                    ),
                    _SummaryChip(
                      icon: Icons.hourglass_empty,
                      color: Colors.orange,
                      label: 'Pending',
                      value: 'AED ${_totalPending.toStringAsFixed(0)}',
                    ),
                    _SummaryChip(
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                      label: 'Invoices',
                      value: '$_totalInvoiceCount',
                    ),
                  ],
                ),
            ],
          ),
        ),
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
                  : _invoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No invoices found',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final inv = _invoices[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  onTap: () => _showInvoiceDetail(inv),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _invoiceColor(inv.status)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.receipt_long,
                                      color: _invoiceColor(inv.status),
                                    ),
                                  ),
                                  title: Text(
                                    inv.invoiceNumber,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${inv.customerName ?? '—'} · ${inv.date ?? ''}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'AED ${inv.total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _StatusChip(inv.status),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Color _invoiceColor(String status) {
    return switch (status) {
      'paid' => Colors.green,
      'pending' => Colors.orange,
      'failed' => Colors.red,
      'refunded' => Colors.purple,
      _ => Colors.grey,
    };
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
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
      'paid' => (Colors.green.shade800, Colors.green.shade50),
      'pending' => (Colors.orange.shade800, Colors.orange.shade50),
      'failed' => (Colors.red.shade800, Colors.red.shade50),
      'refunded' => (Colors.purple.shade800, Colors.purple.shade50),
      _ => (Colors.grey.shade800, Colors.grey.shade100),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
