import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Deleting this account, as app stores require: the password and the word
/// DELETE confirm it, then the account is gone and the app is signed out.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      _password.text.isNotEmpty && _confirm.text.trim() == 'DELETE';

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<Session>().deleteAccount(
          password: _password.text, confirm: _confirm.text.trim());
      messenger.showSnackBar(SnackBar(content: Text(s('account_deleted'))));
      navigator.popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('delete_account'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SoftCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Palette.kumkum),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s('delete_account'),
                            style: theme.textTheme.titleMedium)),
                  ]),
                  const SizedBox(height: 8),
                  Text(s('delete_account_hint')),
                  const SizedBox(height: 8),
                  Text(s('delete_account_warning'),
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  ApiTextField(
                    controller: _password,
                    label: s('password'),
                    field: 'password',
                    error: _error,
                    obscure: true,
                    prefixIcon: Icons.lock_outline,
                  ),
                  ApiTextField(
                    controller: _confirm,
                    label: s('type_delete'),
                    field: 'confirm',
                    error: _error,
                    prefixIcon: Icons.keyboard,
                  ),
                  if (_error != null && _error!.errors.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!.message,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ListenableBuilder(
                    listenable: Listenable.merge([_password, _confirm]),
                    builder: (context, _) => FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Palette.kumkum),
                      onPressed: _busy || !_ready ? null : _delete,
                      icon: const Icon(Icons.delete_forever),
                      label: Text(s('delete_account')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: Text(s('cancel'))),
                ]),
          ),
        ],
      ),
    );
  }
}
