// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// Payment Processing.
///
/// Handles payment for a check with support for split payments, multiple
/// payment methods (cash, card, room charge), tip entry, and check close.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../offline_queue.dart';
import '../models.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.client,
    required this.outletId,
    required this.check,
  });

  final BffClient client;
  final String outletId;
  final Check check;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  double _tip = 0;
  double _amount = 0;
  String _method = 'cash';
  final _refCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  bool _loading = false;

  // Quick tip percentages
  static const _tipPercents = [0.15, 0.18, 0.20];

  @override
  void initState() {
    super.initState();
    _amount = widget.check.total;
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  double get _totalWithTip => widget.check.total + _tip;
  double get _remaining => _totalWithTip - _amount;

  Future<void> _processPayment() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a payment amount.')));
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.client.processPayment(
        outletId: widget.outletId,
        checkId: widget.check.id,
        amount: _amount,
        method: _method,
        reference: _method == 'card'
            ? (_refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim())
            : _method == 'room-charge'
            ? (_roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim())
            : null,
        tip: _tip > 0 ? _tip : null,
      );
      OfflineQueue.instance.noteSuccess();
      // If balance is settled, close the check
      if (_remaining <= 0.01) {
        await widget.client.closeCheck(
          outletId: widget.outletId,
          checkId: widget.check.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment processed. Check closed.')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment processed. Remaining: \$${_remaining.toStringAsFixed(2)}',
              ),
            ),
          );
        }
        setState(() {
          _amount = _remaining;
          _tip = 0;
        });
      }
    } catch (e) {
      // Network-class failure while disconnected — capture the deferred
      // settlement for replay (epos/DESIGN.md §2 offline mode).
      if (e is BffException && (e.statusCode == 0 || e.statusCode >= 500)) {
        OfflineQueue.instance.noteFailure(
          OfflineOp(
            type: OfflineOpType.paymentPost,
            checkId: widget.check.id,
            idempotencyKey: OfflineQueue.instance.nextIdempotencyKey(),
            payload: {
              'amount': _amount,
              'method': _method,
              'tip': _tip > 0 ? _tip : null,
            },
            capturedAt: DateTime.now(),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Offline — payment queued (${OfflineQueue.instance.queuedCount} in queue).',
              ),
            ),
          );
          Navigator.of(context).pop(false);
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SizedBox(
                width: 500,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Check summary ──
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'Check #${widget.check.checkNumber}',
                                style: theme.textTheme.titleLarge,
                              ),
                              Text(
                                '${widget.check.tableName ?? 'No table'} • ${widget.check.serverName}',
                              ),
                              const Divider(),
                              _Row(
                                'Subtotal',
                                fmt.format(widget.check.subtotal),
                              ),
                              _Row('Tax', fmt.format(widget.check.tax)),
                              if (_tip > 0) _Row('Tip', fmt.format(_tip)),
                              const Divider(),
                              _Row(
                                'Total',
                                fmt.format(_totalWithTip),
                                bold: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // ── Tip selection ──
                      Text('Tip', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ..._tipPercents.map((p) {
                            final tipAmt = widget.check.total * p;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilledButton.tonal(
                                  onPressed: () => setState(() {
                                    _tip = tipAmt;
                                    _amount = _totalWithTip;
                                  }),
                                  child: Text(
                                    '${(p * 100).round()}%\n\$${tipAmt.toStringAsFixed(2)}',
                                  ),
                                ),
                              ),
                            );
                          }),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => setState(() {
                                _tip = 0;
                                _amount = widget.check.total;
                              }),
                              child: const Text('No Tip'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Payment method ──
                      Text(
                        'Payment Method',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MethodButton(
                              icon: Icons.payments,
                              label: 'Cash',
                              selected: _method == 'cash',
                              onTap: () => setState(() => _method = 'cash'),
                            ),
                          ),
                          Expanded(
                            child: _MethodButton(
                              icon: Icons.credit_card,
                              label: 'Card',
                              selected: _method == 'card',
                              onTap: () => setState(() => _method = 'card'),
                            ),
                          ),
                          Expanded(
                            child: _MethodButton(
                              icon: Icons.hotel,
                              label: 'Room',
                              selected: _method == 'room-charge',
                              onTap: () =>
                                  setState(() => _method = 'room-charge'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── Reference field (conditional) ──
                      if (_method == 'card')
                        TextField(
                          controller: _refCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Card reference',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      if (_method == 'room-charge')
                        TextField(
                          controller: _roomCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Room number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // ── Amount ──
                      TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '\$',
                          border: const OutlineInputBorder(),
                          suffixText:
                              'Remaining: \$${_remaining.toStringAsFixed(2)}',
                        ),
                        controller: TextEditingController(
                          text: _amount.toStringAsFixed(2),
                        ),
                        onChanged: (v) => _amount = double.tryParse(v) ?? 0,
                      ),
                      const SizedBox(height: 16),
                      // ── Action ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _processPayment,
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: Text(
                            _remaining <= 0.01
                                ? 'Process Payment & Close'
                                : 'Process Payment',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? Theme.of(context).textTheme.titleMedium : null,
          ),
          Text(
            value,
            style: bold
                ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 72,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: selected
                ? theme.colorScheme.primaryContainer
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
