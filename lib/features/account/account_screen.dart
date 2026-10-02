import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _session = context.read<Session>();
  late final _name = TextEditingController(text: _session.account?.user.name ?? '');
  late final _phone = TextEditingController(text: _session.account?.user.phone ?? '');
  final _current = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _current, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _session.updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_password.text.isNotEmpty) ...{'current_password': _current.text, 'password': _password.text},
      });
      _current.clear();
      _password.clear();
      if (mounted) showMessage(context, 'Saved.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().account?.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.email_outlined), title: Text(user.email), subtitle: const Text('Sign-in email')),
          const SizedBox(height: 8),
          ApiTextField(controller: _name, label: 'Name', field: 'name', error: _error),
          ApiTextField(controller: _phone, label: 'Mobile number', field: 'phone', error: _error, keyboardType: TextInputType.phone),
          const SectionTitle('Change password'),
          ApiTextField(controller: _current, label: 'Current password', field: 'current_password', error: _error, obscure: true),
          ApiTextField(controller: _password, label: 'New password', field: 'password', error: _error, obscure: true),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
          const SectionTitle('Help'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent),
            title: const Text('Contact the ${Brand.name} team'),
            subtitle: const Text(Brand.supportEmail),
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: Brand.supportEmail, query: 'subject=${Brand.appName} app')),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.open_in_browser),
            title: const Text('Open the temple portal on the web'),
            subtitle: Text('${_session.api.baseUrl}/temple'),
            onTap: () => launchUrl(Uri.parse('${_session.api.baseUrl}/temple'), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await _session.logout();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
