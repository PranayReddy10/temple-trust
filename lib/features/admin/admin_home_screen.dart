import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../account/account_screen.dart';
import '../counter/scan_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_queues.dart';
import 'all_temples_screen.dart';

typedef Json = Map<String, dynamic>;

/// The super admin's home: what is waiting for a decision, and every temple.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<Json> _future = _load();

  Future<Json> _load() async {
    final res = await context.read<Session>().api.get('admin/overview');
    return (res['data'] as Map).cast<String, dynamic>();
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final user = context.watch<Session>().account?.user;
    final locale = Localizations.localeOf(context).toString();
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/brand/logo.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Flexible(child: Text('${s('admin')} · ${Brand.name}', overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          const LanguageButton(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: s('account'),
            icon: user == null ? const Icon(Icons.account_circle_outlined) : InitialsAvatar(user.name, size: 32),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Palette.saffron,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(s('scan')),
      ),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final o = snap.data!;
          final temples = (o['temples'] as Map?) ?? const {};
          int n(dynamic v) => (v as num?)?.toInt() ?? 0;
          final waiting = n(o['claims_pending']) + n(o['registrations_pending']) + n(o['events_in_review']);

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: HeroPanel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat.yMMMMEEEEd(locale).format(DateTime.now()), style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      const SizedBox(height: 6),
                      if (user != null) Text('${s('greeting')}, ${user.name.split(' ').first}', style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 26, fontWeight: FontWeight.w600, height: 1.15)),
                      const SizedBox(height: 6),
                      Text(s('admin_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _HeroFigure(s('waiting_for_you'), '$waiting'),
                        _HeroFigure(s('published'), '${n(temples['published'])}'),
                        _HeroFigure(s('in_review_lc'), '${n(temples['in_review'])}'),
                        _HeroFigure(s('draft'), '${n(temples['draft'])}'),
                      ]),
                    ]),
                  ),
                ),
                SectionTitle(s('waiting_for_you')),
                ActionTile(icon: Icons.how_to_reg_outlined, color: Palette.sky, title: s('requests_to_manage'), badge: n(o['claims_pending']) > 0 ? '${n(o['claims_pending'])}' : null, subtitle: n(o['claims_pending']) == 0 ? s('none') : null, onTap: () => _open(const ClaimsQueueScreen())),
                ActionTile(icon: Icons.add_location_alt_outlined, color: Palette.saffron, title: s('temples_to_list'), badge: n(o['registrations_pending']) > 0 ? '${n(o['registrations_pending'])}' : null, subtitle: n(o['registrations_pending']) == 0 ? s('none') : null, onTap: () => _open(const RegistrationsQueueScreen())),
                ActionTile(icon: Icons.celebration_outlined, color: const Color(0xFFD1476B), title: s('events_to_review'), badge: n(o['events_in_review']) > 0 ? '${n(o['events_in_review'])}' : null, subtitle: n(o['events_in_review']) == 0 ? s('none') : null, onTap: () => _open(const EventsQueueScreen())),
                SectionTitle(s('money')),
                ActionTile(icon: Icons.account_balance_wallet_outlined, title: s('finance_settlements'), subtitle: s('finance_settlements_hint'), onTap: () => _open(const AdminFinanceScreen())),
                SectionTitle(s('temples')),
                ActionTile(
                  icon: Icons.temple_hindu,
                  color: Palette.tulsi,
                  title: s('all_temples'),
                  subtitle: '${n(temples['published'])} ${s('published')} · ${n(temples['in_review'])} ${s('in_review_lc')} · ${n(temples['draft'])} ${s('draft')}',
                  onTap: () => _open(const AllTemplesScreen()),
                ),
                const SizedBox(height: 24),
                Center(child: Text(Brand.tagline, style: theme.textTheme.bodySmall)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
