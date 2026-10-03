import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/brand.dart';
import 'core/l10n.dart';
import 'core/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(baseUrl: Brand.defaultApiBase);
  final locale = LocaleController(api)..restore();
  final session = Session(api)..restore();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: locale),
      ChangeNotifierProvider.value(value: session),
    ],
    child: const TrustApp(),
  ));
}
