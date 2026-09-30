import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import 'bookings_screen.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

/// A temple's money: who booked a day and what they paid, the month, what
/// the platform holds for the temple, every payout with its bank reference,
/// and the account it is paid to.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.templeId, required this.title});

  final int templeId;
  final String title;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  DateTime _day = DateTime.now();
  late Future<Json> _future = _load();

  Future<Json> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/finance', {'date': formatDate(_day)});
    return _map(res['data']);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  bool get _isToday => formatDate(_day) == formatDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance')),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final f = snap.data!;
          final day = _map(f['day']);
          final month = _map(f['month']);
          final balance = _map(f['balance']);
          final ready = _map(balance['ready']);
          final upcoming = _map(balance['upcoming']);
          final inPayout = _map(balance['in_payout']);
          final paid = _map(balance['paid']);
          final account = f['payout_account'] == null ? null : _map(f['payout_account']);
          final recent = [for (final s in (f['recent_settlements'] as List? ?? const [])) _map(s)];
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text(widget.title, style: theme.textTheme.titleLarge),
                SectionTitle(
                  _isToday ? 'Today' : 'Day',
                  trailing: SizedBox(
                    width: 170,
                    child: DateField(
                      label: 'Day',
                      value: _day,
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() => _day = d);
                        _reload();
                      },
                    ),
                  ),
                ),
                _DayCard(day: day, onOpen: () => _open(BookingsScreen(templeId: widget.templeId, initialDay: _day))),
                const SectionTitle('This month'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(child: Figure('Paid bookings', '${_n(month['bookings'])}', caption: '${_n(month['people'])} people')),
                      Expanded(child: Figure('Paid by devotees', rupees(month['amount_paise']), emphasis: true)),
                    ]),
                  ),
                ),
                const SectionTitle('Settlement'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Figure(
                              'Due to your temple',
                              rupees(ready['net_paise']),
                              emphasis: true,
                              color: theme.colorScheme.primary,
                              caption: '${_n(ready['bookings'])} bookings · ${rupees(ready['gross_paise'])} less ${rupees(ready['fee_paise'])} fee',
                            ),
                          ),
                        ]),
                        const Divider(height: 24),
                        Row(children: [
                          Expanded(child: Figure('Being paid', rupees(inPayout['net_paise']), caption: '${_n(inPayout['settlements'])} settlements')),
                          Expanded(child: Figure('Paid to date', rupees(paid['net_paise']), caption: '${_n(paid['settlements'])} settlements')),
                        ]),
                        const SizedBox(height: 12),
                        Text(
                          'Devotees pay through the platform; it pays your temple in regular settlements, '
                          'less a ${_percent(balance['fee_percent'])} platform fee. '
                          '${rupees(upcoming['gross_paise'])} is already paid for ${_n(upcoming['bookings'])} bookings on days still ahead.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                SectionTitle(
                  'Payouts',
                  trailing: TextButton(
                    onPressed: () => _open(SettlementsScreen(templeId: widget.templeId)),
                    child: const Text('See all'),
                  ),
                ),
                if (recent.isEmpty)
                  const Card(child: ListTile(title: Text('No payouts yet'), subtitle: Text('They appear here once the platform settles your paid bookings.'))),
                for (final s in recent)
                  _SettlementTile(s, onTap: () => _open(SettlementDetailScreen(templeId: widget.templeId, settlementId: _n(s['id'])))),
                const SectionTitle('Paid to'),
                _PayoutCard(
                  account: account,
                  canEdit: f['can_edit_payout_account'] == true,
                  onEdit: () => _open(PayoutAccountScreen(templeId: widget.templeId, account: account)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _percent(dynamic v) {
  final p = (v as num?)?.toDouble() ?? 0;
  final s = p.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$s%';
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.onOpen});

  final Json day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bySeva = [for (final r in (day['by_seva'] as List? ?? const [])) _map(r)];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Figure('Amount paid', rupees(day['amount_paise']), emphasis: true, color: theme.colorScheme.primary)),
                Expanded(child: Figure('Booked', '${_n(day['bookings'])}', caption: '${_n(day['people'])} people')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Figure('Received', '${_n(day['received'])}', caption: 'scanned at the counter')),
                Expanded(child: Figure('Still to come', '${_n(day['to_receive'])}')),
              ]),
              if (_n(day['awaiting_payment']) > 0 || _n(day['cancelled']) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    [
                      if (_n(day['awaiting_payment']) > 0) '${_n(day['awaiting_payment'])} not paid yet',
                      if (_n(day['cancelled']) > 0) '${_n(day['cancelled'])} cancelled or refunded',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (bySeva.isNotEmpty) ...[
                const Divider(height: 24),
                for (final r in bySeva)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(child: Text('${r['seva']}', overflow: TextOverflow.ellipsis)),
                      Text('${_n(r['bookings'])} · ${_n(r['people'])} ppl', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      SizedBox(width: 96, child: Text(rupees(r['amount_paise']), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                  ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('See who booked ›', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile(this.s, {required this.onTap});

  final Json s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _map(s['status']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          title: Text('${rupees(s['net_paise'])} · ${s['period']}'),
          subtitle: Text([
            '${_n(s['bookings_count'])} bookings',
            if (s['transaction_ref'] != null) 'UTR ${s['transaction_ref']}',
            if (s['paid_at'] != null) 'paid ${_date(s['paid_at'])}',
          ].join(' · ')),
          trailing: StatusChip.forStatus(_chip('${status['value']}'), '${status['label']}'),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Settlement states in the colours the other chips use.
String _chip(String status) => switch (status) {
      'paid' => 'approved',
      'pending' => 'pending',
      _ => 'cancelled',
    };

String _date(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : formatDate(d);
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.account, required this.canEdit, required this.onEdit});

  final Json? account;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final a = account;
    final complete = a != null && a['is_complete'] == true;
    return Card(
      child: ListTile(
        leading: Icon(Icons.account_balance_outlined, color: Theme.of(context).colorScheme.primary),
        title: Text(complete ? '${a['account_name'] ?? 'UPI'}' : 'No payout account yet'),
        subtitle: Text(complete
            ? [
                if (a['bank_name'] != null) '${a['bank_name']}',
                if (a['account_number_masked'] != null) '${a['account_number_masked']}',
                if (a['ifsc'] != null) '${a['ifsc']}',
                if (a['upi_id'] != null) 'UPI ${a['upi_id']}',
              ].join(' · ')
            : canEdit
                ? 'Add the trust\'s bank account or UPI id so the platform can pay you.'
                : 'The temple\'s owner adds this in the app.'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (complete)
            a['is_verified'] == true ? StatusChip.forStatus('verified', 'Verified') : StatusChip.forStatus('pending', 'Being checked'),
          if (canEdit) const Icon(Icons.chevron_right),
        ]),
        onTap: canEdit ? onEdit : null,
      ),
    );
  }
}

/// Every payout to the temple.
class SettlementsScreen extends StatelessWidget {
  const SettlementsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: AsyncList<Json>(
        load: () async {
          final res = await context.read<Session>().api.get('temples/$templeId/settlements');
          return [for (final r in res['data'] as List) _map(r)];
        },
        empty: 'No payouts yet.',
        itemBuilder: (context, s, reload) => _SettlementTile(
          s,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettlementDetailScreen(templeId: templeId, settlementId: _n(s['id'])))),
        ),
      ),
    );
  }
}

/// One payout: the money, the bank reference, and every booking it covers.
class SettlementDetailScreen extends StatefulWidget {
  const SettlementDetailScreen({super.key, required this.templeId, required this.settlementId});

  final int templeId;
  final int settlementId;

  @override
  State<SettlementDetailScreen> createState() => _SettlementDetailScreenState();
}

class _SettlementDetailScreenState extends State<SettlementDetailScreen> {
  late Future<Json> _future = _load();

  Future<Json> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/settlements/${widget.settlementId}');
    return _map(res['data']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout')),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _future = _load()));
          return SettlementDetails(settlement: snap.data!);
        },
      ),
    );
  }
}

/// A settlement in full, shared with the admin's screen.
class SettlementDetails extends StatelessWidget {
  const SettlementDetails({super.key, required this.settlement, this.footer});

  final Json settlement;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = settlement;
    final status = _map(s['status']);
    final bookings = [for (final b in (s['bookings'] as List? ?? const [])) _map(b)];
    final theme = Theme.of(context);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(label, style: theme.textTheme.bodySmall)),
            Expanded(child: Text(value)),
          ]),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(children: [
          Expanded(child: Text('${s['reference']}', style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace'))),
          StatusChip.forStatus(_chip('${status['value']}'), '${status['label']}'),
        ]),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Figure('To the temple', rupees(s['net_paise']), emphasis: true, color: theme.colorScheme.primary),
              const Divider(height: 24),
              row('Seva days', '${s['period']}'),
              row('Bookings', '${_n(s['bookings_count'])}'),
              row('Paid by devotees', rupees(s['gross_paise'])),
              row('Platform fee', '${rupees(s['fee_paise'])} (${_percent(s['fee_percent'])})'),
              if (s['method_label'] != null) row('Paid by', '${s['method_label']}'),
              if (s['transaction_ref'] != null) row('Reference (UTR)', '${s['transaction_ref']}'),
              if (s['paid_at'] != null) row('Paid on', _date(s['paid_at'])),
              if (s['note'] != null) row('Note', '${s['note']}'),
              if (s['cancel_reason'] != null) row('Cancelled', '${s['cancel_reason']}'),
            ]),
          ),
        ),
        if (footer != null) footer!,
        if (bookings.isNotEmpty) ...[
          const SectionTitle('Bookings in this payout'),
          for (final b in bookings)
            Card(
              child: ListTile(
                dense: true,
                title: Text('${b['devotee_name']} · ${_n(b['people'])} ${_n(b['people']) == 1 ? 'person' : 'people'}'),
                subtitle: Text('${b['seva'] ?? ''} · ${b['booked_for']} · Ref ${b['reference']}'),
                trailing: Text(rupees(b['amount_paise']), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Where the platform pays the temple. The owner only; the full account
/// number never comes back from the server, so leaving it blank keeps it.
class PayoutAccountScreen extends StatefulWidget {
  const PayoutAccountScreen({super.key, required this.templeId, this.account});

  final int templeId;
  final Json? account;

  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  late final _name = TextEditingController(text: widget.account?['account_name'] as String?);
  final _number = TextEditingController();
  late final _ifsc = TextEditingController(text: widget.account?['ifsc'] as String?);
  late final _bank = TextEditingController(text: widget.account?['bank_name'] as String?);
  late final _upi = TextEditingController(text: widget.account?['upi_id'] as String?);
  ApiException? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _number, _ifsc, _bank, _upi]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<Session>().api.put('temples/${widget.templeId}/payout-account', {
        'account_name': _v(_name),
        'account_number': _v(_number),
        'ifsc': _v(_ifsc),
        'bank_name': _v(_bank),
        'upi_id': _v(_upi),
      });
      if (!mounted) return;
      showMessage(context, 'Saved. The platform checks new details before paying to them.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = widget.account?['account_number_masked'];
    return Scaffold(
      appBar: AppBar(title: const Text('Payout account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('The trust\'s own account. Settlements are transferred here. A change is checked by the platform, usually by calling you, before money is sent to it.'),
          const SizedBox(height: 16),
          ApiTextField(controller: _name, label: 'Account holder name', field: 'account_name', error: _error),
          ApiTextField(
            controller: _number,
            label: 'Account number',
            field: 'account_number',
            error: _error,
            keyboardType: TextInputType.number,
            hint: masked == null ? null : 'On file: $masked · leave blank to keep',
          ),
          ApiTextField(controller: _ifsc, label: 'IFSC', field: 'ifsc', error: _error, hint: 'e.g. SBIN0001234'),
          ApiTextField(controller: _bank, label: 'Bank and branch', field: 'bank_name', error: _error),
          const Padding(padding: EdgeInsets.fromLTRB(0, 8, 0, 8), child: Text('Or, or as well:')),
          ApiTextField(controller: _upi, label: 'UPI ID', field: 'upi_id', error: _error, hint: 'name@bank'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
