import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/l10n.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/home_screen.dart';

class TrustApp extends StatelessWidget {
  const TrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleController>().locale;
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: TrustTheme.light(),
      darkTheme: TrustTheme.dark(),
      locale: locale,
      supportedLocales: LocaleController.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Gate(),
    );
  }
}

/// Signed in or not decides the whole app: the home screen, or the welcome.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (!session.ready) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/brand/logo.png', width: 72, height: 72),
            const SizedBox(height: 20),
            const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          ]),
        ),
      );
    }
    if (!session.signedIn) return const WelcomeScreen();
    return session.isSuperAdmin ? const AdminHomeScreen() : const HomeScreen();
  }
}
