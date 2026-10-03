import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/counter/find_booking_screen.dart';

void main() {
  testWidgets('a devotee without a phone is found by number, opened and marked received', (tester) async {
    final today = DateTime.now();
    final day = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final booking = {
      'kind': 'seva',
      'reference': 'SVABCD2345',
      'code': 'secret-code',
      'status': {'value': 'confirmed', 'label': 'Confirmed'},
      'puja': {'name': 'Archana'},
      'temple': {'name': 'Sri Rama Temple'},
      'booked_for': day,
      'people': 3,
      'devotee_name': 'Lakshmi',
      'devotee_phone': '98480 22338',
      'amount': 'Free',
      'is_free': true,
    };
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      if (req.url.path.endsWith('/bookings/search')) {
        return http.Response(jsonEncode({'data': [booking]}), 200, headers: {'content-type': 'application/json'});
      }
      if (req.url.path.endsWith('/bookings/verify')) {
        return http.Response(jsonEncode({'data': {'outcome': 'verified', 'booking': {...booking, 'status': {'value': 'verified', 'label': 'Received'}, 'verified_at': DateTime.now().toIso8601String()}}}), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: FindBookingScreen())));
    await tester.enterText(find.byType(TextField), '98480 22338');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(requests.first.url.queryParameters['q'], '98480 22338');
    expect(find.textContaining('Lakshmi · 3 people'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);

    await tester.tap(find.textContaining('Lakshmi · 3 people'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Mark received'), 200);
    await tester.tap(find.text('Mark received'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();

    final verify = requests.firstWhere((r) => r.url.path.endsWith('/bookings/verify'));
    expect(jsonDecode(verify.body)['code'], 'secret-code');
    expect(find.text('Marked received.'), findsOneWidget);
  });
}
