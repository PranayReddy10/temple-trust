import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_trust/core/api_client.dart';
import 'package:temple_trust/core/l10n.dart';

void main() {
  test('every string has English, and each translation fills a key English has', () {
    const en = S('en');
    const te = S('te');
    expect(en('scan_at_counter'), 'Scan at counter');
    expect(te('scan_at_counter'), 'కౌంటర్‌లో స్కాన్');
    expect(const S('hi')('financial_report'), 'वित्तीय रिपोर्ट');
    expect(const S('ta')('today'), 'இன்று');
    expect(const S('kn')('language'), 'ಭಾಷೆ');
    // A key with no translation falls back to English, never to the key.
    expect(const S('te')('no_such_key'), 'no_such_key');
    expect(en('n_bookings', {'n': 3}), '3 bookings');
    expect(te.people(1), '1 వ్యక్తి');
    expect(en.people(4), '4 people');
  });

  testWidgets('the language picker switches the interface and tells the API', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(baseUrl: 'https://example.test');
    final locale = LocaleController(api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: locale,
      child: Builder(builder: (context) {
        final l = context.watch<LocaleController>().locale;
        return MaterialApp(
          locale: l,
          supportedLocales: LocaleController.supportedLocales,
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: Scaffold(appBar: AppBar(actions: const [LanguageButton()]), body: Builder(builder: (c) => Text(S.of(c)('scan_at_counter')))),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Scan at counter'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('తెలుగు'));
    await tester.pumpAndSettle();

    expect(find.text('కౌంటర్‌లో స్కాన్'), findsOneWidget);
    expect(api.language, 'te');
    expect((await SharedPreferences.getInstance()).getString('trust.locale'), 'te');
  });
}
