// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

/// POS Reports.
///
/// Sales reports, server reports, daily summary, and tax report. The
/// user picks a report type and date range, then views the data in a
/// table format with totals.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bff_client.dart';
import '../models.dart';

class PosReportsPage extends StatefulWidget {
  const PosReportsPage({
    super.key,
    required this.client,
    required this.outletId,
  });

  final BffClient client;
  final String outletId;

  @override
  State<PosReportsPage> createState() => _PosReportsPageState();
}

class _PosReportsPageState extends State<PosReportsPage> {
  String _reportType = 'sales';
  DateTime? _startDate;
  DateTime? _endDate;
  ReportData? _report;
  bool _loading = false;

  static const _reportTypes = [
    ('sales', 'Sales Report', Icons.point_of_sale),
    ('server', 'Server Report', Icons.person),
    ('daily-summary', 'Daily Summary', Icons.summarize),
    ('tax', 'Tax Report', Icons.receipt_long),
  ];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(const Duration(days: 7));
    _endDate = DateTime.now();
  }

  Future<void> _runReport() async {
    setState(() => _loading = true);
    try {
      _report = await widget.client.getReport(
        outletId: widget.outletId,
        reportType: _reportType,
        startDate: _startDate,
        endDate: _endDate,
      );
    } catch (e) {
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Report type selector ──
            Wrap(
              spacing: 8,
              children: _reportTypes.map((rt) {
                final (code, label, icon) = rt;
                final selected = _reportType == code;
                return ChoiceChip(
                  label: Text(label),
                  avatar: Icon(icon, size: 18),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _reportType = code;
                    _report = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // ── Date range ──
            Row(
              children: [
                Text('Date Range:', style: theme.textTheme.titleMedium),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _startDate == null
                        ? 'Start'
                        : DateFormat.yMMMd().format(_startDate!),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _endDate == null
                        ? 'End'
                        : DateFormat.yMMMd().format(_endDate!),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate:
                          _startDate ?? DateTime(DateTime.now().year - 1),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : _runReport,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Run Report'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Results ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _report == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bar_chart,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a report type and run it.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header ──
                            Row(
                              children: [
                                Text(
                                  _report!.reportType.toUpperCase(),
                                  style: theme.textTheme.titleLarge,
                                ),
                                const Spacer(),
                                Text(
                                  '${DateFormat.yMMMd().format(_report!.periodStart)}  -  ${DateFormat.yMMMd().format(_report!.periodEnd)}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                            const Divider(),
                            // ── Table ──
                            Expanded(
                              child: SingleChildScrollView(
                                child: _report!.rows.isEmpty
                                    ? const Center(
                                        child: Text('No data for this period.'),
                                      )
                                    : DataTable(
                                        columns: _report!.columns
                                            .map(
                                              (c) => DataColumn(label: Text(c)),
                                            )
                                            .toList(),
                                        rows: _report!.rows.map((row) {
                                          return DataRow(
                                            cells: _report!.columns.map((col) {
                                              final val = row[col];
                                              String display;
                                              if (val is num) {
                                                display = val is int
                                                    ? val.toString()
                                                    : '\$${val.toStringAsFixed(2)}';
                                              } else {
                                                display =
                                                    val?.toString() ?? '-';
                                              }
                                              return DataCell(Text(display));
                                            }).toList(),
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ),
                            // ── Totals ──
                            if (_report!.totals.isNotEmpty) ...[
                              const Divider(),
                              Text(
                                'Totals',
                                style: theme.textTheme.titleMedium,
                              ),
                              ..._report!.totals.entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(e.key),
                                      Text(
                                        '\$${e.value.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
