// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Order Entry.
///
/// Menu-based ordering with categories in a left sidebar, items in a
/// center grid, modifier selection dialogs, special instructions field,
/// and a cart / order summary on the right. Can be used standalone (to
/// create a new check) or with an existing check (to add items).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../offline_queue.dart';
import '../models.dart';
import 'check_detail_page.dart';

class OrderEntryPage extends StatefulWidget {
  const OrderEntryPage({
    super.key,
    required this.client,
    required this.outletId,
    this.checkId,
  });

  final BffClient client;
  final String outletId;
  final String? checkId;

  @override
  State<OrderEntryPage> createState() => _OrderEntryPageState();
}

class _OrderEntryPageState extends State<OrderEntryPage> {
  List<MenuCategory> _categories = [];
  List<MenuItem> _items = [];
  String? _selectedCategoryId;
  final _cart = <OrderItem>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      _categories = await widget.client.getMenuCategories(
        outletId: widget.outletId,
      );
      _items = await widget.client.getMenuItems(outletId: widget.outletId);
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MenuItem> get _filteredItems {
    if (_selectedCategoryId == null) return _items;
    return _items.where((i) => i.categoryId == _selectedCategoryId).toList();
  }

  double get _cartTotal => _cart.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> _addItem(MenuItem item) async {
    // Show modifier dialog
    List<Modifier> selectedMods = [];
    String? specialInstr;

    if (item.modifiers.isNotEmpty) {
      final result = await showDialog<({List<Modifier> mods, String? instr})>(
        context: context,
        builder: (ctx) => _ModifierDialog(item: item),
      );
      if (result == null) return;
      selectedMods = result.mods;
      specialInstr = result.instr;
    } else {
      // Quick add — check for special instructions
      final instr = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(item.name),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Special instructions (optional)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'add'),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (instr == null) return;
      if (instr == 'add') {
        // Add without instructions
      } else {
        specialInstr = instr.isEmpty ? null : instr;
      }
    }

    setState(() {
      _cart.add(
        OrderItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          menuItemId: item.id,
          name: item.name,
          price: item.price,
          quantity: 1,
          modifiers: selectedMods,
          specialInstructions: specialInstr,
        ),
      );
    });
  }

  Future<void> _sendOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _loading = true);
    try {
      String checkId = widget.checkId ?? '';
      if (checkId.isEmpty) {
        // Create a new check first (assumes a default table/server for quick order)
        final check = await widget.client.createCheck(
          outletId: widget.outletId,
          tableId: 'pos-counter',
          serverId: 'current-server',
          guests: 1,
        );
        checkId = check.id;
      }
      for (final item in _cart) {
        try {
          await widget.client.addOrderItem(
            outletId: widget.outletId,
            checkId: checkId,
            menuItemId: item.menuItemId,
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            modifiers: item.modifiers,
            specialInstructions: item.specialInstructions,
          );
          OfflineQueue.instance.noteSuccess();
        } on BffException catch (e) {
          // Network-class failure while disconnected — capture the line for
          // replay (epos/DESIGN.md §2 offline mode) and continue with the
          // remaining lines so the ticket is fully queued.
          if (_isNetworkError(e)) {
            OfflineQueue.instance.noteFailure(
              OfflineOp(
                type: OfflineOpType.orderAdd,
                checkId: checkId,
                idempotencyKey: OfflineQueue.instance.nextIdempotencyKey(),
                payload: {
                  'menu_item_id': item.menuItemId,
                  'quantity': item.quantity,
                  'name': item.name,
                  'price': item.price,
                  'modifiers': item.modifiers,
                  'special_instructions': item.specialInstructions,
                },
                capturedAt: DateTime.now(),
              ),
            );
          } else {
            rethrow;
          }
        }
      }
      if (mounted) {
        final q = OfflineQueue.instance;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              q.queuedCount > 0
                  ? 'Terminal offline — ${q.queuedCount} operation(s) queued '
                        'and will sync when reconnected.'
                  : 'Order sent!',
            ),
          ),
        );
        // Navigate to check detail or payment
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CheckDetailPage(
              client: widget.client,
              outletId: widget.outletId,
              checkId: checkId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Network-class errors (queueable) vs domain errors (surface now).
  static bool _isNetworkError(BffException e) =>
      e.statusCode == 0 || e.statusCode >= 500;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ── Categories ──
                SizedBox(
                  width: 140,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _categories.length,
                    itemBuilder: (context, i) {
                      final cat = _categories[i];
                      final selected = _selectedCategoryId == cat.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: FilledButton.tonal(
                          onPressed: () =>
                              setState(() => _selectedCategoryId = cat.id),
                          style: FilledButton.styleFrom(
                            backgroundColor: selected
                                ? theme.colorScheme.primaryContainer
                                : null,
                          ),
                          child: Text(cat.name),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Items grid ──
                Expanded(
                  flex: 2,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.4,
                        ),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, i) {
                      final item = _filteredItems[i];
                      final is86ed = item.eightySixed;
                      return Card(
                        color: is86ed
                            ? Colors.grey.shade300
                            : theme.colorScheme.surfaceContainerLow,
                        child: InkWell(
                          onTap: is86ed ? null : () => _addItem(item),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      item.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: is86ed ? Colors.grey : null,
                                        decoration: is86ed
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  is86ed ? '86\'d' : fmt.format(item.price),
                                  style: TextStyle(
                                    color: is86ed ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Cart ──
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: theme.colorScheme.primaryContainer,
                        child: Text(
                          'Current Order',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: _cart.isEmpty
                            ? const Center(child: Text('No items added.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _cart.length,
                                itemBuilder: (context, i) {
                                  final item = _cart[i];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        '${item.quantity}x ${item.name}',
                                      ),
                                      subtitle: item.modifiers.isNotEmpty
                                          ? Text(
                                              item.modifiers
                                                  .map((m) => m.name)
                                                  .join(', '),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            )
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(fmt.format(item.lineTotal)),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                            onPressed: () => setState(
                                              () => _cart.removeAt(i),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          border: Border(
                            top: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total',
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  Text(
                                    fmt.format(_cartTotal),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _cart.isEmpty || _loading
                                      ? null
                                      : _sendOrder,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(
                                    widget.checkId != null
                                        ? 'Add to Check'
                                        : 'Send Order',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ModifierDialog extends StatefulWidget {
  final MenuItem item;
  const _ModifierDialog({required this.item});

  @override
  State<_ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends State<_ModifierDialog> {
  final _selected = <Modifier>{};
  final _instrCtrl = TextEditingController();

  @override
  void dispose() {
    _instrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Group modifiers by modifierGroup
    final groups = <String, List<Modifier>>{};
    for (final m in widget.item.modifiers) {
      final key = m.modifierGroup ?? 'Options';
      groups.putIfAbsent(key, () => []).add(m);
    }
    return AlertDialog(
      title: Text(widget.item.name),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...groups.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  ...entry.value.map((m) {
                    return CheckboxListTile(
                      value: _selected.contains(m),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(m);
                        } else {
                          _selected.remove(m);
                        }
                      }),
                      title: Text(m.name),
                      subtitle: m.priceAdjustment > 0
                          ? Text('+\$${m.priceAdjustment.toStringAsFixed(2)}')
                          : null,
                      dense: true,
                    );
                  }),
                  const Divider(),
                ],
              );
            }),
            TextField(
              controller: _instrCtrl,
              decoration: const InputDecoration(
                labelText: 'Special instructions',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            mods: _selected.toList(),
            instr: _instrCtrl.text.trim().isEmpty
                ? null
                : _instrCtrl.text.trim(),
          )),
          child: const Text('Add to Order'),
        ),
      ],
    );
  }
}
