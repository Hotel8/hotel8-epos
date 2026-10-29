// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Check Detail.
///
/// Shows the full check with order items (modifiers, quantities), totals
/// (subtotal, tax, total), and actions: Split, Transfer, Void, Payment.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';
import 'order_entry_page.dart';
import 'payment_page.dart';

class CheckDetailPage extends StatefulWidget {
  const CheckDetailPage({
    super.key,
    required this.client,
    required this.outletId,
    required this.checkId,
  });

  final BffClient client;
  final String outletId;
  final String checkId;

  @override
  State<CheckDetailPage> createState() => _CheckDetailPageState();
}

class _CheckDetailPageState extends State<CheckDetailPage> {
  late Future<Check> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.getCheck(
      outletId: widget.outletId,
      checkId: widget.checkId,
    );
  }

  void _refresh() {
    setState(() {
      _future = widget.client.getCheck(
        outletId: widget.outletId,
        checkId: widget.checkId,
      );
    });
  }

  Future<void> _voidItem(OrderItem item) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('Void: ${item.name}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Reason',
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
                ctrl.text.trim().isEmpty ? 'N/A' : ctrl.text.trim(),
              ),
              child: const Text('Void'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await widget.client.voidOrderItem(
        outletId: widget.outletId,
        checkId: widget.checkId,
        itemId: item.id,
        reason: reason,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _voidCheck() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Entire Check'),
        content: const Text(
          'This will void all items on this check. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void Check'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.voidCheck(
        outletId: widget.outletId,
        checkId: widget.checkId,
        reason: 'Manager void',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _split() async {
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '2');
        return AlertDialog(
          title: const Text('Split Check'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Number of checks',
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
              child: const Text('Split'),
            ),
          ],
        );
      },
    );
    if (n == null) return;
    try {
      await widget.client.splitCheck(
        outletId: widget.outletId,
        checkId: widget.checkId,
        numChecks: n,
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _transfer() async {
    // Simple transfer - in production this would show a server picker.
    final server = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Transfer Check'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Transfer to server ID',
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
              child: const Text('Transfer'),
            ),
          ],
        );
      },
    );
    if (server == null) return;
    try {
      await widget.client.transferCheck(
        outletId: widget.outletId,
        checkId: widget.checkId,
        toServerId: server,
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
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    final timeFmt = DateFormat.Hm();
    return Scaffold(
      appBar: AppBar(title: const Text('Check Detail')),
      body: FutureBuilder<Check>(
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
          final check = snapshot.data!;
          return Column(
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.surfaceContainerLow,
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check #${check.checkNumber}',
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${check.tableName ?? 'No table'} • ${check.serverName} • ${check.guests} guests',
                        ),
                        Text('Opened: ${timeFmt.format(check.openedAt)}'),
                      ],
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(check.status.toUpperCase()),
                      backgroundColor: <String, Color>{
                        'open': Colors.green.shade100,
                        'closed': Colors.grey.shade300,
                        'voided': Colors.red.shade100,
                      }[check.status],
                    ),
                  ],
                ),
              ),
              // ── Items ──
              Expanded(
                child: check.items.isEmpty
                    ? const Center(child: Text('No items on this check.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: check.items.length,
                        itemBuilder: (context, i) {
                          final item = check.items[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${item.quantity}x'),
                              ),
                              title: Text(item.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.modifiers.isNotEmpty)
                                    Text(
                                      item.modifiers
                                          .map((m) => m.name)
                                          .join(', '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  if (item.specialInstructions != null)
                                    Text(
                                      'Note: ${item.specialInstructions}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  Text(
                                    item.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fmt.format(item.lineTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (check.status == 'open') ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _voidItem(item),
                                      tooltip: 'Void item',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // ── Totals & actions ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  border: Border(top: BorderSide(color: theme.dividerColor)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal'),
                          Text(fmt.format(check.subtotal)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tax'),
                          Text(fmt.format(check.tax)),
                        ],
                      ),
                      if (check.tip != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tip'),
                            Text(fmt.format(check.tip!)),
                          ],
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: theme.textTheme.titleLarge),
                          Text(
                            fmt.format(check.total),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (check.status == 'open') ...[
                        // ── Action buttons ──
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => OrderEntryPage(
                                        client: widget.client,
                                        outletId: widget.outletId,
                                        checkId: check.id,
                                      ),
                                    ),
                                  )
                                  .then((_) => _refresh()),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Items'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => PaymentPage(
                                        client: widget.client,
                                        outletId: widget.outletId,
                                        check: check,
                                      ),
                                    ),
                                  )
                                  .then((_) => _refresh()),
                              icon: const Icon(Icons.payments),
                              label: const Text('Payment'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _split,
                              icon: const Icon(Icons.call_split),
                              label: const Text('Split'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _transfer,
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('Transfer'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _voidCheck,
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text('Void Check'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
