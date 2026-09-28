import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/home_screen.dart';

class TrustApp extends StatelessWidget {
  const TrustApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: TrustTheme.light(),
      darkTheme: TrustTheme.dark(),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.signedIn ? const HomeScreen() : const WelcomeScreen();
  }
}
