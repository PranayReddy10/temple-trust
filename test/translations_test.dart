import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/l10n.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/temple/translations_screen.dart';

void main() {
  const json = {'content-type': 'application/json'};

  Map<String, dynamic> payload(String? telugu) => {
        'auto_translate': true,
        'languages': [
          {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
          {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
        ],
        'fields': [
          {
            'field': 'dress_code',
            'english': 'Traditional dress only.',
            'publishes_directly': true,
            'translations': telugu == null
                ? {}
                : {
                    'te': {'value': telugu, 'is_reviewed': true}
                  },
          },
        ],
      };

  testWidgets('a team auto-translates the dress code, reads it and saves it',
      (tester) async {
    String? saved;
    final client = MockClient((req) async {
      final path = req.url.path;
      if (req.method == 'POST' && path.endsWith('/translations/suggest')) {
        expect(jsonDecode(req.body), {'field': 'dress_code', 'locale': 'te'});
        return http.Response(
            jsonEncode({
              'data': {'value': 'సాంప్రదాయ దుస్తులు మాత్రమే.'}
            }),
            200,
            headers: json);
      }
      if (req.method == 'PUT' && path.endsWith('/temples/7/translations')) {
        saved = (jsonDecode(req.body) as Map)['value'] as String;
        return http.Response(jsonEncode({'data': payload(saved)}), 200,
            headers: json);
      }
      if (req.method == 'GET' && path.endsWith('/temples/7/translations')) {
        return http.Response(jsonEncode({'data': payload(null)}), 200,
            headers: json);
      }
      return http.Response('{}', 404);
    });
    final session =
        Session(ApiClient(baseUrl: 'https://example.test', client: client));

    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: TranslationsScreen(templeId: 7))));
    await tester.pumpAndSettle();

    expect(find.text('Dress code'), findsOneWidget);
    expect(find.text('Not translated yet'), findsOneWidget);

    await tester.tap(find.text('Dress code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto-translate'));
    await tester.pumpAndSettle();
    expect(find.text('సాంప్రదాయ దుస్తులు మాత్రమే.'), findsOneWidget);

    await tester.enterText(
        find.byType(TextField), 'సాంప్రదాయ దుస్తులు మాత్రమే!');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(saved, 'సాంప్రదాయ దుస్తులు మాత్రమే!');
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Saved. Devotees see it now.'), findsOneWidget);
  });

  test('every Languages screen string has all five languages', () {
    for (final key in [
      'tr_title',
      'tr_auto',
      'tr_field_name',
      'tr_field_dress_code',
      'tr_saved_review'
    ]) {
      final en = const S('en')(key);
      for (final code in ['te', 'hi', 'ta', 'kn']) {
        expect(S(code)(key), isNot(en), reason: '$key in $code');
      }
    }
  });
}
