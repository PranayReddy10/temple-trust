import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../temple/finance_screen.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

/// Settling with temples: what devotees paid today and this month, what
/// each temple is owed, and the payouts waiting for the transfer. The same
/// service as Admin → Finance on the web.
class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  late Future<(Json, List<Json>)> _future = _load();

  Future<(Json, List<Json>)> _load() async {
    final api = context.read<Session>().api;
    final overview = await api.get('admin/finance');
    final pending = await api.get('admin/settlements', {'status': 'pending'});
    return (_map(overview['data']), [for (final r in pending['data'] as List) _map(r)]);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _settle(Json t) async {
    final api = context.read<Session>().api;
    final note = TextEditingController();
    final account = t['payout_account'] == null ? null : _map(t['payout_account']);
    final ahead = _n(t['ahead_gross_paise']);
    var all = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text('Settle with ${t['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_n(t['ready_bookings'])} paid items, ${rupees(t['ready_gross_paise'])} in all. '
                'The temple gets ${rupees(t['ready_net_paise'])} after a ${t['fee_percent']}% fee.'),
            if (_n(t['ready_donations_paise']) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Includes ${rupees(t['ready_donations_paise'])} in online hundi gifts, settled with the bookings and tickets.'),
              ),
            if (ahead > 0)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: all,
                onChanged: (v) => setDialog(() => all = v),
                title: Text('Include ${rupees(ahead)} paid in advance'),
                subtitle: Text(all
                    ? 'Bookings for today and days ahead are paid out now and can no longer be cancelled.'
                    : 'Only seva days up to yesterday; the rest waits for a later settlement.'),
              ),
            const SizedBox(height: 8),
            Text(account == null || account['is_complete'] != true
                ? 'No payout details yet: add them before you transfer.'
                : account['is_verified'] == true
                    ? 'Pays to a verified account.'
                    : 'Payout details are NOT verified: call the temple before you transfer.'),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (the temple sees this)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Prepare')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.post('admin/temples/${t['id']}/settlements', {'all': all, if (note.text.trim().isNotEmpty) 'note': note.text.trim()});
      if (mounted) showMessage(context, 'Settlement prepared. Transfer it, then mark it paid with the UTR.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _open(Json s) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSettlementScreen(settlement: s)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            tooltip: 'Paid settlements',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PaidSettlementsScreen())),
          ),
        ],
      ),
      body: FutureBuilder<(Json, List<Json>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final (o, pending) = snap.data!;
          final today = _map(o['today']);
          final collected = _map(o['collected_today']);
          final month = _map(o['month']);
          final temples = [for (final t in (o['temples'] as List? ?? const [])) _map(t)];
          final owed = temples.where((t) => _n(t['ready_gross_paise']) > 0).toList();
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Figure('Sevas today', rupees(today['amount_paise']), emphasis: true, color: theme.colorScheme.primary, caption: '${_n(today['bookings'])} paid bookings')),
                        Expanded(child: Figure('Collected today', rupees(collected['amount_paise']), caption: 'through the gateway')),
                      ]),
                      const Divider(height: 24),
                      Row(children: [
                        Expanded(child: Figure('This month', rupees(month['amount_paise']), caption: '${_n(month['bookings'])} bookings')),
                        Expanded(child: Figure('Owed to temples', rupees(o['ready_net_paise']), caption: 'paid, not yet settled')),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Figure('Being paid', rupees(o['in_payout_net_paise']), caption: '${pending.length} to transfer')),
                      ]),
                    ]),
                  ),
                ),
                if (pending.isNotEmpty) ...[
                  const SectionTitle('Waiting for the transfer'),
                  for (final s in pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text('${_map(s['temple'])['name'] ?? ''} · ${rupees(s['net_paise'])}'),
                          subtitle: Text('${s['reference']} · ${s['period']} · ${_n(s['bookings_count'])} bookings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(s),
                        ),
                      ),
                    ),
                ],
                const SectionTitle('Ready to settle'),
                if (owed.isEmpty)
                  const Card(child: ListTile(title: Text('Nothing owed right now'), subtitle: Text('Temples appear here once devotees pay for a seva.'))),
                for (final t in owed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text('${t['name']}'),
                        subtitle: Text([
                          '${_n(t['ready_bookings'])} paid items',
                          'gets ${rupees(t['ready_net_paise'])}',
                          _payoutState(t['payout_account']),
                        ].join(' · ')),
                        trailing: FilledButton.tonal(onPressed: () => _settle(t), child: const Text('Settle')),
                      ),
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

String _payoutState(dynamic account) {
  final a = _map(account);
  if (a['is_complete'] != true) return 'no payout details';
  return a['is_verified'] == true ? 'account verified' : 'account to verify';
}

/// One settlement for the person paying it: where to send the money, then
/// the bank reference once sent.
class AdminSettlementScreen extends StatefulWidget {
  const AdminSettlementScreen({super.key, required this.settlement});

  final Json settlement;

  @override
  State<AdminSettlementScreen> createState() => _AdminSettlementScreenState();
}

class _AdminSettlementScreenState extends State<AdminSettlementScreen> {
  late Json _s = widget.settlement;
  final _ref = TextEditingController();
  final _note = TextEditingController();
  String _method = 'bank';
  ApiException? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _paid() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await context.read<Session>().api.post('admin/settlements/${_s['id']}/paid', {
        'method': _method,
        if (_ref.text.trim().isNotEmpty) 'transaction_ref': _ref.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      setState(() => _s = _map(res['data']));
      showMessage(context, 'Marked paid. The temple sees the reference in its app.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this settlement?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Only if nothing was transferred. Its bookings go back to the temple\'s balance.'),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel settlement')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await context.read<Session>().api.post('admin/settlements/${_s['id']}/cancel', {'reason': reason.text.trim()});
      if (!mounted) return;
      setState(() => _s = _map(res['data']));
      showMessage(context, 'Settlement cancelled.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _map(_s['status'])['value'] == 'pending';
    final to = _s['payout_to'] == null ? null : _map(_s['payout_to']);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('${_map(_s['temple'])['name'] ?? 'Settlement'}', overflow: TextOverflow.ellipsis)),
      body: SettlementDetails(
        settlement: _s,
        footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('Pay to'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: to == null
                  ? const Text('No payout details when this was prepared. Ask the temple\'s owner to add them in the app, then cancel and prepare again.')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (to['account_name'] != null) SelectableText('${to['account_name']}', style: theme.textTheme.titleMedium),
                      if (to['account_number'] != null) SelectableText('A/c ${to['account_number']} · ${to['ifsc'] ?? ''}'),
                      if (to['bank_name'] != null) Text('${to['bank_name']}'),
                      if (to['upi_id'] != null) SelectableText('UPI ${to['upi_id']}'),
                      if (to['verified'] != true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Not verified when prepared: confirm with the temple before transferring.', style: TextStyle(color: theme.colorScheme.error)),
                        ),
                    ]),
            ),
          ),
          if (pending) ...[
            const SectionTitle('Record the transfer'),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: const [
                DropdownMenuItem(value: 'bank', child: Text('Bank transfer (NEFT / IMPS / RTGS)')),
                DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'bank'),
            ),
            const SizedBox(height: 12),
            ApiTextField(controller: _ref, label: 'UTR / transaction or cheque number', field: 'transaction_ref', error: _error),
            ApiTextField(controller: _note, label: 'Note (the temple sees this)', field: 'note', error: _error),
            FilledButton.icon(
              onPressed: _busy ? null : _paid,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Mark ${rupees(_s['net_paise'])} paid'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('Cancel settlement')),
          ],
        ]),
      ),
    );
  }
}

class _PaidSettlementsScreen extends StatelessWidget {
  const _PaidSettlementsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paid settlements')),
      body: AsyncList<Json>(
        load: () async {
          final res = await context.read<Session>().api.get('admin/settlements', {'status': 'paid'});
          return [for (final r in res['data'] as List) _map(r)];
        },
        empty: 'Nothing paid yet.',
        itemBuilder: (context, s, reload) => Card(
          child: ListTile(
            title: Text('${_map(s['temple'])['name'] ?? ''} · ${rupees(s['net_paise'])}'),
            subtitle: Text('${s['period']} · UTR ${s['transaction_ref'] ?? '—'}'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminSettlementScreen(settlement: s))),
          ),
        ),
      ),
    );
  }
}
