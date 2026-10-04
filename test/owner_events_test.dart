import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/models.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/events_screen.dart';

void main() {
  const json = {'content-type': 'application/json'};

  Map<String, dynamic> event(String status, {bool canReview = false}) => {
        'id': 5,
        'title': 'Ekadashi Bhajan',
        'type': 'bhajan',
        'date_label': 'Sat, 10 Oct',
        'raised_by': 'Bhajan Leader',
        'status': {'value': status, 'label': status == 'published' ? 'Published' : 'Pending review'},
        'can_review': canReview,
        'registration': {'enabled': false},
      };

  testWidgets('the owner approves an event a devotee proposed', (tester) async {
    var approved = false;
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/events/5/approve')) {
        approved = true;
        return http.Response(jsonEncode({'data': event('published')}), 200, headers: json);
      }
      if (req.method == 'GET' && req.url.path.endsWith('/temples/7/events')) {
        return http.Response(jsonEncode({'data': [approved ? event('published') : event('pending_review', canReview: true)]}), 200, headers: json);
      }
      return http.Response('{}', 404);
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: EventsScreen(templeId: 7))));
    await tester.pumpAndSettle();

    expect(find.textContaining('Proposed by Bhajan Leader'), findsOneWidget);
    expect(find.text('Waiting for approval'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(approved, isTrue);
    expect(find.text('Waiting for approval'), findsNothing);
  });

  testWidgets('a manager sees no approve button', (tester) async {
    final client = MockClient((req) async => http.Response(jsonEncode({'data': [event('pending_review')]}), 200, headers: json));
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: EventsScreen(templeId: 7))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
  });

  test('a temple shares its website page only once published', () {
    final published = TrustTemple.fromJson({'id': 1, 'name': 'Sri Rama Temple', 'access_level': 'owner', 'public_url': 'https://darshansaathi.com/temples/sri-rama'});
    final draft = TrustTemple.fromJson({'id': 2, 'name': 'Draft Temple', 'access_level': 'manager', 'public_url': null});

    expect(published.publicUrl, 'https://darshansaathi.com/temples/sri-rama');
    expect(published.isOwner, isTrue);
    expect(draft.publicUrl, isNull);
    expect(draft.isOwner, isFalse);
  });
}
