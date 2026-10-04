import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/bookings_screen.dart';

void main() {
  testWidgets('the seva bookings list is searched by name or phone on the server', (tester) async {
    final queries = <String?>[];
    final statuses = <String?>[];
    final client = MockClient((req) async {
      queries.add(req.url.queryParameters['q']);
      statuses.add(req.url.queryParameters['status']);
      final q = req.url.queryParameters['q'];
      final all = [
        {'reference': 'SVAAAA2222', 'devotee_name': 'Lakshmi', 'devotee_phone': '98480 22338', 'people': 2, 'booked_for': '2026-10-10', 'puja': {'name': 'Archana'}, 'status': {'value': 'confirmed', 'label': 'Confirmed'}},
        {'reference': 'SVBBBB3333', 'devotee_name': 'Ravi', 'devotee_phone': '90000 11111', 'people': 1, 'booked_for': '2026-10-10', 'puja': {'name': 'Abhishekam'}, 'status': {'value': 'confirmed', 'label': 'Confirmed'}},
      ];
      final data = q == null ? all : all.where((b) => '${b['devotee_name']}'.toLowerCase().contains(q.toLowerCase()) || '${b['devotee_phone']}'.replaceAll(' ', '').contains(q)).toList();
      return http.Response(jsonEncode({'data': data}), 200, headers: {'content-type': 'application/json'});
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: BookingsScreen(templeId: 1))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lakshmi ·'), findsOneWidget);
    expect(find.textContaining('Ravi ·'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '22338');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(queries.last, '22338');
    expect(find.textContaining('Lakshmi ·'), findsOneWidget);
    expect(find.textContaining('Ravi ·'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'nobody');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('No booking matches "nobody".'), findsOneWidget);

    // Only the successful bookings are asked for until a filter says otherwise.
    expect(statuses.toSet(), {'successful'});
    await tester.tap(find.text('Cancelled'));
    await tester.pumpAndSettle();
    expect(statuses.last, 'cancelled');
  });
}
