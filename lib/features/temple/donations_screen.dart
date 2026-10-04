import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
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

  /// Donor's name, part of their phone number, or the receipt reference.
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _reload);
  }

  Future<Json> _load() async {
    final q = _search.text.trim();
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/donations', {if (q.length >= 2) 'q': q});
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
                HeroPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('HUNDI TODAY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rupees(today['amount_paise']), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 32, fontWeight: FontWeight.w600, height: 1.1)),
                    ),
                    Text(_gifts(today['count']), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _Panel('This month', rupees(month['amount_paise']), _gifts(month['count']))),
                      Expanded(child: _Panel('In all', rupees(total['amount_paise']), _gifts(total['count']))),
                    ]),
                  ]),
                ),
                const SectionTitle('Gifts'),
                TextField(
                  controller: _search,
                  onChanged: _searchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search donor name, mobile number or receipt',
                    helperText: 'Gifts made anonymously are found only by their receipt reference.',
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              _searchChanged('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      _search.text.trim().length >= 2 ? 'No gift matches "${_search.text.trim()}".' : 'No gifts yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final g in items)
                  Card(
                    child: ListTile(
                      leading: IconBadge(Icons.volunteer_activism_outlined, color: g['settled'] == true ? Palette.tulsi : Palette.gold),
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

class _Panel extends StatelessWidget {
  const _Panel(this.label, this.value, this.caption);

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.2))),
      Text(caption, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }
}

String _gifts(dynamic count) => '${_n(count)} ${_n(count) == 1 ? 'gift' : 'gifts'}';

/// Donation states in the colours the other chips use.
String _chip(String status) => switch (status) {
      'paid' => 'confirmed',
      'failed' => 'cancelled',
      _ => status,
    };
