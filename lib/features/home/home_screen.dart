import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../account/account_screen.dart';
import '../counter/find_booking_screen.dart';
import '../counter/scan_screen.dart';
import '../onboarding/claim_temple_screen.dart';
import '../onboarding/register_temple_screen.dart';
import '../temple/bookings_screen.dart';
import '../temple/finance_screen.dart';
import '../temple/temple_dashboard_screen.dart';

/// The temples this account manages, where each request stands, and the
/// counter's scan button where a thumb finds it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Bumped on pull-to-refresh so every temple card fetches its day again.
  int _generation = 0;

  Future<void> _refresh() async {
    try {
      await context.read<Session>().refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final account = session.account;
    final temples = account?.temples ?? const <TrustTemple>[];
    final s = S.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/brand/logo.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Flexible(child: Text(Brand.appName, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          const LanguageButton(),
          const SizedBox(width: 6),
          IconButton(
            tooltip: s('account'),
            icon: account == null ? const Icon(Icons.account_circle_outlined) : InitialsAvatar(account.user.name, size: 32),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: temples.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Palette.saffron,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(s('scan')),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            if (account != null) _Greeting(name: account.user.name),
            if (temples.isEmpty)
              const _GetStarted()
            else ...[
              const SizedBox(height: 14),
              const _ScanPanel(),
              SectionTitle(s('quick_actions')),
              _QuickActions(temples: temples),
              SectionTitle(s('your_temples')),
              for (final t in temples) Padding(padding: const EdgeInsets.only(bottom: 12), child: _TempleCard(key: ValueKey('${t.id}-$_generation'), temple: t)),
            ],
            if ((account?.openClaims ?? const []).isNotEmpty) ...[
              SectionTitle(s('requests_to_manage')),
              for (final c in account!.openClaims) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ClaimTile(claim: c)),
            ],
            if ((account?.registrations ?? const []).isNotEmpty) ...[
              SectionTitle(s('temples_registered')),
              for (final r in account!.registrations) Padding(padding: const EdgeInsets.only(bottom: 10), child: _RegistrationTile(registration: r)),
            ],
            if (temples.isNotEmpty) ...[
              SectionTitle(s('another_temple')),
              const _AddTempleButtons(),
            ],
            const SizedBox(height: 24),
            Center(child: Text(Brand.tagline, style: theme.textTheme.bodySmall)),
          ],
        ),
      ),
    );
  }
}

/// "Namaskaram, Name" with the day's date, on kumkum.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final locale = Localizations.localeOf(context).toString();
    final today = DateFormat.yMMMMEEEEd(locale).format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: HeroPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(today, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text('${s('greeting')}, ${name.split(' ').first}', style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 26, fontWeight: FontWeight.w600, height: 1.15)),
          const SizedBox(height: 6),
          Text(s('home_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
        ]),
      ),
    );
  }
}

/// The counter's button: scan a seva booking, an event ticket or a passport.
class _ScanPanel extends StatelessWidget {
  const _ScanPanel();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return HeroPanel(
      gradient: Palette.saffronGradient,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.35))),
          child: const Icon(Icons.qr_code_scanner, size: 36),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s('scan_at_counter'), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 21, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s('scan_hint'), style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_ios_rounded, size: 18),
      ]),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.temples});

  final List<TrustTemple> temples;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final one = temples.length == 1 ? temples.first : null;
    final items = <(IconData, String, Color, Widget Function())>[
      (Icons.person_search_outlined, s('find_booking'), Palette.sky, () => const FindBookingScreen()),
      if (one != null) (Icons.confirmation_number_outlined, s('bookings_today'), Palette.tulsi, () => BookingsScreen(templeId: one.id, todayOnly: true)),
      if (one != null) (Icons.account_balance_wallet_outlined, s('finance'), Palette.kumkum, () => FinanceScreen(templeId: one.id, title: one.name)),
    ];
    return Row(children: [
      for (final (i, item) in items.indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: SoftCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.$4())),
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBadge(item.$1, color: item.$3, size: 36),
              const SizedBox(height: 10),
              Text(item.$2, style: Theme.of(context).textTheme.labelLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ],
    ]);
  }
}

class _GetStarted extends StatelessWidget {
  const _GetStarted();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconBadge(Icons.temple_hindu, size: 48),
            const SizedBox(height: 14),
            Text(s('connect_temple'), style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(s('connect_temple_body'), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            const _AddTempleButtons(),
          ],
        ),
      ),
    );
  }
}

class _AddTempleButtons extends StatelessWidget {
  const _AddTempleButtons();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimTempleScreen())),
          icon: const Icon(Icons.search),
          label: Text(s('find_my_temple')),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterTempleScreen())),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(s('register_missing')),
        ),
      ],
    );
  }
}

/// A temple: its cover, where it is, how it stands, and today's numbers.
class _TempleCard extends StatefulWidget {
  const _TempleCard({super.key, required this.temple});

  final TrustTemple temple;

  @override
  State<_TempleCard> createState() => _TempleCardState();
}

class _TempleCardState extends State<_TempleCard> {
  late final Future<Map<String, dynamic>> _stats = _load();

  Future<Map<String, dynamic>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.temple.id}');
    return TrustTemple.fromJson((res['data'] as Map).cast<String, dynamic>()).stats;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    final t = widget.temple;
    return SoftCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TempleDashboardScreen(templeId: t.id, title: t.name))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 2.2,
          child: Stack(fit: StackFit.expand, children: [
            if (t.imageUrl != null) FittedPhoto(t.imageUrl!, placeholder: _placeholder(theme)) else _placeholder(theme),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0x99000000)]),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: TrustTheme.serif, fontSize: 20, fontWeight: FontWeight.w600, height: 1.15)),
                if (t.place.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(child: Text(t.place, style: const TextStyle(color: Colors.white70, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                  ]),
              ]),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Wrap(spacing: 6, children: [
                if (t.statusLabel != null) _GlassChip(t.statusLabel!),
                if (t.trustLabel != null) _GlassChip(t.trustLabel!),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _stats,
            builder: (context, snap) {
              // Could not be read (offline, or the temple was just handed
              // over): the dashboard itself says more.
              final st = snap.hasError ? const <String, dynamic>{} : snap.data;
              int n(String k) => (st?[k] as num?)?.toInt() ?? 0;
              return Row(children: [
                Expanded(
                  child: _Today(
                    label: s('todays_sevas'),
                    value: st == null ? null : rupeesShort(st['amount_today_paise']),
                    caption: st == null ? null : '${s('n_bookings', {'n': n('bookings_today')})} · ${s('received')} ${n('received_today')}',
                  ),
                ),
                Expanded(
                  child: _Today(
                    label: s('hundi_today'),
                    value: st == null ? null : rupeesShort(st['hundi_today_paise']),
                    caption: st == null ? null : s('n_gifts', {'n': n('hundi_today_count')}),
                    color: Palette.gold,
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        decoration: const BoxDecoration(gradient: Palette.kumkumGradient),
        child: Icon(Icons.temple_hindu, size: 48, color: Colors.white.withValues(alpha: 0.45)),
      );
}

class _Today extends StatelessWidget {
  const _Today({required this.label, this.value, this.caption, this.color});

  final String label;
  final String? value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      value == null
          ? Container(width: 64, height: 18, margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(6)))
          : FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value!, style: theme.textTheme.titleLarge?.copyWith(color: color ?? theme.colorScheme.primary))),
      if (caption != null) Text(caption!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.claim});

  final TempleClaim claim;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final label = switch (claim.status) {
      'pending' => s('waiting_confirmation'),
      'rejected' => s('not_approved'),
      _ => claim.status,
    };
    return ActionTile(
      icon: Icons.how_to_reg_outlined,
      color: claim.status == 'rejected' ? const Color(0xFFB3261E) : Palette.sky,
      title: claim.templeName ?? 'Temple',
      subtitle: [
        if (claim.templeCity != null) claim.templeCity!,
        if (claim.rejectionReason != null) '${s('reason')}: ${claim.rejectionReason}',
      ].join(' · '),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusChip.forStatus(claim.status, label),
        if (claim.status == 'pending')
          IconButton(
            tooltip: s('withdraw'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _withdraw(context),
          ),
      ]),
      onTap: () {
        if (claim.status == 'rejected') Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimTempleScreen()));
      },
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    if (!await confirm(context, S.of(context)('withdraw_q'), action: S.of(context)('withdraw'))) return;
    if (!context.mounted) return;
    final session = context.read<Session>();
    try {
      await session.api.delete('claims/${claim.id}');
      await session.refresh();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _RegistrationTile extends StatelessWidget {
  const _RegistrationTile({required this.registration});

  final TempleRegistration registration;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ActionTile(
      icon: Icons.add_location_alt_outlined,
      color: Palette.saffron,
      title: registration.name,
      subtitle: [
        if (registration.city != null) registration.city!,
        if (registration.status == 'approved') s('listed_access_pending'),
        if (registration.reviewNote != null && registration.reviewNote!.isNotEmpty) registration.reviewNote!,
      ].join(' · '),
      trailing: StatusChip.forStatus(registration.status, registration.statusLabel),
      onTap: () {},
    );
  }
}
