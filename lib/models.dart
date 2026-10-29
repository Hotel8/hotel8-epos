// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// H8POS data models.
///
/// Simple Dart classes mirroring the H8POS restaurant contract shapes (see
/// `epos/DESIGN.md` §3) and the BFF
/// proxy surface for H8POS. H8POS is the restaurant point-of-sale staff app
/// - checks, orders, payments, tables, menus, and reports.

// ═══════════════════════════════════════════════════════════════════════════
// Outlet
// ═══════════════════════════════════════════════════════════════════════════

class Outlet {
  final String id;
  final String code;
  final String name;
  final String type; // restaurant, bar, room-service, pool, etc.
  final String? description;
  final bool active;
  final String currencyCode;

  const Outlet({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.description,
    this.active = true,
    this.currencyCode = 'USD',
  });

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    description: json['description'] as String?,
    active: json['active'] as bool? ?? true,
    currencyCode: json['currency_code'] as String? ?? 'USD',
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Menu
// ═══════════════════════════════════════════════════════════════════════════

class MenuCategory {
  final String id;
  final String name;
  final int sortOrder;
  final bool active;

  const MenuCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.active = true,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) => MenuCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    sortOrder: json['sort_order'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );
}

class MenuItem {
  final String id;
  final String name;
  final String categoryId;
  final String? description;
  final double price;
  final String currencyCode;
  final bool active;
  final bool eightySixed; // "86'd"  -  temporarily unavailable
  final List<Modifier> modifiers;

  const MenuItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description,
    required this.price,
    this.currencyCode = 'USD',
    this.active = true,
    this.eightySixed = false,
    this.modifiers = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) => MenuItem(
    id: json['id'] as String,
    name: json['name'] as String,
    categoryId: json['category_id'] as String,
    description: json['description'] as String?,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    currencyCode: json['currency_code'] as String? ?? 'USD',
    active: json['active'] as bool? ?? true,
    eightySixed: json['eighty_sixed'] as bool? ?? false,
    modifiers:
        (json['modifiers'] as List<dynamic>?)
            ?.map((e) => Modifier.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class Modifier {
  final String id;
  final String name;
  final double priceAdjustment;
  final String? modifierGroup; // e.g. "Size", "Temperature", "Add-ons"

  const Modifier({
    required this.id,
    required this.name,
    this.priceAdjustment = 0,
    this.modifierGroup,
  });

  factory Modifier.fromJson(Map<String, dynamic> json) => Modifier(
    id: json['id'] as String,
    name: json['name'] as String,
    priceAdjustment: (json['price_adjustment'] as num?)?.toDouble() ?? 0,
    modifierGroup: json['modifier_group'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Check
// ═══════════════════════════════════════════════════════════════════════════

class Check {
  final String id;
  final String checkNumber;
  final String outletId;
  final String? tableId;
  final String? tableName;
  final String serverId;
  final String serverName;
  final int guests;
  final DateTime openedAt;
  DateTime? closedAt;
  String status; // open, closed, voided, transferred
  List<OrderItem> items;
  double subtotal;
  double tax;
  double total;
  double? tip;
  String? specialInstructions;

  Check({
    required this.id,
    required this.checkNumber,
    required this.outletId,
    this.tableId,
    this.tableName,
    required this.serverId,
    required this.serverName,
    required this.guests,
    required this.openedAt,
    this.closedAt,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.tip,
    this.specialInstructions,
  });

  factory Check.fromJson(Map<String, dynamic> json) => Check(
    id: json['id'] as String,
    checkNumber: json['check_number'] as String,
    outletId: json['outlet_id'] as String,
    tableId: json['table_id'] as String?,
    tableName: json['table_name'] as String?,
    serverId: json['server_id'] as String,
    serverName: json['server_name'] as String,
    guests: json['guests'] as int? ?? 1,
    openedAt: DateTime.parse(json['opened_at'] as String),
    closedAt: json['closed_at'] != null
        ? DateTime.tryParse(json['closed_at'] as String)
        : null,
    status: json['status'] as String? ?? 'open',
    items:
        (json['items'] as List<dynamic>?)
            ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    tax: (json['tax'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    tip: (json['tip'] as num?)?.toDouble(),
    specialInstructions: json['special_instructions'] as String?,
  );
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  double price;
  int quantity;
  List<Modifier> modifiers;
  String? specialInstructions;
  String status; // sent, preparing, served, voided
  DateTime? sentAt;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.modifiers = const [],
    this.specialInstructions,
    this.status = 'sent',
    this.sentAt,
  });

  double get lineTotal =>
      (price + modifiers.fold(0.0, (sum, m) => sum + m.priceAdjustment)) *
      quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as String,
    menuItemId: json['menu_item_id'] as String,
    name: json['name'] as String,
    price: (json['price'] as num?)?.toDouble() ?? 0,
    quantity: json['quantity'] as int? ?? 1,
    modifiers:
        (json['modifiers'] as List<dynamic>?)
            ?.map((e) => Modifier.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    specialInstructions: json['special_instructions'] as String?,
    status: json['status'] as String? ?? 'sent',
    sentAt: json['sent_at'] != null
        ? DateTime.tryParse(json['sent_at'] as String)
        : null,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Payment
// ═══════════════════════════════════════════════════════════════════════════

class Payment {
  final String id;
  final String checkId;
  final double amount;
  final String method; // cash, card, room-charge, comp, split
  final String? reference;
  final DateTime paidAt;
  final String? serverId;

  const Payment({
    required this.id,
    required this.checkId,
    required this.amount,
    required this.method,
    this.reference,
    required this.paidAt,
    this.serverId,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    checkId: json['check_id'] as String,
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    method: json['method'] as String,
    reference: json['reference'] as String?,
    paidAt: DateTime.parse(json['paid_at'] as String),
    serverId: json['server_id'] as String?,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Table
// ═══════════════════════════════════════════════════════════════════════════

class Table {
  final String id;
  final String tableNumber;
  final String section; // Main, Patio, Bar, etc.
  final int seats;
  String status; // available, occupied, reserved, dirty
  String? currentCheckId;
  String? assignedServer;
  DateTime? seatedAt;

  Table({
    required this.id,
    required this.tableNumber,
    required this.section,
    required this.seats,
    required this.status,
    this.currentCheckId,
    this.assignedServer,
    this.seatedAt,
  });

  factory Table.fromJson(Map<String, dynamic> json) => Table(
    id: json['id'] as String,
    tableNumber: json['table_number'] as String,
    section: json['section'] as String,
    seats: json['seats'] as int? ?? 4,
    status: json['status'] as String? ?? 'available',
    currentCheckId: json['current_check_id'] as String?,
    assignedServer: json['assigned_server'] as String?,
    seatedAt: json['seated_at'] != null
        ? DateTime.tryParse(json['seated_at'] as String)
        : null,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Server shift
// ═══════════════════════════════════════════════════════════════════════════

class ServerShift {
  final String id;
  final String serverId;
  final String serverName;
  final DateTime startTime;
  DateTime? endTime;
  String status; // active, ended, break
  double cashStart;
  double? cashEnd;
  int openChecks;
  double totalSales;

  ServerShift({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.cashStart,
    this.cashEnd,
    this.openChecks = 0,
    this.totalSales = 0,
  });

  factory ServerShift.fromJson(Map<String, dynamic> json) => ServerShift(
    id: json['id'] as String,
    serverId: json['server_id'] as String,
    serverName: json['server_name'] as String,
    startTime: DateTime.parse(json['start_time'] as String),
    endTime: json['end_time'] != null
        ? DateTime.tryParse(json['end_time'] as String)
        : null,
    status: json['status'] as String? ?? 'active',
    cashStart: (json['cash_start'] as num?)?.toDouble() ?? 0,
    cashEnd: (json['cash_end'] as num?)?.toDouble(),
    openChecks: json['open_checks'] as int? ?? 0,
    totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Report data
// ═══════════════════════════════════════════════════════════════════════════

class ReportData {
  final String reportType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String currencyCode;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, double> totals;

  const ReportData({
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    this.currencyCode = 'USD',
    required this.columns,
    required this.rows,
    this.totals = const {},
  });

  factory ReportData.fromJson(Map<String, dynamic> json) => ReportData(
    reportType: json['report_type'] as String,
    periodStart: DateTime.parse(json['period_start'] as String),
    periodEnd: DateTime.parse(json['period_end'] as String),
    currencyCode: json['currency_code'] as String? ?? 'USD',
    columns:
        (json['columns'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
    rows:
        (json['rows'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        const [],
    totals:
        (json['totals'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        const {},
  );
}
