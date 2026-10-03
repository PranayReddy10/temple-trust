import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/admin/admin_finance_screen.dart';

void main() {
  testWidgets('the settlements screen narrows to a temple by name or town', (tester) async {
    Map<String, dynamic> temple(int id, String name, String city) => {
          'id': id, 'name': name, 'city': city,
          'ready_bookings': 3, 'ready_gross_paise': 100000, 'ready_net_paise': 95000, 'fee_percent': 5,
          'payout_account': {'is_complete': true, 'is_verified': true},
        };
    final client = MockClient((req) async {
      final body = req.url.path.endsWith('/admin/finance')
          ? {
              'data': {
                'today': {}, 'collected_today': {}, 'month': {},
                'ready_net_paise': 190000, 'in_payout_net_paise': 0,
                'temples': [temple(1, 'Sri Rama Temple', 'Bhadrachalam'), temple(2, 'Someshwara Temple', 'Kolanupaka')],
              }
            }
          : {
              'data': [
                {'reference': 'ST22AA', 'net_paise': 50000, 'period': '1–7 Oct', 'bookings_count': 2, 'temple': {'name': 'Someshwara Temple', 'city': 'Kolanupaka'}},
              ]
            };
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));
    await tester.binding.setSurfaceSize(const Size(500, 2000));
    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: AdminFinanceScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Sri Rama Temple'), findsOneWidget);
    expect(find.text('Someshwara Temple'), findsOneWidget);
    expect(find.textContaining('Someshwara Temple ·'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bhadra');
    await tester.pump();
    expect(find.text('Sri Rama Temple'), findsOneWidget);
    expect(find.text('Someshwara Temple'), findsNothing);
    expect(find.text('Waiting for the transfer'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ST22');
    await tester.pump();
    expect(find.textContaining('Someshwara Temple ·'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nowhere');
    await tester.pump();
    expect(find.text('No temple matches "nowhere"'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
