import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/timings_screen.dart';

void main() {
  Map<String, dynamic> timing(int id, String dayLabel, List<int>? days) => {
        'id': id,
        'kind': 'darshan',
        'label': 'Darshan',
        'days': days,
        'day_label': dayLabel,
        'window': '6:00 AM – 1:00 PM',
        'opens_at': '06:00',
        'closes_at': '13:00',
      };

  testWidgets('every-day timings are split into Mon–Fri and Sat & Sun', (tester) async {
    var split = false;
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      final json = {'content-type': 'application/json'};
      if (req.method == 'POST' && req.url.path.endsWith('/timings/weekend')) {
        split = true;
        return http.Response(jsonEncode({'data': [timing(2, 'Sat & Sun', [6, 0])]}), 201, headers: json);
      }
      if (req.method == 'GET' && req.url.path.endsWith('/timings')) {
        return http.Response(jsonEncode({'data': split ? [timing(1, 'Mon–Fri', [1, 2, 3, 4, 5]), timing(2, 'Sat & Sun', [6, 0])] : [timing(1, 'Every day', null)]}), 200, headers: json);
      }
      return http.Response('{}', 404);
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: TimingsScreen(templeId: 7))));
    await tester.pumpAndSettle();
    expect(find.text('Every day · 6:00 AM – 1:00 PM'), findsOneWidget);

    await tester.tap(find.text('Different timings on Sat & Sun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(requests.any((r) => r.method == 'POST' && r.url.path == '/api/v1/trust/temples/7/timings/weekend'), isTrue);
    expect(find.text('Mon–Fri · 6:00 AM – 1:00 PM'), findsOneWidget);
    expect(find.text('Sat & Sun · 6:00 AM – 1:00 PM'), findsOneWidget);
  });

  testWidgets('a new timing can be set for Sat & Sun only', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      final json = {'content-type': 'application/json'};
      if (req.method == 'POST') return http.Response(jsonEncode({'data': timing(3, 'Sat & Sun', [6, 0])}), 201, headers: json);
      return http.Response(jsonEncode({'data': []}), 200, headers: json);
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: TimingsScreen(templeId: 7))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add timing'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Sat & Sun'));
    await tester.pumpAndSettle();
    // Sunday off again, then back on: the days chips follow.
    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final post = requests.firstWhere((r) => r.method == 'POST');
    expect(jsonDecode(post.body)['days'], [6, 0]);
  });
}
