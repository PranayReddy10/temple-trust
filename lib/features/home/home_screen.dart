import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../account/account_screen.dart';
import '../counter/scan_screen.dart';
import '../onboarding/claim_temple_screen.dart';
import '../onboarding/register_temple_screen.dart';
import '../temple/temple_dashboard_screen.dart';

/// The temples this account manages, and where each request stands.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final account = session.account;
    final temples = account?.temples ?? const <TrustTemple>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(Brand.appName),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
      floatingActionButton: temples.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan at counter'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await session.refresh();
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            if (account != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text('Namaskaram, ${account.user.name.split(' ').first}', style: Theme.of(context).textTheme.titleLarge),
              ),
            if (temples.isEmpty) const _GetStarted() else ...[
              const SectionTitle('Your temples'),
              for (final t in temples)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _TempleCard(temple: t)),
            ],
            if ((account?.openClaims ?? const []).isNotEmpty) ...[
              const SectionTitle('Requests to manage a temple'),
              for (final c in account!.openClaims) Padding(padding: const EdgeInsets.only(bottom: 8), child: _ClaimTile(claim: c)),
            ],
            if ((account?.registrations ?? const []).isNotEmpty) ...[
              const SectionTitle('Temples you registered'),
              for (final r in account!.registrations) Padding(padding: const EdgeInsets.only(bottom: 8), child: _RegistrationTile(registration: r)),
            ],
            if (temples.isNotEmpty) ...[
              const SectionTitle('Another temple?'),
              const _AddTempleButtons(),
            ],
          ],
        ),
      ),
    );
  }
}

class _GetStarted extends StatelessWidget {
  const _GetStarted();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.temple_hindu, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Connect your temple', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'If your temple is already on the app, find it and ask to manage it. '
              'If it is missing, register it with a few photos. Our team confirms each request — '
              'usually by calling the number on your account — and your temple appears here once approved.',
            ),
            const SizedBox(height: 16),
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
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimTempleScreen())),
          icon: const Icon(Icons.search),
          label: const Text('Find my temple'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterTempleScreen())),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Register a missing temple'),
        ),
      ],
    );
  }
}

class _TempleCard extends StatelessWidget {
  const _TempleCard({required this.temple});

  final TrustTemple temple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TempleDashboardScreen(templeId: temple.id, title: temple.name))),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: temple.imageUrl == null
                  ? Container(color: theme.colorScheme.primary.withValues(alpha: 0.12), child: Icon(Icons.temple_hindu, color: theme.colorScheme.primary))
                  : Image.network(temple.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(temple.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (temple.place.isNotEmpty) Text(temple.place, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (temple.statusLabel != null) StatusChip.forStatus('${(temple.raw['status'] as Map?)?['value']}', temple.statusLabel!),
                      if (temple.trustLabel != null) StatusChip(temple.trustLabel!),
                    ]),
                  ],
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.chevron_right)),
          ],
        ),
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.claim});

  final TempleClaim claim;

  @override
  Widget build(BuildContext context) {
    final label = switch (claim.status) {
      'pending' => 'Waiting for confirmation',
      'rejected' => 'Not approved',
      _ => claim.status,
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.how_to_reg_outlined),
        title: Text(claim.templeName ?? 'Temple'),
        subtitle: Text([
          if (claim.templeCity != null) claim.templeCity!,
          if (claim.rejectionReason != null) 'Reason: ${claim.rejectionReason}',
        ].join(' · ')),
        trailing: StatusChip.forStatus(claim.status, label),
        onLongPress: claim.status == 'pending' ? () => _withdraw(context) : null,
        onTap: claim.status == 'rejected'
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClaimTempleScreen()))
            : null,
      ),
    );
  }

  Future<void> _withdraw(BuildContext context) async {
    if (!await confirm(context, 'Withdraw this request?', action: 'Withdraw')) return;
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
    return Card(
      child: ListTile(
        leading: const Icon(Icons.add_location_alt_outlined),
        title: Text(registration.name),
        subtitle: Text([
          if (registration.city != null) registration.city!,
          if (registration.status == 'approved') 'Listed — access is being confirmed',
          if (registration.reviewNote != null && registration.reviewNote!.isNotEmpty) registration.reviewNote!,
        ].join(' · ')),
        trailing: StatusChip.forStatus(registration.status, registration.statusLabel),
      ),
    );
  }
}
