// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Menu Management.
///
/// Manage menu items by category: view items, filter, toggle 86'd
/// status, and edit pricing. Shows categories sidebar, items grid
/// with price, status, and modifier count.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({
    super.key,
    required this.client,
    required this.outletId,
  });

  final BffClient client;
  final String outletId;

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage> {
  List<MenuCategory> _categories = [];
  List<MenuItem> _items = [];
  String? _selectedCategoryId;
  bool _loading = false;
  String _search = '';

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
    var items = _selectedCategoryId == null
        ? _items
        : _items.where((i) => i.categoryId == _selectedCategoryId).toList();
    if (_search.isNotEmpty) {
      items = items
          .where((i) => i.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }
    return items;
  }

  Future<void> _toggle86(MenuItem item) async {
    try {
      await widget.client.toggleEightySix(
        outletId: widget.outletId,
        itemId: item.id,
        eightySixed: !item.eightySixed,
      );
      _loadMenu();
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
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // ── Categories sidebar ──
                SizedBox(
                  width: 180,
                  child: Card(
                    margin: const EdgeInsets.all(8),
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        Text('Categories', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ListTile(
                          selected: _selectedCategoryId == null,
                          title: const Text('All'),
                          onTap: () =>
                              setState(() => _selectedCategoryId = null),
                          dense: true,
                        ),
                        ..._categories.map((c) {
                          return ListTile(
                            selected: _selectedCategoryId == c.id,
                            title: Text(c.name),
                            subtitle: Text(
                              '${_items.where((i) => i.categoryId == c.id).length} items',
                            ),
                            onTap: () =>
                                setState(() => _selectedCategoryId = c.id),
                            dense: true,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // ── Items ──
                Expanded(
                  child: Column(
                    children: [
                      // ── Search bar ──
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Search items',
                                  prefixIcon: Icon(Icons.search, size: 20),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadMenu,
                            ),
                          ],
                        ),
                      ),
                      // ── Item grid ──
                      Expanded(
                        child: _filteredItems.isEmpty
                            ? const Center(child: Text('No items found.'))
                            : GridView.builder(
                                padding: const EdgeInsets.all(12),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 250,
                                      childAspectRatio: 1.5,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemCount: _filteredItems.length,
                                itemBuilder: (context, i) {
                                  final item = _filteredItems[i];
                                  return Card(
                                    color: item.eightySixed
                                        ? Colors.grey.shade300
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.name,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    decoration: item.eightySixed
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                              if (item.modifiers.isNotEmpty)
                                                Chip(
                                                  label: Text(
                                                    '${item.modifiers.length} mods',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ),
                                            ],
                                          ),
                                          if (item.description != null)
                                            Text(
                                              item.description!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const Spacer(),
                                          Row(
                                            children: [
                                              Text(
                                                fmt.format(item.price),
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.eightySixed
                                                      ? Colors.grey
                                                      : Colors.green,
                                                ),
                                              ),
                                              const Spacer(),
                                              FilledButton.tonalIcon(
                                                onPressed: () =>
                                                    _toggle86(item),
                                                icon: Icon(
                                                  item.eightySixed
                                                      ? Icons.check
                                                      : Icons.block,
                                                  size: 18,
                                                  color: item.eightySixed
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                                label: Text(
                                                  item.eightySixed
                                                      ? 'Un-86'
                                                      : '86',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
