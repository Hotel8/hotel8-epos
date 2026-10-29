// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Table Management / Floor Plan.
///
/// Displays tables in a color-coded floor-plan grid by section. Each
/// table card shows the table number, status, seats, and (if occupied)
/// the server and seated time. Actions: assign server, seat guests,
/// update status.

import 'package:flutter/material.dart' hide Table;
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'order_entry_page.dart';

class TableManagementPage extends StatefulWidget {
  const TableManagementPage({
    super.key,
    required this.client,
    required this.outletId,
  });

  final BffClient client;
  final String outletId;

  @override
  State<TableManagementPage> createState() => _TableManagementPageState();
}

class _TableManagementPageState extends State<TableManagementPage> {
  late Future<List<Table>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getTables(outletId: widget.outletId);
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getTables(outletId: widget.outletId);
    });
  }

  Color _tableColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green.shade300;
      case 'occupied':
        return Colors.red.shade300;
      case 'reserved':
        return Colors.blue.shade300;
      case 'dirty':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade300;
    }
  }

  Future<void> _tableAction(Table table) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Table ${table.tableNumber}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${table.section} • ${table.seats} seats • ${table.status}',
              ),
            ),
            const Divider(),
            if (table.status == 'available')
              ListTile(
                leading: const Icon(Icons.airline_seat_recline_normal),
                title: const Text('Seat Guests'),
                onTap: () => Navigator.pop(ctx, 'seat'),
              ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Assign Server'),
              onTap: () => Navigator.pop(ctx, 'assign'),
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Mark Dirty'),
              onTap: () => Navigator.pop(ctx, 'dirty'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Mark Available'),
              onTap: () => Navigator.pop(ctx, 'available'),
            ),
            if (table.currentCheckId != null)
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Open Check / Order'),
                onTap: () => Navigator.pop(ctx, 'order'),
              ),
          ],
        ),
      ),
    );
    if (action == null) return;

    switch (action) {
      case 'seat':
        await _seatGuests(table);
      case 'assign':
        await _assignServer(table);
      case 'dirty':
        await _updateStatus(table, 'dirty');
      case 'available':
        await _updateStatus(table, 'available');
      case 'order':
        if (mounted) {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => OrderEntryPage(
                    client: widget.client,
                    outletId: widget.outletId,
                    checkId: table.currentCheckId,
                  ),
                ),
              )
              .then((_) => _refresh());
        }
    }
  }

  Future<void> _seatGuests(Table table) async {
    final guests = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '2');
        return AlertDialog(
          title: Text('Seat - Table ${table.tableNumber}'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of guests',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? 2),
              child: const Text('Seat'),
            ),
          ],
        );
      },
    );
    if (guests == null) return;
    try {
      await widget.client.seatGuests(
        outletId: widget.outletId,
        tableId: table.id,
        guests: guests,
        serverId: 'current-server',
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _assignServer(Table table) async {
    final server = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Assign Server - Table ${table.tableNumber}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Server ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
              ),
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
    if (server == null) return;
    try {
      await widget.client.updateTable(
        outletId: widget.outletId,
        tableId: table.id,
        assignedServer: server,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _updateStatus(Table table, String status) async {
    try {
      await widget.client.updateTable(
        outletId: widget.outletId,
        tableId: table.id,
        status: status,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat.Hm();
    return Scaffold(
      body: FutureBuilder<List<Table>>(
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
          final tables = snapshot.data!;
          // Group by section
          final bySection = <String, List<Table>>{};
          for (final t in tables) {
            bySection.putIfAbsent(t.section, () => []).add(t);
          }
          final sections = bySection.keys.toList()..sort();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Legend ──
              SizedBox(
                width: 160,
                child: Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legend',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _Legend('Available', Colors.green.shade300),
                        _Legend('Occupied', Colors.red.shade300),
                        _Legend('Reserved', Colors.blue.shade300),
                        _Legend('Dirty', Colors.grey.shade400),
                        const Divider(),
                        IconButton.outlined(
                          icon: const Icon(Icons.refresh),
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Floor plan ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: sections.length,
                  itemBuilder: (context, i) {
                    final section = sections[i];
                    final sectionTables = bySection[section]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    MediaQuery.of(context).size.width > 900
                                    ? 6
                                    : 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: sectionTables.length,
                          itemBuilder: (context, j) {
                            final t = sectionTables[j];
                            return InkWell(
                              onTap: () => _tableAction(t),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _tableColor(t.status),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.black.withOpacity(0.1),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      t.tableNumber,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${t.seats} seats',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    if (t.assignedServer != null)
                                      Text(
                                        t.assignedServer!,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    if (t.seatedAt != null)
                                      Text(
                                        timeFmt.format(t.seatedAt!),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
