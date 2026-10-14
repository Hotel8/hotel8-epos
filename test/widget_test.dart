// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Hotel8:EPOS
// SPDX-License-Identifier: Apache-2.0

// ePOS app smoke test.
//
// Pumps the real root widget (`POSStaffApp`) and asserts the POS shell
// renders with its staff navigation (Dashboard / Checks / Order / Tables /
// Menu / Reports). No network calls are made while building the shell.

import 'package:flutter_test/flutter_test.dart';

import 'package:epos/app.dart';

void main() {
  testWidgets('POSStaffApp renders POS shell with staff navigation', (
    tester,
  ) async {
    await tester.pumpWidget(const POSStaffApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Labels may repeat (nav + page heading) — assert presence.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Checks'), findsWidgets);
    expect(find.text('Order'), findsWidgets);
    expect(find.text('Tables'), findsWidgets);
    expect(find.text('Menu'), findsWidgets);
    expect(find.text('Reports'), findsWidgets);
  });
}
