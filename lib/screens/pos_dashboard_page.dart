// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// POS Dashboard.
///
/// Shows open checks count, sales summary (today's total, cash/card
/// breakdown), server status (active servers, open checks per server),
/// and quick action buttons (New Check, New Order, Close Check, Reports).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import 'check_list_page.dart';
import 'order_entry_page.dart';
import 'pos_reports_page.dart';
import 'table_management_page.dart';

class PosDashboardPage extends StatefulWidget {
  const PosDashboardPage({
    super.key,
    required this.client,
    required this.outletId,
  });

  final BffClient client;
  final String outletId;

  @override
  State<PosDashboardPage> createState() => _PosDashboardPageState();
}

class _PosDashboardPageState extends State<PosDashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getDashboard(outletId: widget.outletId);
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getDashboard(outletId: widget.outletId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  Text(snapshot.error.toString()),
                  FilledButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          final openChecks = data['open_checks'] as int? ?? 0;
          final totalSales = (data['total_sales'] as num?)?.toDouble() ?? 0;
          final cashSales = (data['cash_sales'] as num?)?.toDouble() ?? 0;
          final cardSales = (data['card_sales'] as num?)?.toDouble() ?? 0;
          final roomCharges = (data['room_charges'] as num?)?.toDouble() ?? 0;
          final avgCheck = (data['avg_check'] as num?)?.toDouble() ?? 0;
          final tablesOccupied = data['tables_occupied'] as int? ?? 0;
          final tablesAvailable = data['tables_available'] as int? ?? 0;
          final servers = (data['servers'] as List<dynamic>?) ?? [];

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Quick actions ──
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _QuickAction(
                      icon: Icons.add_circle,
                      label: 'New Check',
                      color: Colors.green,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TableManagementPage(
                            client: widget.client, outletId: widget.outletId),
                      )),
                    ),
                    _QuickAction(
                      icon: Icons.point_of_sale,
                      label: 'New Order',
                      color: Colors.orange,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OrderEntryPage(
                            client: widget.client, outletId: widget.outletId),
                      )),
                    ),
                    _QuickAction(
                      icon: Icons.receipt_long,
                      label: 'Open Checks',
                      color: Colors.blue,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CheckListPage(
                            client: widget.client, outletId: widget.outletId),
                      )),
                    ),
                    _QuickAction(
                      icon: Icons.bar_chart,
                      label: 'Reports',
                      color: Colors.purple,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PosReportsPage(
                            client: widget.client, outletId: widget.outletId),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Sales summary ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today\'s Sales', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount:
                              MediaQuery.of(context).size.width > 600 ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.2,
                          children: [
                            _Kpi('Total Sales', fmt.format(totalSales), Colors.green),
                            _Kpi('Cash', fmt.format(cashSales), Colors.blue),
                            _Kpi('Card', fmt.format(cardSales), Colors.purple),
                            _Kpi('Room', fmt.format(roomCharges), Colors.teal),
                            _Kpi('Avg Check', fmt.format(avgCheck), Colors.orange),
                            _Kpi('Open Checks', '$openChecks', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ── Tables & Servers ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tables', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              _StatRow(Icons.event_available, 'Available', '$tablesAvailable', Colors.green),
                              _StatRow(Icons.event_busy, 'Occupied', '$tablesOccupied', Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Server Status', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              if (servers.isEmpty)
                                const Text('No active servers.')
                              else
                                ...servers.map((s) {
                                  final server = s as Map<String, dynamic>;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Text((server['name'] as String?)?[0] ?? '?'),
                                    ),
                                    title: Text(server['name'] as String? ?? 'Server'),
                                    subtitle: Text(
                                        '${server['open_checks'] ?? 0} open checks • ${fmt.format((server['sales'] as num?)?.toDouble() ?? 0)}'),
                                    trailing: Chip(
                                      label: Text(server['status'] as String? ?? 'active'),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 100,
      child: Card(
        color: color.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Kpi(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}