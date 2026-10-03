import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/events_screen.dart';

Map<String, dynamic> _row(String name, String phone, String ref, String status) => {
      'reference': ref,
      'devotee_name': name,
      'devotee_phone': phone,
      'people': 2,
      'amount_paise': 10000,
      'amount': '₹100.00',
      'status': {'value': status, 'label': status == 'verified' ? 'Received' : 'Confirmed'},
    };

void main() {
  testWidgets('the attendee list is searched by name, phone or reference, and a ticket opens', (tester) async {
    final client = MockClient((req) async {
      if (req.url.path.endsWith('/registrations')) {
        return http.Response(
          jsonEncode({
            'data': {
              'date': '2026-10-10',
              'dates': ['2026-10-10'],
              'summary': {'registrations': 3, 'people': 6, 'received': 1, 'amount_paise': 30000, 'amount': '₹300.00'},
              'items': [
                _row('Lakshmi', '98480 22338', 'EVAAAA2222', 'confirmed'),
                _row('Ravi Kumar', '+91 90000 11111', 'EVBBBB3333', 'verified'),
                _row('Sita', '91234 56789', 'EVCCCC4444', 'confirmed'),
              ],
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (req.url.path.endsWith('/bookings/search')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'kind': 'event',
                'reference': req.url.queryParameters['q'],
                'event': {'title': 'Saturday bhajan'},
                'status': {'value': 'confirmed', 'label': 'Confirmed'},
                'booked_for': '2026-10-10',
                'people': 2,
                'devotee_name': 'Sita',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(home: EventAttendeesScreen(templeId: 1, eventId: 2, title: 'Saturday bhajan')),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lakshmi ·'), findsOneWidget);
    expect(find.textContaining('Ravi Kumar ·'), findsOneWidget);

    // A phone number, typed differently from how it was saved.
    await tester.enterText(find.byType(TextField), '9848022338');
    await tester.pump();
    expect(find.textContaining('Lakshmi ·'), findsOneWidget);
    expect(find.textContaining('Ravi Kumar ·'), findsNothing);

    // A name, and a reference in lower case.
    await tester.enterText(find.byType(TextField), 'ravi');
    await tester.pump();
    expect(find.textContaining('Ravi Kumar ·'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'evcccc');
    await tester.pump();
    expect(find.textContaining('Sita ·'), findsOneWidget);
    expect(find.textContaining('Lakshmi ·'), findsNothing);

    // Received only.
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Received 1'));
    await tester.pump();
    expect(find.textContaining('Ravi Kumar ·'), findsOneWidget);
    expect(find.textContaining('Sita ·'), findsNothing);

    // Tapping a person opens their ticket.
    await tester.tap(find.text('All 3'));
    await tester.pump();
    await tester.scrollUntilVisible(find.textContaining('Sita ·'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Sita ·'));
    await tester.pumpAndSettle();
    expect(find.text('Saturday bhajan'), findsWidgets);
    expect(find.text('EVCCCC4444'), findsOneWidget);
  });
}
