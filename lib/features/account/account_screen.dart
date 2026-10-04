import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'delete_account_screen.dart';
import 'support_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final _session = context.read<Session>();
  late final _name =
      TextEditingController(text: _session.account?.user.name ?? '');
  late final _phone =
      TextEditingController(text: _session.account?.user.phone ?? '');
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
        if (_password.text.isNotEmpty) ...{
          'current_password': _current.text,
          'password': _password.text
        },
      });
      _current.clear();
      _password.clear();
      if (mounted) showMessage(context, S.of(context)('saved'));
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
    final user = context.watch<Session>().account?.user;
    final temples = context.watch<Session>().account?.temples ?? const [];
    final language = context.watch<LocaleController>().language;
    return Scaffold(
      appBar: AppBar(title: Text(s('account'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          if (user != null)
            HeroPanel(
              child: Row(children: [
                InitialsAvatar(user.name,
                    size: 56, color: Palette.goldLight.withValues(alpha: 0.9)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: const TextStyle(
                                fontFamily: TrustTheme.serif,
                                fontSize: 22,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(user.email,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${s('signed_in_as')} ${user.isSuperAdmin ? s('role_super_admin') : user.role == 'editor' ? s('role_editor') : s('role_temple_admin')}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          if (temples.isNotEmpty) ...[
            SectionTitle(s('your_access')),
            for (final t in temples)
              SoftCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(t.isOwner ? Icons.verified_user_outlined : Icons.badge_outlined, color: t.isOwner ? Palette.kumkum : Palette.sky),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(t.isOwner ? s('access_owner') : s('access_manager'), style: TextStyle(fontWeight: FontWeight.w700, color: t.isOwner ? Palette.kumkum : Palette.sky)),
                      const SizedBox(height: 2),
                      Text(t.isOwner ? s('access_owner_hint') : s('access_manager_hint'), style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ]),
              ),
          ],
          SectionTitle(s('preferences')),
          ActionTile(
            icon: Icons.translate,
            color: Palette.sky,
            title: s('language'),
            subtitle: language.nativeName == language.name
                ? language.name
                : '${language.nativeName} · ${language.name}',
            onTap: () => showLanguageSheet(context),
          ),
          SectionTitle(s('profile')),
          SoftCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ApiTextField(
                      controller: _name,
                      label: s('name'),
                      field: 'name',
                      error: _error,
                      prefixIcon: Icons.person_outline),
                  ApiTextField(
                      controller: _phone,
                      label: s('mobile_number'),
                      field: 'phone',
                      error: _error,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                      child: Text(s('change_password'),
                          style: theme.textTheme.titleMedium)),
                  ApiTextField(
                      controller: _current,
                      label: s('current_password'),
                      field: 'current_password',
                      error: _error,
                      obscure: true,
                      prefixIcon: Icons.lock_outline),
                  ApiTextField(
                      controller: _password,
                      label: s('new_password'),
                      field: 'password',
                      error: _error,
                      obscure: true,
                      prefixIcon: Icons.lock_reset),
                  FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? s('saving') : s('save'))),
                ]),
          ),
          SectionTitle(s('help')),
          ActionTile(
            icon: Icons.support_agent,
            color: Palette.tulsi,
            title: s('help_support'),
            subtitle: s('help_hint', {'name': Brand.name}),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await _session.logout();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(s('sign_out')),
          ),
          // Staff accounts are closed in the admin panel, not here.
          if (user != null && !user.isSuperAdmin) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Palette.kumkum),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DeleteAccountScreen())),
              icon: const Icon(Icons.delete_outline),
              label: Text(s('delete_account')),
            ),
          ],
          const SizedBox(height: 24),
          Center(
              child: Text('${Brand.appName} · ${Brand.supportEmail}',
                  style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
