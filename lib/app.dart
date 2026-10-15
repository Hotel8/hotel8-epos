// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'package:sentin8/sentin8.dart';

import 'bff_client.dart';
import 'screens/check_list_page.dart';
import 'screens/menu_management_page.dart';
import 'screens/order_entry_page.dart';
import 'screens/pos_dashboard_page.dart';
import 'screens/pos_reports_page.dart';
import 'screens/table_management_page.dart';

class POSStaffApp extends StatelessWidget {
  const POSStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS — Restaurant POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const POSShell(),
    );
  }
}

/// POS-style shell with a sidebar navigation: Dashboard, Checks, Order,
/// Tables, Menu, Reports. Uses large touch-friendly icons.
class POSShell extends StatefulWidget {
  const POSShell({super.key});

  @override
  State<POSShell> createState() => _POSShellState();
}

class _POSShellState extends State<POSShell> {
  AppRuntimeContext? _runtimeContext;
  BffClient? _client;
  String? _outletId;
  String? _bootstrapError;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Same-origin bootstrap — TLS injects the X-Sentin8-* host headers
      // the runtime context resolves from (epos/DESIGN.md §2).
      final ctx = await fetchRuntimeContext(appBaseUrl: '');
      final client = BffClient(baseUrl: ctx.bffBaseUrl);
      // First outlet of the property's POS deployment — the terminal's
      // outlet assignment is a property-level configuration; multi-outlet
      // selection arrives with the outlet registry page.
      String? outletId;
      try {
        final outlets = await client.getOutlets();
        if (outlets.isNotEmpty) outletId = outlets.first.id;
      } on BffException {
        // Terminal still renders — screens show their own empty states.
      }
      setState(() {
        _runtimeContext = ctx;
        _client = client;
        _outletId = outletId;
      });
    } catch (e) {
      setState(() => _bootstrapError = e.toString());
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  static const _items = <_NavItem>[
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.receipt_long, label: 'Checks'),
    _NavItem(icon: Icons.point_of_sale, label: 'Order'),
    _NavItem(icon: Icons.table_restaurant, label: 'Tables'),
    _NavItem(icon: Icons.restaurant_menu, label: 'Menu'),
    _NavItem(icon: Icons.bar_chart, label: 'Reports'),
  ];

  String get _title => _items[_index].label;

  Widget _pageFor(int index) {
    final client = _client;
    final outletId = _outletId;
    if (client == null || outletId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (index) {
      case 0:
        return PosDashboardPage(client: client, outletId: outletId);
      case 1:
        return CheckListPage(client: client, outletId: outletId);
      case 2:
        return OrderEntryPage(client: client, outletId: outletId);
      case 3:
        return TableManagementPage(client: client, outletId: outletId);
      case 4:
        return MenuManagementPage(client: client, outletId: outletId);
      case 5:
        return PosReportsPage(client: client, outletId: outletId);
      default:
        return PosDashboardPage(client: client, outletId: outletId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 100,
            color: theme.colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                SizedBox(
                  height: 80,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 2),
                        Text('POS', style: theme.textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final selected = _index == i;
                      return Material(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _index = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 28,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
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
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: const Icon(Icons.person),
                      ),
                      const SizedBox(height: 4),
                      Text('Server', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // ── Main area ──
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                title: Text(_title),
                actions: [
                  Chip(
                    label: Text('Outlet: $_outletId'),
                    avatar: const Icon(Icons.store, size: 18),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: _pageFor(_index),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
