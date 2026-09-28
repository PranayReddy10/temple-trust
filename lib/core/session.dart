import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'brand.dart';
import 'models.dart';

/// Who is signed in, and what they manage.
///
/// The token is kept on the device; the account (temples, claims,
/// registrations) is always fetched fresh, because whether a claim was
/// approved is the server's to say.
class Session extends ChangeNotifier {
  Session(this.api) {
    api.onUnauthenticated = _expired;
  }

  final ApiClient api;

  static const _tokenKey = 'trust.token';
  static const _baseKey = 'trust.api_base';

  bool _ready = false;
  TrustAccount? _account;
  TrustOptions? _options;

  bool get ready => _ready;
  bool get signedIn => api.token != null;
  TrustAccount? get account => _account;
  TrustOptions get options => _options ?? const TrustOptions({});

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    api.baseUrl = prefs.getString(_baseKey) ?? Brand.defaultApiBase;
    api.token = prefs.getString(_tokenKey);
    if (api.token != null) {
      try {
        await refresh();
      } on ApiException catch (e) {
        if (e.isUnauthenticated || e.isForbidden) await _clear();
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setServer(String base) async {
    api.baseUrl = base;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseKey, api.baseUrl);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await api.post('auth/login', {'email': email.trim(), 'password': password});
    await _accept(res);
  }

  Future<void> register({required String name, required String email, required String phone, required String password}) async {
    final res = await api.post('auth/register', {'name': name.trim(), 'email': email.trim(), 'phone': phone.trim(), 'password': password});
    await _accept(res);
  }

  Future<void> refresh() async {
    final res = await api.get('me');
    _account = TrustAccount.fromJson((res['data'] as Map).cast<String, dynamic>());
    notifyListeners();
    await loadOptions();
  }

  Future<void> loadOptions({bool force = false}) async {
    if (_options != null && !force) return;
    try {
      final res = await api.get('options');
      _options = TrustOptions((res['data'] as Map).cast<String, dynamic>());
      notifyListeners();
    } on ApiException {
      // Forms fall back to typing; the next refresh tries again.
    }
  }

  Future<void> updateProfile(Map<String, dynamic> changes) async {
    final res = await api.patch('me', changes);
    _account = TrustAccount.fromJson((res['data'] as Map).cast<String, dynamic>());
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('auth/logout');
    } on ApiException {
      // Signed out on this device either way.
    }
    await _clear();
  }

  Future<void> _accept(Map<String, dynamic> res) async {
    final data = (res['data'] as Map).cast<String, dynamic>();
    api.token = '${data['token']}';
    _account = TrustAccount.fromJson((data['account'] as Map).cast<String, dynamic>());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
    notifyListeners();
    await loadOptions(force: true);
  }

  void _expired() {
    _clear();
  }

  Future<void> _clear() async {
    api.token = null;
    _account = null;
    _options = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
