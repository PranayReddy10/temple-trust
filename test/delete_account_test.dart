import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/session.dart';
import 'package:temple_trust/features/account/delete_account_screen.dart';

void main() {
  testWidgets('deleting the account needs the password and DELETE, then signs out', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    var answer = http.Response(jsonEncode({'message': 'That is not your password.', 'errors': {'password': ['That is not your password.']}}), 422, headers: {'content-type': 'application/json'});
    final client = MockClient((req) async {
      requests.add(req);
      return answer;
    });
    final session = Session(ApiClient(baseUrl: 'https://example.test', client: client))..api.token = 'token-1';

    await tester.pumpWidget(ChangeNotifierProvider.value(value: session, child: const MaterialApp(home: DeleteAccountScreen())));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, 'Delete account');
    expect(tester.widget<FilledButton>(button).onPressed, isNull, reason: 'nothing typed yet');

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.enterText(find.widgetWithText(TextField, 'Type DELETE'), 'DELETE');
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('That is not your password.'), findsWidgets);
    expect(session.signedIn, isTrue);

    answer = http.Response(jsonEncode({'data': {'message': 'Your account has been deleted.'}}), 200, headers: {'content-type': 'application/json'});
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'right-password');
    await tester.tap(button);
    await tester.pumpAndSettle();

    final last = requests.last;
    expect(last.method, 'DELETE');
    expect(last.url.path, '/api/v1/trust/me');
    expect(jsonDecode(last.body), {'password': 'right-password', 'confirm': 'DELETE'});
    expect(session.signedIn, isFalse);
  });
}
