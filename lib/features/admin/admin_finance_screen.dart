import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
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

  /// Narrows both lists to one temple: its name or town, or a reference.
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Json row, {Json? temple}) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final t = temple ?? row;
    return '${t['name'] ?? ''}'.toLowerCase().contains(q) ||
        '${t['city'] ?? ''}'.toLowerCase().contains(q) ||
        '${row['reference'] ?? ''}'.toLowerCase().contains(q);
  }

  Future<(Json, List<Json>)> _load() async {
    final api = context.read<Session>().api;
    final overview = await api.get('admin/finance');
    final pending = await api.get('admin/settlements', {'status': 'pending'});
    return (
      _map(overview['data']),
      [for (final r in pending['data'] as List) _map(r)]
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _settle(Json t) async {
    final api = context.read<Session>().api;
    final note = TextEditingController();
    final account =
        t['payout_account'] == null ? null : _map(t['payout_account']);
    final ahead = _n(t['ahead_gross_paise']);
    var all = true;
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(s('ad_settle_with', {'name': t['name']})),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('ad_settle_summary', {
                  'n': _n(t['ready_bookings']),
                  'total': rupees(t['ready_gross_paise']),
                  'net': rupees(t['ready_net_paise']),
                  'fee': t['fee_percent'],
                })),
                if (_n(t['ready_donations_paise']) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s('ad_includes_hundi',
                        {'amount': rupees(t['ready_donations_paise'])})),
                  ),
                if (ahead > 0)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: all,
                    onChanged: (v) => setDialog(() => all = v),
                    title: Text(
                        s('ad_include_advance', {'amount': rupees(ahead)})),
                    subtitle:
                        Text(all ? s('ad_advance_on') : s('ad_advance_off')),
                  ),
                const SizedBox(height: 8),
                Text(account == null || account['is_complete'] != true
                    ? s('ad_no_payout_details')
                    : account['is_verified'] == true
                        ? s('ad_pays_verified')
                        : s('ad_payout_not_verified')),
                TextField(
                    controller: note,
                    decoration:
                        InputDecoration(labelText: s('ad_note_temple_sees'))),
              ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(s('ad_prepare'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.post('admin/temples/${t['id']}/settlements', {
        'all': all,
        if (note.text.trim().isNotEmpty) 'note': note.text.trim()
      });
      if (mounted) showMessage(context, s('ad_settlement_prepared'));
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _open(Json s) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AdminSettlementScreen(settlement: s)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s('finance')),
        actions: [
          IconButton(
            tooltip: s('ad_paid_settlements'),
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _PaidSettlementsScreen())),
          ),
        ],
      ),
      body: FutureBuilder<(Json, List<Json>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final (o, pending) = snap.data!;
          final today = _map(o['today']);
          final collected = _map(o['collected_today']);
          final month = _map(o['month']);
          final temples = [
            for (final t in (o['temples'] as List? ?? const [])) _map(t)
          ];
          final owed =
              temples.where((t) => _n(t['ready_gross_paise']) > 0).toList();

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                HeroPanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('ad_sevas_today_caps'),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(rupees(today['amount_paise']),
                              style: const TextStyle(
                                  fontFamily: TrustTheme.serif,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1)),
                        ),
                        Text(
                            s('ad_paid_collected', {
                              'n': _n(today['bookings']),
                              'amount': rupees(collected['amount_paise'])
                            }),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                              child: _Panel(
                                  s('this_month'),
                                  rupees(month['amount_paise']),
                                  s('n_bookings',
                                      {'n': _n(month['bookings'])}))),
                          Expanded(
                              child: _Panel(
                                  s('ad_owed_to_temples'),
                                  rupees(o['ready_net_paise']),
                                  s('ad_paid_not_settled'))),
                          Expanded(
                              child: _Panel(
                                  s('being_paid'),
                                  rupees(o['in_payout_net_paise']),
                                  s('ad_n_to_transfer',
                                      {'n': pending.length}))),
                        ]),
                      ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: s('ad_search_finance'),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                if (pending
                    .any((p) => _matches(p, temple: _map(p['temple'])))) ...[
                  SectionTitle(s('ad_waiting_transfer')),
                  for (final p in pending
                      .where((p) => _matches(p, temple: _map(p['temple']))))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          title: Text(
                              '${_map(p['temple'])['name'] ?? ''} · ${rupees(p['net_paise'])}'),
                          subtitle: Text(
                              '${p['reference']} · ${p['period']} · ${s('n_bookings', {
                                'n': _n(p['bookings_count'])
                              })}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(p),
                        ),
                      ),
                    ),
                ],
                SectionTitle(s('ad_ready_to_settle')),
                if (owed.isEmpty)
                  Card(
                      child: ListTile(
                          title: Text(s('ad_nothing_owed')),
                          subtitle: Text(s('ad_nothing_owed_hint')))),
                if (owed.isNotEmpty && !owed.any(_matches))
                  Card(
                      child: ListTile(
                          title: Text(s('ad_no_temple_matches',
                              {'q': _search.text.trim()})),
                          subtitle: Text(s('ad_clear_search')))),
                for (final t in owed.where(_matches))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        title: Text('${t['name']}'),
                        subtitle: Text([
                          s('ad_n_paid_items', {'n': _n(t['ready_bookings'])}),
                          s('ad_gets',
                              {'amount': rupees(t['ready_net_paise'])}),
                          _payoutState(s, t['payout_account']),
                        ].join(' · ')),
                        trailing: FilledButton.tonal(
                            onPressed: () => _settle(t),
                            child: Text(s('ad_settle'))),
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

String _payoutState(S s, dynamic account) {
  final a = _map(account);
  if (a['is_complete'] != true) return s('ad_no_payout_details_lc');
  return a['is_verified'] == true
      ? s('ad_account_verified')
      : s('ad_account_to_verify');
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
      final res = await context
          .read<Session>()
          .api
          .post('admin/settlements/${_s['id']}/paid', {
        'method': _method,
        if (_ref.text.trim().isNotEmpty) 'transaction_ref': _ref.text.trim(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      setState(() => _s = _map(res['data']));
      showMessage(context, S.of(context)('ad_marked_paid'));
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
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s('ad_cancel_settlement_q')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s('ad_cancel_settlement_body')),
          TextField(
              controller: reason,
              decoration: InputDecoration(labelText: s('reason'))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s('ad_keep'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s('ad_cancel_settlement'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await context.read<Session>().api.post(
          'admin/settlements/${_s['id']}/cancel',
          {'reason': reason.text.trim()});
      if (!mounted) return;
      setState(() => _s = _map(res['data']));
      showMessage(context, s('ad_settlement_cancelled'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _map(_s['status'])['value'] == 'pending';
    final to = _s['payout_to'] == null ? null : _map(_s['payout_to']);
    final theme = Theme.of(context);
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
          title: Text('${_map(_s['temple'])['name'] ?? s('settlement')}',
              overflow: TextOverflow.ellipsis)),
      body: SettlementDetails(
        settlement: _s,
        footer:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle(s('ad_pay_to')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: to == null
                  ? Text(s('ad_no_payout_when_prepared'))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          if (to['account_name'] != null)
                            SelectableText('${to['account_name']}',
                                style: theme.textTheme.titleMedium),
                          if (to['account_number'] != null)
                            SelectableText(s('ad_account_no', {
                              'number': to['account_number'],
                              'ifsc': to['ifsc'] ?? ''
                            })),
                          if (to['bank_name'] != null)
                            Text('${to['bank_name']}'),
                          if (to['upi_id'] != null)
                            SelectableText('UPI ${to['upi_id']}'),
                          if (to['verified'] != true)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(s('ad_not_verified_prepared'),
                                  style: TextStyle(
                                      color: theme.colorScheme.error)),
                            ),
                        ]),
            ),
          ),
          if (pending) ...[
            SectionTitle(s('ad_record_transfer')),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: InputDecoration(labelText: s('ad_paid_by')),
              items: [
                DropdownMenuItem(
                    value: 'bank', child: Text(s('ad_method_bank'))),
                const DropdownMenuItem(value: 'upi', child: Text('UPI')),
                DropdownMenuItem(
                    value: 'cheque', child: Text(s('ad_method_cheque'))),
                DropdownMenuItem(
                    value: 'cash', child: Text(s('ad_method_cash'))),
              ],
              onChanged: (v) => setState(() => _method = v ?? 'bank'),
            ),
            const SizedBox(height: 12),
            ApiTextField(
                controller: _ref,
                label: s('ad_utr_label'),
                field: 'transaction_ref',
                error: _error),
            ApiTextField(
                controller: _note,
                label: s('ad_note_temple_sees'),
                field: 'note',
                error: _error),
            FilledButton.icon(
              onPressed: _busy ? null : _paid,
              icon: const Icon(Icons.check_circle_outline),
              label:
                  Text(s('ad_mark_paid', {'amount': rupees(_s['net_paise'])})),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: _busy ? null : _cancel,
                child: Text(s('ad_cancel_settlement'))),
          ],
        ]),
      ),
    );
  }
}

class _PaidSettlementsScreen extends StatefulWidget {
  const _PaidSettlementsScreen();

  @override
  State<_PaidSettlementsScreen> createState() => _PaidSettlementsScreenState();
}

class _PaidSettlementsScreenState extends State<_PaidSettlementsScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 400), () => _list.currentState?.reload());
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim();
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('ad_paid_settlements'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _search,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: s('ad_search_paid'),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _changed('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: AsyncList<Json>(
            key: _list,
            load: () async {
              final q = _search.text.trim();
              final res = await context.read<Session>().api.get(
                  'admin/settlements',
                  {'status': 'paid', if (q.length >= 2) 'q': q});
              return [for (final r in res['data'] as List) _map(r)];
            },
            empty: q.length >= 2
                ? s('ad_no_paid_match', {'q': q})
                : s('ad_nothing_paid'),
            itemBuilder: (context, p, reload) => Card(
              child: ListTile(
                title: Text(
                    '${_map(p['temple'])['name'] ?? ''} · ${rupees(p['net_paise'])}'),
                subtitle:
                    Text('${p['period']} · UTR ${p['transaction_ref'] ?? '—'}'),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AdminSettlementScreen(settlement: p))),
              ),
            ),
          ),
        ),
      ]),
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
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, height: 1.2))),
      Text(caption,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    ]);
  }
}
