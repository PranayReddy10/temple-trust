import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_trust/features/counter/passport_card.dart';

void main() {
  testWidgets('a scanned passport shows the devotee, not raw fields',
      (tester) async {
    final passport = {
      'name': 'Lakshmi Devi',
      'avatar_url': null,
      'home_state': 'Telangana',
      'joined_at': '2026-03-14T10:00:00+05:30',
      'stamps': 4,
      'temples_visited': 6,
      'visits_recorded': 7,
      'states_covered': 2,
      'visits': [
        {
          'temple': {
            'id': 9,
            'name': 'Sri Rama Temple',
            'city': 'Bhadrachalam'
          },
          'visited_on': '2026-09-20',
          'is_verified': true
        },
        {
          'temple': {
            'id': 3,
            'name': 'Yadadri Temple',
            'city': 'Yadagirigutta'
          },
          'visited_on': '2026-08-02',
          'is_verified': false
        },
      ],
    };

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child:
                    PassportCard(passport: passport, templeIds: const {9})))));

    expect(find.text('Lakshmi Devi'), findsOneWidget);
    expect(find.text('From Telangana'), findsOneWidget);
    expect(find.text('Pilgrim since 14 Mar 2026'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Sri Rama Temple, Bhadrachalam'), findsOneWidget);
    expect(find.text('Visited your temple before, on 20 Sep 2026'),
        findsOneWidget);
    // The photo is a picture (here the initials, as there is none), never its address.
    expect(find.textContaining('avatar'), findsNothing);
    expect(find.textContaining('http'), findsNothing);
    expect(find.text('LD'), findsOneWidget);
  });
}
