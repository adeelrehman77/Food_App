import 'package:flutter/material.dart';
import '../data/saas_repository.dart';
import '../domain/models.dart';

/// Platform analytics overview — the "home" screen of the SaaS admin.
class SaasOverviewScreen extends StatefulWidget {
  const SaasOverviewScreen({super.key});

  @override
  State<SaasOverviewScreen> createState() => _SaasOverviewScreenState();
}

class _SaasOverviewScreenState extends State<SaasOverviewScreen> {
  final _repo = SaasRepository();
  PlatformAnalytics? _analytics;
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
      final data = await _repo.getAnalytics();
      setState(() {
        _analytics = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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
            Text('Failed to load analytics',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final a = _analytics!;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time metrics across all tenants',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Metric cards
            _buildCardGrid(context, a),

            const SizedBox(height: 32),

            // Revenue section
            _buildRevenueSection(a),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGrid(BuildContext context, PlatformAnalytics a) {
    final cards = [
      _MetricData(
        'Total Tenants',
        a.totalTenants.toString(),
        Icons.store_rounded,
        const Color(0xFF3F51B5),
      ),
      _MetricData(
        'Active Tenants',
        a.activeTenants.toString(),
        Icons.check_circle_rounded,
        const Color(0xFF4CAF50),
      ),
      _MetricData(
        'Trial Tenants',
        a.trialTenants.toString(),
        Icons.hourglass_bottom_rounded,
        const Color(0xFFFF9800),
      ),
      _MetricData(
        'Pending Invoices',
        a.pendingInvoices.toString(),
        Icons.receipt_long_rounded,
        const Color(0xFF2196F3),
      ),
      _MetricData(
        'Overdue Invoices',
        a.overdueInvoices.toString(),
        Icons.warning_rounded,
        Colors.red,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (_, i) => _MetricCard(data: cards[i]),
        );
      },
    );
  }

  Widget _buildRevenueSection(PlatformAnalytics a) {
    return Row(
      children: [
        Expanded(
          child: _RevenueCard(
            title: 'Monthly Recurring Revenue',
            amount: a.totalRevenueMonthly,
            color: const Color(0xFF3F51B5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _RevenueCard(
            title: 'Annual Recurring Revenue',
            amount: a.totalRevenueYearly,
            color: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricData(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  const _RevenueCard({
    required this.title,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'AED ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
