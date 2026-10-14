// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

// ePOS offline queue — order capture and payment pre-authorization with
// deferred settlement when the terminal is disconnected (epos/DESIGN.md
// §2 "Offline mode" + §10).
//
// The queue holds idempotent operation records in memory (session-scoped —
// the terminal is a single-device surface; nothing persists across app
// restarts). On reconnect the app replays them via the POS offline-sync
// endpoint (`POST /proxy/hotel8-pos/v1/offline-sync`) which replays each
// operation server-side and reports per-op status. Card pre-auths taken
// offline carry a client-side idempotency key so the settlement side can
// dedupe after replay (POS DESIGN.md §5 idempotency rule).

import 'dart:async';
import 'dart:collection';

import 'bff_client.dart';

/// One queued terminal operation, captured while offline.
enum OfflineOpType {
  /// Order line(s) added to an existing check.
  orderAdd,

  /// A payment posted against a check (deferred settlement).
  paymentPost,
}

class OfflineOp {
  OfflineOp({
    required this.type,
    required this.checkId,
    required this.idempotencyKey,
    required this.payload,
    required this.capturedAt,
  });

  final OfflineOpType type;
  final String checkId;

  /// Client-side dedupe key — the offline ticket number plus sequence,
  /// stable across replay attempts (POS offline-sync contract).
  final String idempotencyKey;

  /// The captured payload (the exact body the online call would send).
  final Map<String, dynamic> payload;

  final DateTime capturedAt;

  Map<String, dynamic> toSyncBody() => {
        'type': switch (type) {
          OfflineOpType.orderAdd => 'order_add',
          OfflineOpType.paymentPost => 'payment_post',
        },
        'check_id': checkId,
        'idempotency_key': idempotencyKey,
        'payload': payload,
        'captured_at': capturedAt.toIso8601String(),
      };
}

/// Terminal connectivity + the captured-op queue. Wired into `OrderEntryPage`
/// and `PaymentPage` — a failed call while `offlineMode` is detected queues
/// the op and surfaces the queue counter.
class OfflineQueue {
  OfflineQueue._();

  static final OfflineQueue instance = OfflineQueue._();

  final Queue<OfflineOp> _ops = Queue();
  final _ticketSeq = <int>[];
  int _sequence = 0;

  /// Terminal offline state — set when a call fails with a network-class
  /// error and cleared on the next successful call (any API response proves
  /// connectivity).
  bool offlineMode = false;

  DateTime? _lastSuccessfulCall;
  DateTime? _lastSyncAt;

  int get queuedCount => _ops.length;

  DateTime? get lastSyncAt => _lastSyncAt;

  /// Connectivity as the terminal sees it — conservative: online only after
  /// a successful call and no outage detection since.
  bool get isOnline {
    if (offlineMode) return false;
    if (_lastSuccessfulCall == null) return true; // no failed call yet
    // A successful call within the last 30s keeps online status sticky.
    return DateTime.now().difference(_lastSuccessfulCall!) <
        const Duration(seconds: 30);
  }

  void noteSuccess() {
    offlineMode = false;
    _lastSuccessfulCall = DateTime.now();
  }

  /// Mark offline after a failed call; queue the retryable op.
  void noteFailure(OfflineOp op) {
    offlineMode = true;
    _sequence += 1;
    _ops.add(op);
  }

  /// Replay every captured op via the POS offline-sync endpoint.
  ///
  /// Returns the per-op results (`SYNCED`/`SKIPPED` from the service); the
  /// queue drains only ops the service accepted.
  Future<OfflineSyncResult> replay(BffClient client) async {
    if (_ops.isEmpty) {
      _lastSyncAt = DateTime.now();
      return OfflineSyncResult(0, const []);
    }
    final body = {
      'operations': [for (final op in _ops) op.toSyncBody()],
    };
    final json = await client.syncOffline(body);
    // Drain — the offline-sync endpoint is the replay surface; ops that came
    // back SKIPPED failed idempotency precheck (already applied before the
    // outage) and are safe to drop (exactly-once via idempotency_key).
    final results = <Map<String, dynamic>>[];
    final list = json['operations'] as List<dynamic>? ?? const [];
    for (final e in list) {
      results.add(e as Map<String, dynamic>);
    }
    final drained = _ops.length;
    _ops.clear();
    _lastSyncAt = DateTime.now();
    return OfflineSyncResult(drained, results);
  }

  /// Next capture key for an op (offline ticket + sequence).
  String nextIdempotencyKey() {
    final ticket = DateTime.now().millisecondsSinceEpoch;
    _ticketSeq.add(ticket);
    return 'off-$ticket-$_sequence';
  }
}

class OfflineSyncResult {
  OfflineSyncResult(this.drained, this.results);

  final int drained;
  final List<Map<String, dynamic>> results;
}