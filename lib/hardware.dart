// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

// ePOS terminal hardware abstraction — payment terminal, printer-group
// routing, and cash drawer behind a platform-channel interface
// (epos/DESIGN.md §2 "Hardware").
//
// The web build cannot host platform channels; `TerminalHardware.platform()`
// returns `UnimplementedHardware` there and surfaces a clear "hardware not
// available in this build" state instead of failing silently. A
// platform-channel-capable build (embedding target) provides the real
// implementation via the `h8pos_hardware` channel; the method contract is
// declared here so the Flutter side and the embedder agree:
//
//   payTerminal(amount, method, reference?) -> { "status": "APPROVED"/"DECLINED", "auth_code": ... }
//   printReceipt(checkNumber, lines)        -> { "status": "OK" }
//   openDrawer()                            -> { "status": "OK" }

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Result of a terminal payment attempt.
class TerminalPaymentResult {
  final String status; // APPROVED | DECLINED
  final String? authCode;

  const TerminalPaymentResult({required this.status, this.authCode});

  bool get approved => status == 'APPROVED';
}

/// Hardware surface the terminal pages call; never throws for absence of
/// hardware — queries return a clear unavailable state.
abstract class TerminalHardware {
  /// Authorize a payment on the integrated terminal.
  Future<TerminalPaymentResult> payTerminal({
    required double amount,
    required String method,
    String? reference,
  });

  /// Print a receipt on the outlet's printer group.
  Future<bool> printReceipt({
    required String checkNumber,
    required List<String> lines,
  });

  /// Open the cash drawer.
  Future<bool> openDrawer();

  /// Whether a real hardware host is attached to this build.
  bool get isAvailable;
}

/// No-op implementation for builds without platform channels (web). Every
/// call reports unavailable — callers render "hardware pending" instead of
/// attempting a payment flow that cannot complete.
class UnimplementedHardware implements TerminalHardware {
  const UnimplementedHardware();

  @override
  bool get isAvailable => false;

  @override
  Future<TerminalPaymentResult> payTerminal({
    required double amount,
    required String method,
    String? reference,
  }) async =>
      const TerminalPaymentResult(status: 'UNAVAILABLE');

  @override
  Future<bool> printReceipt({
    required String checkNumber,
    required List<String> lines,
  }) async =>
      false;

  @override
  Future<bool> openDrawer() async => false;
}

/// Platform-channel implementation for embedding targets. Talks to the
/// embedder's `h8pos_hardware` channel; a MissingPluginException (channel not
/// registered) degrades to UnimplementedHardware behavior.
class PlatformChannelHardware implements TerminalHardware {
  static const MethodChannel _channel = MethodChannel('h8pos_hardware');

  @override
  bool get isAvailable => !kIsWeb;

  @override
  Future<TerminalPaymentResult> payTerminal({
    required double amount,
    required String method,
    String? reference,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'payTerminal',
        {
          'amount': amount,
          'method': method,
          if (reference != null) 'reference': reference,
        },
      );
      return TerminalPaymentResult(
        status: (result?['status'] as String?) ?? 'DECLINED',
        authCode: result?['auth_code'] as String?,
      );
    } on MissingPluginException {
      return const TerminalPaymentResult(status: 'UNAVAILABLE');
    } on PlatformException {
      return const TerminalPaymentResult(status: 'DECLINED');
    }
  }

  @override
  Future<bool> printReceipt({
    required String checkNumber,
    required List<String> lines,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>(
        'printReceipt',
        {'check_number': checkNumber, 'lines': lines},
      );
      return result == 'OK';
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> openDrawer() async {
    try {
      final result = await _channel.invokeMethod<String>('openDrawer');
      return result == 'OK';
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// Hardware chooser: web builds get the unavailable stub; embedding targets
/// get the platform-channel implementation.
TerminalHardware terminalHardware() =>
    kIsWeb ? const UnimplementedHardware() : PlatformChannelHardware();