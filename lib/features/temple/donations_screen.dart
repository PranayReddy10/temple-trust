import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Online hundi: gifts devotees make to the temple in the app. They are paid
/// out with the temple's settlements; the owner turns the hundi on or off.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  late Future<Json> _future = _load();
  bool _saving = false;

  Future<Json> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/donations');
    return _map(res['data']);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _setAccepting(bool on) async {
    setState(() => _saving = true);
    try {
      await context.read<Session>().api.put('temples/${widget.templeId}/donation-settings', {'accepts_donations': on});
      if (!mounted) return;
      showMessage(context, on ? 'Devotees can now give to the hundi in the app.' : 'Online hundi turned off.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Online hundi')),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final d = snap.data!;
          final today = _map(d['today']);
          final month = _map(d['month']);
          final total = _map(d['total']);
          final items = [for (final r in (d['items'] as List? ?? const [])) _map(r)];
          final accepts = d['accepts_donations'] == true;
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Card(
                  child: d['can_change'] == true
                      ? SwitchListTile(
                          title: const Text('Accept online hundi'),
                          subtitle: const Text('Devotees can give to the temple from the app. Gifts are paid out with your settlements.'),
                          value: accepts,
                          onChanged: _saving ? null : _setAccepting,
                        )
                      : ListTile(
                          title: Text(accepts ? 'Online hundi is on' : 'Online hundi is off'),
                          subtitle: const Text('The temple\'s owner turns it on or off.'),
                        ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(
                          child: Figure('Today', rupees(today['amount_paise']), emphasis: true, color: theme.colorScheme.primary, caption: _gifts(today['count'])),
                        ),
                        Expanded(child: Figure('This month', rupees(month['amount_paise']), caption: _gifts(month['count']))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Figure('In all', rupees(total['amount_paise']), caption: _gifts(total['count']))),
                      ]),
                    ]),
                  ),
                ),
                const SectionTitle('Gifts'),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text('No gifts yet.', textAlign: TextAlign.center),
                  ),
                for (final g in items)
                  Card(
                    child: ListTile(
                      title: Text('${g['donor'] ?? 'A devotee'} · ${g['amount'] ?? rupees(g['amount_paise'])}'),
                      subtitle: Text([
                        if (_map(g['purpose'])['label'] != null) '${_map(g['purpose'])['label']}',
                        if (g['paid_on'] != null) '${g['paid_on']}',
                        g['settled'] == true ? 'Paid out' : 'Not yet paid out',
                        if (g['note'] != null && '${g['note']}'.isNotEmpty) '"${g['note']}"',
                      ].join(' · ')),
                      trailing: StatusChip.forStatus(_chip('${_map(g['status'])['value']}'), '${_map(g['status'])['label'] ?? ''}'),
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

String _gifts(dynamic count) => '${_n(count)} ${_n(count) == 1 ? 'gift' : 'gifts'}';

/// Donation states in the colours the other chips use.
String _chip(String status) => switch (status) {
      'paid' => 'confirmed',
      'failed' => 'cancelled',
      _ => status,
    };
