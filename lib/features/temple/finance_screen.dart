import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'bookings_screen.dart';
import 'payments_verification_screen.dart';
import 'donations_screen.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

/// A temple's money, in full: any day's bookings and what they paid, the
/// month, the year and all time; what the platform holds for the temple;
/// every payout with its bank reference; and the account it is paid to.
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

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  bool get _isToday => formatDate(_day) == formatDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('finance'))),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
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
          final recent = [for (final x in (f['recent_settlements'] as List? ?? const [])) _map(x)];
          final theme = Theme.of(context);

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(widget.title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                const SizedBox(height: 8),

                // What is due, first: the figure the trust opens this for.
                HeroPanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s('due_to_temple').toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(rupees(ready['net_paise']), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 34, fontWeight: FontWeight.w600, height: 1.1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        s('n_bookings', {'n': _n(ready['bookings'])}),
                        if (_n(ready['tickets']) > 0) s('n_tickets', {'n': _n(ready['tickets'])}),
                        if (_n(ready['donations']) > 0) s('n_gifts', {'n': _n(ready['donations'])}),
                        '${rupees(ready['gross_paise'])} − ${rupees(ready['fee_paise'])} ${s('platform_fee').toLowerCase()}',
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _HeroFigure(s('being_paid'), rupees(inPayout['net_paise']), s('n_settlements', {'n': _n(inPayout['settlements'])}))),
                      Expanded(child: _HeroFigure(s('paid_to_date'), rupees(paid['net_paise']), s('n_settlements', {'n': _n(paid['settlements'])}))),
                    ]),
                  ]),
                ),

                // The report: every period, with sevas, tickets and hundi.
                SectionTitle(s('financial_report'), subtitle: s('report_hint')),
                _ReportTabs(finance: f),

                SectionTitle(
                  _isToday ? s('today') : s('day'),
                  trailing: SizedBox(
                    width: 170,
                    child: DateField(
                      label: s('day'),
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

                SectionTitle(s('settlement')),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Figure(s('due_to_temple'), rupees(ready['net_paise']), emphasis: true, color: theme.colorScheme.primary)),
                        Expanded(child: Figure(s('upcoming'), rupees(upcoming['gross_paise']), caption: s('n_bookings', {'n': _n(upcoming['bookings'])}))),
                      ]),
                      const Divider(height: 24),
                      Row(children: [
                        Expanded(child: Figure(s('being_paid'), rupees(inPayout['net_paise']), caption: s('n_settlements', {'n': _n(inPayout['settlements'])}))),
                        Expanded(child: Figure(s('paid_to_date'), rupees(paid['net_paise']), caption: s('n_settlements', {'n': _n(paid['settlements'])}))),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        'Devotees pay through the platform; it pays your temple in regular settlements, '
                        'less a ${_percent(balance['fee_percent'])} platform fee'
                        '${balance['donation_fee_percent'] != null ? ' (${_percent(balance['donation_fee_percent'])} on hundi gifts)' : ''}. '
                        '${rupees(upcoming['gross_paise'])} is already paid for ${_n(upcoming['bookings'])} bookings on days still ahead.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                FeeShareCard(feePercent: balance['fee_percent'], donationFeePercent: balance['donation_fee_percent']),

                SectionTitle(s('online_hundi')),
                ActionTile(
                  icon: Icons.volunteer_activism_outlined,
                  color: Palette.gold,
                  title: f['accepts_donations'] == true ? s('taking_gifts') : s('not_taking_gifts'),
                  subtitle: '${s('today')} ${rupees(_map(day['donations'])['amount_paise'])} · ${s('this_month').toLowerCase()} ${rupees(_map(month['donations'])['amount_paise'])}',
                  onTap: () => _open(DonationsScreen(templeId: widget.templeId)),
                ),

                SectionTitle(
                  s('payouts'),
                  trailing: TextButton(
                    onPressed: () => _open(SettlementsScreen(templeId: widget.templeId)),
                    child: Text(s('see_all')),
                  ),
                ),
                if (recent.isEmpty) SoftCard(child: Row(children: [const IconBadge(Icons.receipt_long_outlined), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s('no_payouts'), style: theme.textTheme.titleMedium), Text(s('no_payouts_body'), style: theme.textTheme.bodySmall)]))])),
                for (final x in recent) _SettlementTile(x, onTap: () => _open(SettlementDetailScreen(templeId: widget.templeId, settlementId: _n(x['id'])))),

                SectionTitle(s('paid_to')),
                if ((account?['kyc'] as Map?)?['status'] == 'rejected')
                  RejectionNotice(
                    reason: (account!['kyc'] as Map)['rejection_reason'] as String?,
                    rejectedAt: DateTime.tryParse('${(account['kyc'] as Map)['rejected_at']}')?.toLocal(),
                    canFix: f['can_edit_payout_account'] == true,
                    onTap: () => _open(PaymentsVerificationScreen(templeId: widget.templeId)),
                  ),
                _PayoutCard(
                  account: account,
                  canEdit: f['can_edit_payout_account'] == true,
                  onEdit: () => _open(PaymentsVerificationScreen(templeId: widget.templeId)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value, this.caption);

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

/// Today · this month · this year · all time, each with the sevas, tickets
/// and hundi gifts that make up the total. Year and all-time come from
/// newer servers; an older one shows the first two.
class _ReportTabs extends StatefulWidget {
  const _ReportTabs({required this.finance});

  final Json finance;

  @override
  State<_ReportTabs> createState() => _ReportTabsState();
}

class _ReportTabsState extends State<_ReportTabs> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final f = widget.finance;
    final periods = <(String, String, Json?)>[
      ('today', s('today'), f['today'] == null ? null : _map(f['today'])),
      ('month', s('this_month'), _map(f['month'])),
      ('year', s('this_year'), f['year'] == null ? null : _map(f['year'])),
      ('all_time', s('all_time'), f['all_time'] == null ? null : _map(f['all_time'])),
    ].where((p) => p.$3 != null).toList();
    if (!periods.any((p) => p.$1 == _period)) _period = periods.first.$1;
    final p = periods.firstWhere((p) => p.$1 == _period).$3!;
    final tickets = _map(p['tickets']);
    final gifts = _map(p['donations']);
    final total = _n(p['total_paise'] ?? p['amount_paise']);
    final sevas = _n(p['amount_paise']);
    double share(int part) => total == 0 ? 0 : part / total;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, item) in periods.indexed)
                Padding(
                  padding: EdgeInsets.only(right: i == periods.length - 1 ? 0 : 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _period == item.$1,
                    showCheckmark: false,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(color: _period == item.$1 ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
                    onSelected: (_) => setState(() => _period = item.$1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Figure(s('total_collected'), rupees(total), emphasis: true, color: theme.colorScheme.primary)),
          Expanded(child: Figure(s('total_bookings'), '${_n(p['bookings'])}', caption: s.people(_n(p['people'])))),
        ]),
        const SizedBox(height: 14),
        // Where the money came from, as a bar.
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? ColoredBox(color: theme.colorScheme.outlineVariant)
                : Row(children: [
                    if (sevas > 0) Expanded(flex: (share(sevas) * 1000).round().clamp(1, 1000), child: const ColoredBox(color: Palette.kumkum)),
                    if (_n(tickets['amount_paise']) > 0) Expanded(flex: (share(_n(tickets['amount_paise'])) * 1000).round().clamp(1, 1000), child: const ColoredBox(color: Palette.saffron)),
                    if (_n(gifts['amount_paise']) > 0) Expanded(flex: (share(_n(gifts['amount_paise'])) * 1000).round().clamp(1, 1000), child: const ColoredBox(color: Palette.gold)),
                  ]),
          ),
        ),
        const SizedBox(height: 12),
        ReportLine(label: s('sevas'), counts: '${s('n_bookings', {'n': _n(p['bookings'])})} · ${s.people(_n(p['people']))}', amount: rupees(sevas), color: Palette.kumkum),
        ReportLine(label: s('event_tickets'), counts: '${s('n_tickets', {'n': _n(tickets['count'])})} · ${s.people(_n(tickets['people']))}', amount: rupees(tickets['amount_paise']), color: Palette.saffron),
        ReportLine(label: s('online_hundi'), counts: s('n_gifts', {'n': _n(gifts['count'])}), amount: rupees(gifts['amount_paise']), color: Palette.gold),
        const Divider(height: 18),
        ReportLine(label: s('in_all'), amount: rupees(total), bold: true),
        if (p['from'] != null && p['to'] != null && _period != 'today')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${p['from']} → ${p['to']}', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ),
      ]),
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
    final s = S.of(context);
    final theme = Theme.of(context);
    final bySeva = [for (final r in (day['by_seva'] as List? ?? const [])) _map(r)];
    final tickets = _map(day['tickets']);
    final gifts = _map(day['donations']);
    final hasMore = _n(tickets['count']) > 0 || _n(gifts['count']) > 0;

    return SoftCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Figure(
                hasMore ? s('in_all') : s('amount_paid'),
                rupees(day['total_paise'] ?? day['amount_paise']),
                emphasis: true,
                color: theme.colorScheme.primary,
                caption: hasMore ? '${s('sevas')} ${rupees(day['amount_paise'])}' : null,
              ),
            ),
            Expanded(child: Figure(s('booked'), '${_n(day['bookings'])}', caption: s.people(_n(day['people'])))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Figure(s('received'), '${_n(day['received'])}', caption: s('scanned_at_counter'), color: Palette.tulsi)),
            Expanded(child: Figure(s('still_to_come'), '${_n(day['to_receive'])}')),
          ]),
          if (_n(day['awaiting_payment']) > 0 || _n(day['cancelled']) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (_n(day['awaiting_payment']) > 0) s('not_paid_yet', {'n': _n(day['awaiting_payment'])}),
                  if (_n(day['cancelled']) > 0) s('cancelled_refunded', {'n': _n(day['cancelled'])}),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (bySeva.isNotEmpty) ...[
            const Divider(height: 24),
            for (final r in bySeva) ReportLine(label: '${r['seva']}', counts: '${_n(r['bookings'])} · ${s.people(_n(r['people']))}', amount: rupees(r['amount_paise'])),
          ],
          if (hasMore) ...[
            const Divider(height: 24),
            if (_n(tickets['count']) > 0) ReportLine(label: s('event_tickets'), counts: '${_n(tickets['count'])} · ${s.people(_n(tickets['people']))}', amount: rupees(tickets['amount_paise']), color: Palette.saffron),
            if (_n(gifts['count']) > 0) ReportLine(label: s('online_hundi'), counts: s('n_gifts', {'n': _n(gifts['count'])}), amount: rupees(gifts['amount_paise']), color: Palette.gold),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s('see_who_booked'), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.primary),
            ]),
          ),
        ],
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
    final value = '${status['value']}';
    return ActionTile(
      icon: value == 'paid' ? Icons.task_alt : Icons.schedule_send_outlined,
      color: value == 'paid' ? Palette.tulsi : (value == 'pending' ? const Color(0xFFB08A10) : const Color(0xFFB3261E)),
      title: '${rupees(s['net_paise'])} · ${s['period']}',
      subtitle: [
        '${s['items'] ?? '${_n(s['bookings_count'])} bookings'}',
        if (s['transaction_ref'] != null) 'UTR ${s['transaction_ref']}',
        if (s['paid_at'] != null) 'paid ${_date(s['paid_at'])}',
      ].join(' · '),
      trailing: StatusChip.forStatus(_chip(value), '${status['label']}'),
      onTap: onTap,
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
    final kyc = '${(a?['kyc'] as Map?)?['status'] ?? 'missing'}';
    return ActionTile(
      icon: Icons.account_balance_outlined,
      title: complete ? '${a['account_name'] ?? 'UPI'}' : 'No payout account yet',
      subtitle: complete
          ? [
              if (a['bank_name'] != null) '${a['bank_name']}',
              if (a['account_number_masked'] != null) '${a['account_number_masked']}',
              if (a['ifsc'] != null) '${a['ifsc']}',
              if (a['upi_id'] != null) 'UPI ${a['upi_id']}',
            ].join(' · ')
          : canEdit
              ? 'Add the bank account and verification documents to take money in the app.'
              : 'The temple\'s owner adds this in the app.',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        switch (kyc) {
          'approved' => StatusChip.forStatus('verified', 'Payments on'),
          'pending' => StatusChip.forStatus('pending', 'Being checked'),
          'rejected' => StatusChip.forStatus('rejected', 'Not approved'),
          _ => StatusChip.forStatus('pending', 'Set up'),
        },
        const Icon(Icons.chevron_right),
      ]),
      onTap: onEdit,
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
      appBar: AppBar(title: Text(S.of(context)('payouts'))),
      body: AsyncList<Json>(
        load: () async {
          final res = await context.read<Session>().api.get('temples/$templeId/settlements');
          return [for (final r in res['data'] as List) _map(r)];
        },
        empty: S.of(context)('no_payouts'),
        emptyIcon: Icons.receipt_long_outlined,
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
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: () => setState(() {
              _future = _load();
            }));
          }
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
    final tickets = [for (final t in (s['tickets'] as List? ?? const [])) _map(t)];
    final gifts = [for (final g in (s['donations'] as List? ?? const [])) _map(g)];
    final breakdown = _map(s['breakdown']);
    final theme = Theme.of(context);
    final paid = '${status['value']}' == 'paid';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        HeroPanel(
          gradient: paid ? Palette.tulsiGradient : Palette.kumkumGradient,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${s['reference']}', style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('${status['label']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('TO THE TEMPLE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            Text(rupees(s['net_paise']), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 32, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KeyValueRow('Seva days', '${s['period']}'),
            if (s['items'] != null) KeyValueRow('Covers', '${s['items']}') else KeyValueRow('Bookings', '${_n(s['bookings_count'])}'),
            for (final (k, label) in const [('bookings', 'Seva bookings'), ('tickets', 'Event tickets'), ('donations', 'Hundi gifts')])
              if (_n(_map(breakdown[k])['count']) > 0) KeyValueRow(label, '${_n(_map(breakdown[k])['count'])} · ${rupees(_map(breakdown[k])['amount_paise'])}'),
            const Divider(height: 18),
            KeyValueRow('Paid by devotees', rupees(s['gross_paise'])),
            KeyValueRow(
              'Platform fee',
              '${rupees(s['fee_paise'])} (${_percent(s['fee_percent'])}'
                  '${s['donation_fee_percent'] != null && _n(_map(breakdown['donations'])['count']) > 0 ? '; ${_percent(s['donation_fee_percent'])} on hundi' : ''})',
            ),
            KeyValueRow('To the temple', rupees(s['net_paise']), emphasis: true, valueColor: theme.colorScheme.primary),
            if (s['method_label'] != null || s['transaction_ref'] != null || s['paid_at'] != null) const Divider(height: 18),
            if (s['method_label'] != null) KeyValueRow('Paid by', '${s['method_label']}'),
            if (s['transaction_ref'] != null) KeyValueRow('Reference (UTR)', '${s['transaction_ref']}'),
            if (s['paid_at'] != null) KeyValueRow('Paid on', _date(s['paid_at'])),
            if (s['note'] != null) KeyValueRow('Note', '${s['note']}'),
            if (s['cancel_reason'] != null) KeyValueRow('Cancelled', '${s['cancel_reason']}'),
          ]),
        ),
        if (footer != null) footer!,
        if (bookings.isNotEmpty) ...[
          const SectionTitle('Bookings in this payout'),
          for (final b in bookings)
            _ItemTile(
              icon: Icons.local_fire_department_outlined,
              color: Palette.kumkum,
              title: '${b['devotee_name']} · ${_n(b['people'])} ${_n(b['people']) == 1 ? 'person' : 'people'}',
              subtitle: '${b['seva'] ?? ''} · ${b['booked_for']} · Ref ${b['reference']}',
              amount: rupees(b['amount_paise']),
            ),
        ],
        if (tickets.isNotEmpty) ...[
          const SectionTitle('Event tickets in this payout'),
          for (final t in tickets)
            _ItemTile(
              icon: Icons.celebration_outlined,
              color: Palette.saffron,
              title: '${t['devotee_name'] ?? 'Devotee'} · ${_n(t['people'])} ${_n(t['people']) == 1 ? 'person' : 'people'}',
              subtitle: '${t['event'] ?? ''} · ${t['occurs_on']} · Ref ${t['reference']}',
              amount: rupees(t['amount_paise']),
            ),
        ],
        if (gifts.isNotEmpty) ...[
          const SectionTitle('Hundi gifts in this payout'),
          for (final g in gifts)
            _ItemTile(
              icon: Icons.volunteer_activism_outlined,
              color: Palette.gold,
              title: '${g['donor'] ?? 'A devotee'}',
              subtitle: [
                if (_map(g['purpose'])['label'] != null) '${_map(g['purpose'])['label']}',
                if (g['paid_on'] != null) '${g['paid_on']}',
                'Ref ${g['reference']}',
              ].join(' · '),
              amount: rupees(g['amount_paise']),
            ),
        ],
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.amount});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(children: [
          IconBadge(icon, color: color, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ]),
          ),
          const SizedBox(width: 8),
          Text(amount, style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
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
          const InfoBanner(
            icon: Icons.account_balance_outlined,
            title: 'The trust\'s own account',
            body: 'Settlements are transferred here. A change is checked by the platform, usually by calling you, before money is sent to it.',
            color: Palette.sky,
          ),
          const SizedBox(height: 8),
          ApiTextField(controller: _name, label: 'Account holder name', field: 'account_name', error: _error, prefixIcon: Icons.person_outline),
          ApiTextField(
            controller: _number,
            label: 'Account number',
            field: 'account_number',
            error: _error,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.numbers,
            hint: masked == null ? null : 'On file: $masked · leave blank to keep',
          ),
          ApiTextField(controller: _ifsc, label: 'IFSC', field: 'ifsc', error: _error, hint: 'e.g. SBIN0001234', prefixIcon: Icons.tag),
          ApiTextField(controller: _bank, label: 'Bank and branch', field: 'bank_name', error: _error, prefixIcon: Icons.account_balance_outlined),
          const Padding(padding: EdgeInsets.fromLTRB(4, 8, 0, 8), child: Text('Or, or as well:')),
          ApiTextField(controller: _upi, label: 'UPI ID', field: 'upi_id', error: _error, hint: 'name@bank', prefixIcon: Icons.alternate_email),
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

/// How every rupee is shared: what the platform keeps and what reaches the
/// temple, on sevas and tickets and on hundi gifts, with a worked example.
class FeeShareCard extends StatelessWidget {
  const FeeShareCard({super.key, required this.feePercent, this.donationFeePercent, this.compact = false});

  final dynamic feePercent;
  final dynamic donationFeePercent;

  /// One line each, for the temple's home screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    double pct(dynamic v) => ((v as num?)?.toDouble() ?? 0).clamp(0, 100).toDouble();
    final fee = pct(feePercent);
    final gift = donationFeePercent == null ? null : pct(donationFeePercent);

    Widget row(String what, double keep) {
      final yours = 100 - keep;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(what, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(children: [
                Expanded(flex: (yours * 100).round().clamp(1, 10000), child: ColoredBox(color: theme.colorScheme.primary)),
                if (keep > 0) Expanded(flex: (keep * 100).round().clamp(1, 10000), child: ColoredBox(color: theme.colorScheme.secondary)),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            keep == 0
                ? 'Your temple receives all of it (${_percent(100)}). No platform fee.'
                : 'Your temple receives ${_percent(yours)} · ${Brand.name} keeps ${_percent(keep)}'
                    '${compact ? '' : '\nOn ${rupees(100000)}: ${rupees((100000 * yours / 100).round())} to the temple, ${rupees((100000 * keep / 100).round())} fee'}',
            style: theme.textTheme.bodySmall,
          ),
        ]),
      );
    }

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(Icons.pie_chart_outline, size: 30, color: Palette.gold),
          const SizedBox(width: 10),
          Text(s('your_share'), style: theme.textTheme.titleMedium),
        ]),
        const SizedBox(height: 12),
        row('Sevas and event tickets', fee),
        if (gift != null) row('Online hundi gifts', gift),
      ]),
    );
  }
}
