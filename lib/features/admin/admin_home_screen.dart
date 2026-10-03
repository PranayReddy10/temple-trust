import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/session.dart';
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
    final user = context.watch<Session>().account?.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin · ${Brand.appName}'),
        actions: [
          IconButton(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final o = snap.data!;
          final temples = (o['temples'] as Map?) ?? const {};
          int n(dynamic v) => (v as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              children: [
                if (user != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Text('Namaskaram, ${user.name.split(' ').first}', style: Theme.of(context).textTheme.titleLarge),
                  ),
                const Padding(padding: EdgeInsets.fromLTRB(4, 4, 4, 0), child: Text('Super admin — every temple, and the approval queues.')),
                const SectionTitle('Waiting for you'),
                _Queue(Icons.how_to_reg_outlined, 'Requests to manage a temple', n(o['claims_pending']), () => _open(const ClaimsQueueScreen())),
                _Queue(Icons.add_location_alt_outlined, 'Temples to list', n(o['registrations_pending']), () => _open(const RegistrationsQueueScreen())),
                _Queue(Icons.celebration_outlined, 'Events to review', n(o['events_in_review']), () => _open(const EventsQueueScreen())),
                const SectionTitle('Money'),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Finance & settlements'),
                    subtitle: const Text('Seva payments today, what each temple is owed, payouts to make'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const AdminFinanceScreen()),
                  ),
                ),
                const SectionTitle('Temples'),
                Card(
                  child: ListTile(
                    leading: Icon(Icons.temple_hindu, color: Theme.of(context).colorScheme.primary),
                    title: const Text('All temples'),
                    subtitle: Text('${n(temples['published'])} published · ${n(temples['in_review'])} in review · ${n(temples['draft'])} draft'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _open(const AllTemplesScreen()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Queue extends StatelessWidget {
  const _Queue(this.icon, this.title, this.count, this.onTap);

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (count > 0) StatusChip('$count', color: theme.colorScheme.primary) else const Text('None'),
            const Icon(Icons.chevron_right),
          ]),
          onTap: onTap,
        ),
      ),
    );
  }
}
