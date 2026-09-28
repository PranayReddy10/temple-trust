import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/brand.dart';
import 'core/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(ApiClient(baseUrl: Brand.defaultApiBase))..restore();

  runApp(ChangeNotifierProvider.value(value: session, child: const TrustApp()));
}
