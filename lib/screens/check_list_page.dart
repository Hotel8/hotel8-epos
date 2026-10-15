// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Check List.
///
/// Lists all open checks with search (by check number, table, server) and
/// filter (by status). Tapping a check opens the check detail page.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'check_detail_page.dart';

class CheckListPage extends StatefulWidget {
  const CheckListPage({
    super.key,
    required this.client,
    required this.outletId,
  });

  final BffClient client;
  final String outletId;

  @override
  State<CheckListPage> createState() => _CheckListPageState();
}

class _CheckListPageState extends State<CheckListPage> {
  late Future<List<Check>> _future;
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'open';

  @override
  void initState() {
    super.initState();
    _future = widget.client.getChecks(
      outletId: widget.outletId,
      status: _statusFilter,
    );
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getChecks(
        outletId: widget.outletId,
        status: _statusFilter.isEmpty ? null : _statusFilter,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final timeFmt = DateFormat.Hm();
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Search & filter ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search check #, table, server',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All')),
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    DropdownMenuItem(value: 'voided', child: Text('Voided')),
                  ],
                  onChanged: (v) {
                    _statusFilter = v ?? '';
                    _refresh();
                  },
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── List ──
            Expanded(
              child: FutureBuilder<List<Check>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  var checks = snapshot.data!;
                  // Local search filter
                  final q = _searchCtrl.text.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    checks = checks.where((c) {
                      return c.checkNumber.toLowerCase().contains(q) ||
                          (c.tableName?.toLowerCase().contains(q) ?? false) ||
                          c.serverName.toLowerCase().contains(q);
                    }).toList();
                  }
                  if (checks.isEmpty) {
                    return const Center(child: Text('No checks found.'));
                  }
                  return ListView.builder(
                    itemCount: checks.length,
                    itemBuilder: (context, i) {
                      final c = checks[i];
                      final statusColor =
                          <String, Color>{
                            'open': Colors.green,
                            'closed': Colors.grey,
                            'voided': Colors.red,
                            'transferred': Colors.blue,
                          }[c.status] ??
                          Colors.grey;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: statusColor.withOpacity(0.2),
                            child: Text(
                              c.tableName ?? c.checkNumber.substring(0, 2),
                            ),
                          ),
                          title: Text('Check #${c.checkNumber}'),
                          subtitle: Text(
                            '${c.tableName ?? 'No table'} • ${c.serverName} • ${c.guests} guests • ${timeFmt.format(c.openedAt)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                fmt.format(c.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${c.items.length} items',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckDetailPage(
                                client: widget.client,
                                outletId: widget.outletId,
                                checkId: c.id,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
