import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n.dart';
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
    final s = S.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(children: [
        // The kumkum backdrop behind the logo; the form sits on a card below.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 300 + top,
          child: const DecoratedBox(
            decoration: BoxDecoration(
                gradient: Palette.kumkumGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(40))),
          ),
        ),
        Positioned(right: -60, top: -40, child: _ring(220)),
        Positioned(left: -40, top: 160 + top, child: _ring(140)),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Align(
                      alignment: Alignment.centerRight,
                      child: LanguageButton(
                          color: Colors.white.withValues(alpha: 0.95))),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 22,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset('assets/brand/logo.png',
                              width: 92,
                              height: 92,
                              semanticLabel: Brand.appName)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(Brand.appName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: TrustTheme.serif,
                          fontSize: 27,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(s('welcome_for'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13.5)),
                  Text(s('ob_tagline', {'name': Brand.name}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13.5)),
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: TrustStyle.of(context).cardShadow),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<bool>(
                                segments: [
                                  ButtonSegment(
                                      value: false,
                                      label: Text(s('sign_in')),
                                      icon: const Icon(Icons.login)),
                                  ButtonSegment(
                                      value: true,
                                      label: Text(s('create_account')),
                                      icon: const Icon(Icons.person_add_alt)),
                                ],
                                selected: {_register},
                                onSelectionChanged: (v) =>
                                    setState(() => _register = v.first),
                              ),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _register
                                    ? const _RegisterForm(key: ValueKey('r'))
                                    : const _LoginForm(key: ValueKey('l')),
                              ),
                            ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _ring(double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 18)),
        ),
      );
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
    final s = S.of(context);
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ApiTextField(
                controller: _email,
                label: s('email'),
                field: 'email',
                error: _error,
                keyboardType: TextInputType.emailAddress,
                required: true,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline),
            ApiTextField(
                controller: _password,
                label: s('password'),
                field: 'password',
                error: _error,
                obscure: true,
                required: true,
                autofillHints: const [AutofillHints.password],
                prefixIcon: Icons.lock_outline),
            if (_error != null && _error!.errors.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!.message,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(s('sign_in')),
            ),
            const SizedBox(height: 12),
            Text(s('welcome_same_login'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
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
      await context.read<Session>().register(
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text);
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
    final s = S.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ApiTextField(
              controller: _name,
              label: s('your_name'),
              field: 'name',
              error: _error,
              required: true,
              autofillHints: const [AutofillHints.name],
              prefixIcon: Icons.person_outline),
          ApiTextField(
              controller: _email,
              label: s('email'),
              field: 'email',
              error: _error,
              keyboardType: TextInputType.emailAddress,
              required: true,
              prefixIcon: Icons.mail_outline),
          ApiTextField(
            controller: _phone,
            label: s('mobile_number'),
            field: 'phone',
            error: _error,
            keyboardType: TextInputType.phone,
            required: true,
            hint: s('phone_hint'),
            prefixIcon: Icons.phone_outlined,
          ),
          ApiTextField(
              controller: _password,
              label: s('password_hint'),
              field: 'password',
              error: _error,
              obscure: true,
              required: true,
              prefixIcon: Icons.lock_outline),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(s('create_account')),
          ),
          const SizedBox(height: 12),
          Text(s('after_signup'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
