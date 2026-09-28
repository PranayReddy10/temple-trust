import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Sign in, or create an account for the temple's team.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _register = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Palette.kumkum, Palette.saffron]),
                      boxShadow: [BoxShadow(color: Palette.kumkum.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.temple_hindu, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 18),
                Text(Brand.appName, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'For temple trusts, committees and temple offices. ${Brand.tagline}.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Sign in'), icon: Icon(Icons.login)),
                    ButtonSegment(value: true, label: Text('Create account'), icon: Icon(Icons.person_add_alt)),
                  ],
                  selected: {_register},
                  onSelectionChanged: (s) => setState(() => _register = s.first),
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _register ? const _RegisterForm(key: ValueKey('r')) : const _LoginForm(key: ValueKey('l')),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => _server(context),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: Text('Server: ${context.watch<Session>().api.baseUrl}', overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _server(BuildContext context) async {
    final session = context.read<Session>();
    final c = TextEditingController(text: session.api.baseUrl);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Server address'),
        content: TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://temple.darshansaathi.com')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, Brand.defaultApiBase), child: const Text('Reset')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) await session.setServer(v);
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ApiTextField(controller: _email, label: 'Email', field: 'email', error: _error, keyboardType: TextInputType.emailAddress, required: true, autofillHints: const [AutofillHints.email]),
            ApiTextField(controller: _password, label: 'Password', field: 'password', error: _error, obscure: true, required: true, autofillHints: const [AutofillHints.password]),
            if (_error != null && _error!.errors.isEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!.message, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            Text(
              'Temple portal and super admin accounts sign in with the same email and password as on the web.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({super.key});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().register(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        if (e.errors.isEmpty) showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ApiTextField(controller: _name, label: 'Your name', field: 'name', error: _error, required: true, autofillHints: const [AutofillHints.name]),
          ApiTextField(controller: _email, label: 'Email', field: 'email', error: _error, keyboardType: TextInputType.emailAddress, required: true),
          ApiTextField(
            controller: _phone,
            label: 'Mobile number',
            field: 'phone',
            error: _error,
            keyboardType: TextInputType.phone,
            required: true,
            hint: 'We call this number to confirm you represent the temple',
          ),
          ApiTextField(controller: _password, label: 'Password (8 or more characters)', field: 'password', error: _error, obscure: true, required: true),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create account'),
          ),
          const SizedBox(height: 12),
          Text(
            'After signing up, find your temple and ask to manage it — or register it if it is not listed yet. '
            'Our team confirms every request before a temple is handed over.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
