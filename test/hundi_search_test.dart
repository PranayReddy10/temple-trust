import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/donations_screen.dart';

void main() {
  testWidgets('hundi gifts are searched by donor name or phone on the server', (tester) async {
    final queries = <String?>[];
    final gifts = [
      {'reference': 'HDAAAA2222', 'donor': 'Lakshmi Devi', 'amount': '₹501.00', 'purpose': {'label': 'General'}, 'status': {'value': 'paid', 'label': 'Paid'}, 'paid_on': '2026-10-10'},
      {'reference': 'HDBBBB3333', 'donor': 'Ravi Kumar', 'amount': '₹101.00', 'purpose': {'label': 'Annadanam'}, 'status': {'value': 'paid', 'label': 'Paid'}, 'paid_on': '2026-10-10'},
    ];
    final client = MockClient((req) async {
      final q = req.url.queryParameters['q'];
      queries.add(q);
      final items = q == null ? gifts : gifts.where((g) => '${g['donor']}'.toLowerCase().contains(q.toLowerCase())).toList();
      return http.Response(
        jsonEncode({
          'data': {
            'accepts_donations': true,
            'can_change': true,
            'today': {'count': 2, 'amount_paise': 60200},
            'month': {'count': 2, 'amount_paise': 60200},
            'total': {'count': 2, 'amount_paise': 60200},
            'items': items,
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: DonationsScreen(templeId: 1))));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.textContaining('Ravi Kumar ·'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Lakshmi Devi ·'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laksh');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(queries.last, 'laksh');
    expect(find.textContaining('Lakshmi Devi ·'), findsOneWidget);
    expect(find.textContaining('Ravi Kumar ·'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('No gift matches "nobody".'), findsOneWidget);
  });
}
