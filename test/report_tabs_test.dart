import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/finance_screen.dart';

void main() {
  testWidgets('the financial report shows every period the server sends, with its breakdown', (tester) async {
    Map<String, dynamic> period(int bookings, int sevas, int tickets, int gifts) => {
          'from': '2026-01-01',
          'to': '2026-12-31',
          'bookings': bookings,
          'people': bookings * 2,
          'amount_paise': sevas,
          'tickets': {'count': 2, 'people': 5, 'amount_paise': tickets},
          'donations': {'count': 3, 'amount_paise': gifts},
          'total_paise': sevas + tickets + gifts,
        };
    final client = MockClient((req) async {
      expect(req.headers['Accept-Language'], 'en');
      return http.Response(
        jsonEncode({
          'data': {
            'today': period(1, 50000, 0, 0),
            'day': {'bookings': 1, 'people': 2, 'amount_paise': 50000, 'received': 0, 'to_receive': 1, 'by_seva': [], 'tickets': {'count': 0}, 'donations': {'count': 0}},
            'month': period(10, 500000, 100000, 20000),
            'year': period(120, 6000000, 1200000, 240000),
            'all_time': period(500, 25000000, 5000000, 1000000),
            'balance': {
              'fee_percent': 5,
              'ready': {'bookings': 4, 'tickets': 0, 'donations': 0, 'gross_paise': 200000, 'fee_paise': 10000, 'net_paise': 190000},
              'upcoming': {'bookings': 2, 'gross_paise': 100000},
              'in_payout': {'settlements': 0, 'net_paise': 0},
              'paid': {'settlements': 3, 'net_paise': 900000},
            },
            'payout_account': null,
            'can_edit_payout_account': true,
            'accepts_donations': true,
            'recent_settlements': [],
          }
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: FinanceScreen(templeId: 1, title: 'Sri Rama Temple'))));
    await tester.pumpAndSettle();

    // Opens on the month.
    expect(find.text('₹6,200.00'), findsWidgets);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.text('₹3,10,000.00'), findsWidgets);
    expect(find.text('500'), findsOneWidget);
  });
}
