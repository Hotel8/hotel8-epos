// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// H8POS BFF client.
///
/// Thin HTTP client that calls the BFF proxy endpoints (see
/// `epos/DESIGN.md` §4) which in turn
/// delegate to H8POS / Payments. All requests go through the BFF server-side
/// token guardian - H8POS never talks to a backend directly.
///
/// Endpoint namespaces used:
///   /proxy/hotel8-pos/v1/outlets/{id}/checks        - checks (+void/transfer/split)
///   /proxy/hotel8-pos/v1/outlets/{id}/checks/{id}/orders - order items
///   /proxy/hotel8-pos/v1/outlets/{id}/checks/{id}/payments / payments-process
///   /proxy/hotel8-pos/v1/outlets/{id}/tables        - tables (+status/seat)
///   /proxy/hotel8-pos/v1/outlets/{id}/menu-items    - items, categories, availability
///   /proxy/hotel8-pos/v1/outlets/{id}/reports/{kind} - sales/items/labor/end-of-day

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'models.dart';

class BffClient {
  BffClient({String? baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl ?? _resolveBaseUrl(),
      _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _httpClient;

  /// Resolve the BFF base URL. In production this is the outlet-scoped
  /// BFF domain (e.g. `https://bff.pos.maintestaurant.pos.sentin8.dev`).
  /// For local development fall back to the `H8POS_BFF_BASE_URL` env var or
  /// `http://localhost:8080`.
  static String _resolveBaseUrl() {
    const env = String.fromEnvironment('H8POS_BFF_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;

    if (kIsWeb) {
      // Same-origin: BFF served alongside the Flutter web app.
      return '';
    }
    return 'http://localhost:8080';
  }

  String _path(String p) => '$_baseUrl$p';

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = Uri.parse(_path(path));
    final resolved = query == null ? uri : uri.replace(queryParameters: query);
    final resp = await _httpClient.get(resolved, headers: _headers());
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.post(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final resp = await _httpClient.put(
      Uri.parse(_path(path)),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final resp = await _httpClient.delete(
      Uri.parse(_path(path)),
      headers: _headers(),
    );
    return _handle(resp);
  }

  Map<String, String> _headers() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// `POST /proxy/hotel8-pos/v1/offline-sync` - replay captured offline ops
  /// after reconnect (epos/DESIGN.md §2 offline mode). The service replays
  /// each op server-side under a single transaction set and reports per-op
  /// status (`SYNCED`/`SKIPPED`).
  Future<Map<String, dynamic>> syncOffline(Map<String, dynamic> body) async {
    return _postJson('/proxy/hotel8-pos/v1/offline-sync', body);
  }

  /// `GET /proxy/hotel8-pos/v1/offline-status` - server view of terminal
  /// sync state (advisory banner on the dashboard).
  Future<Map<String, dynamic>> offlineStatus() async {
    return _getJson('/proxy/hotel8-pos/v1/offline-status');
  }

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    final body = resp.body.isEmpty ? '{}' : resp.body;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String message;
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      message =
          decoded['message'] as String? ?? decoded['error'] as String? ?? body;
    } catch (_) {
      message = body;
    }
    throw BffException(resp.statusCode, message);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Outlets
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets`
  Future<List<Outlet>> getOutlets() async {
    final json = await _getJson('/proxy/hotel8-pos/v1/outlets');
    final list = json['outlets'] as List<dynamic>? ?? [];
    return list.map((e) => Outlet.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Dashboard
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/dashboard`
  Future<Map<String, dynamic>> getDashboard({required String outletId}) async {
    return _getJson('/proxy/hotel8-pos/v1/outlets/$outletId/dashboard');
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Checks
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/checks`
  Future<List<Check>> getChecks({
    required String outletId,
    String? status,
    String? serverId,
    String? tableId,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (serverId != null) query['server_id'] = serverId;
    if (tableId != null) query['table_id'] = tableId;
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks',
      query,
    );
    final list = json['checks'] as List<dynamic>? ?? [];
    return list.map((e) => Check.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/checks/{id}`
  Future<Check> getCheck({
    required String outletId,
    required String checkId,
  }) async {
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId',
    );
    return Check.fromJson(json['check'] as Map<String, dynamic>? ?? json);
  }

  /// `POST /proxy/hotel8-pos/v1/outlets/{outletId}/checks`
  Future<Check> createCheck({
    required String outletId,
    required String tableId,
    required String serverId,
    required int guests,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks',
      {'table_id': tableId, 'server_id': serverId, 'guests': guests},
    );
    return Check.fromJson(json['check'] as Map<String, dynamic>? ?? json);
  }

  /// `PUT /proxy/hotel8-pos/v1/.../checks/{id}/void`
  Future<void> voidCheck({
    required String outletId,
    required String checkId,
    String? reason,
  }) async {
    await _putJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/void',
      {'reason': reason ?? ''},
    );
  }

  /// `PUT /proxy/hotel8-pos/v1/.../checks/{id}/transfer`
  Future<Check> transferCheck({
    required String outletId,
    required String checkId,
    required String toServerId,
  }) async {
    final json = await _putJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/transfer',
      {'to_server_id': toServerId},
    );
    return Check.fromJson(json['check'] as Map<String, dynamic>? ?? json);
  }

  /// `PUT /proxy/hotel8-pos/v1/.../checks/{id}/split`
  Future<List<Check>> splitCheck({
    required String outletId,
    required String checkId,
    required int numChecks,
  }) async {
    final json = await _putJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/split',
      {'num_checks': numChecks},
    );
    final list = json['checks'] as List<dynamic>? ?? [];
    return list.map((e) => Check.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Orders
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pos/v1/outlets/{outletId}/checks/{checkId}/items`
  Future<OrderItem> addOrderItem({
    required String outletId,
    required String checkId,
    required String menuItemId,
    required String name,
    required double price,
    int quantity = 1,
    List<Modifier> modifiers = const [],
    String? specialInstructions,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/orders',
      {
        'menu_item_id': menuItemId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'modifiers': modifiers
            .map(
              (m) => {
                'id': m.id,
                'name': m.name,
                'price_adjustment': m.priceAdjustment,
                'modifier_group': m.modifierGroup,
              },
            )
            .toList(),
        if (specialInstructions != null)
          'special_instructions': specialInstructions,
      },
    );
    return OrderItem.fromJson(
      json['order_item'] as Map<String, dynamic>? ?? json,
    );
  }

  /// `DELETE /proxy/hotel8-pos/v1/.../items/{itemId}`
  Future<void> voidOrderItem({
    required String outletId,
    required String checkId,
    required String itemId,
    String? reason,
  }) async {
    final query = <String, String>{};
    if (reason != null) query['reason'] = reason;
    await _deleteJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/orders/$itemId',
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Payments
  // ═════════════════════════════════════════════════════════════════════════

  /// `POST /proxy/hotel8-pos/v1/outlets/{outletId}/checks/{checkId}/payments`
  Future<Payment> processPayment({
    required String outletId,
    required String checkId,
    required double amount,
    required String method,
    String? reference,
    double? tip,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/payments',
      {
        'amount': amount,
        'method': method,
        if (reference != null) 'reference': reference,
        if (tip != null) 'tip': tip,
      },
    );
    return Payment.fromJson(json['payment'] as Map<String, dynamic>? ?? json);
  }

  /// `POST /proxy/hotel8-pos/v1/outlets/{outletId}/checks/{checkId}/close`
  Future<Check> closeCheck({
    required String outletId,
    required String checkId,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/checks/$checkId/payments-process',
      {},
    );
    return Check.fromJson(json['check'] as Map<String, dynamic>? ?? json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Tables
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/tables`
  Future<List<Table>> getTables({
    required String outletId,
    String? section,
    String? status,
  }) async {
    final query = <String, String>{};
    if (section != null) query['section'] = section;
    if (status != null) query['status'] = status;
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/tables',
      query,
    );
    final list = json['tables'] as List<dynamic>? ?? [];
    return list.map((e) => Table.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `PUT /proxy/hotel8-pos/v1/.../tables/{tableId}`
  Future<Table> updateTable({
    required String outletId,
    required String tableId,
    String? status,
    String? assignedServer,
  }) async {
    final json = await _putJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/tables/$tableId',
      {
        if (status != null) 'status': status,
        if (assignedServer != null) 'assigned_server': assignedServer,
      },
    );
    return Table.fromJson(json['table'] as Map<String, dynamic>? ?? json);
  }

  /// `POST /proxy/hotel8-pos/v1/.../tables/{tableId}/seat`
  Future<Table> seatGuests({
    required String outletId,
    required String tableId,
    required int guests,
    required String serverId,
  }) async {
    final json = await _postJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/tables/$tableId/seat',
      {'guests': guests, 'server_id': serverId},
    );
    return Table.fromJson(json['table'] as Map<String, dynamic>? ?? json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Menu
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/categories`
  Future<List<MenuCategory>> getMenuCategories({
    required String outletId,
  }) async {
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/categories',
    );
    final list = json['categories'] as List<dynamic>? ?? [];
    return list
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/items`
  Future<List<MenuItem>> getMenuItems({
    required String outletId,
    String? categoryId,
  }) async {
    final query = <String, String>{};
    if (categoryId != null) query['category_id'] = categoryId;
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/items',
      query,
    );
    final list = json['items'] as List<dynamic>? ?? [];
    return list
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PUT /proxy/hotel8-pos/v1/.../items/{itemId}/86`
  Future<MenuItem> toggleEightySix({
    required String outletId,
    required String itemId,
    required bool eightySixed,
  }) async {
    final json = await _putJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/menu-items/$itemId/availability',
      {'eighty_sixed': eightySixed},
    );
    return MenuItem.fromJson(json['item'] as Map<String, dynamic>? ?? json);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Server shifts
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/shifts`
  Future<List<ServerShift>> getServerShifts({
    required String outletId,
    String? status,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/shifts',
      query,
    );
    final list = json['shifts'] as List<dynamic>? ?? [];
    return list
        .map((e) => ServerShift.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Reports
  // ═════════════════════════════════════════════════════════════════════════

  /// `GET /proxy/hotel8-pos/v1/outlets/{outletId}/reports/{reportType}`
  Future<ReportData> getReport({
    required String outletId,
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = startDate.toIso8601String().split('T').first;
    }
    if (endDate != null) {
      query['end_date'] = endDate.toIso8601String().split('T').first;
    }
    final json = await _getJson(
      '/proxy/hotel8-pos/v1/outlets/$outletId/reports/$reportType',
      query,
    );
    return ReportData.fromJson(json['report'] as Map<String, dynamic>? ?? json);
  }

  void close() => _httpClient.close();
}

class BffException implements Exception {
  final int statusCode;
  final String message;
  const BffException(this.statusCode, this.message);

  @override
  String toString() => 'BffException($statusCode): $message';
}
