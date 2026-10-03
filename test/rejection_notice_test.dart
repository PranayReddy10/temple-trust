import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_trust/features/temple/payments_verification_screen.dart';

void main() {
  testWidgets('a rejected verification shows the team\'s reason and what to do', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RejectionNotice(reason: 'The Aadhaar photo is not readable.', rejectedAt: DateTime(2026, 10, 3, 10, 30)),
      ),
    ));

    expect(find.text('Payments not approved'), findsOneWidget);
    expect(find.text('REASON'), findsOneWidget);
    expect(find.text('The Aadhaar photo is not readable.'), findsOneWidget);
    expect(find.textContaining('3 Oct 2026'), findsOneWidget);
    expect(find.textContaining('Send again for approval'), findsOneWidget);
  });

  testWidgets('no reason given still tells them how to ask', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RejectionNotice(reason: null, canFix: false))));

    expect(find.textContaining('did not give a reason'), findsOneWidget);
    expect(find.textContaining('owner can correct this'), findsOneWidget);
  });
}
