import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// One seva booking, drawn as the ticket the devotee holds in their app, so
/// the counter sees exactly what the devotee is showing — and can mark them
/// received from here.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.booking});

  final Json booking;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Json _b = widget.booking;
  bool _busy = false;

  Future<void> _markReceived() async {
    // The scan code, or the reference when it was found by search.
    final code = (_b['code'] as String?) ?? (_b['reference'] as String?);
    if (code == null) return;
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s('mn_mark_received_q')),
        content: Text(s('mn_mark_received_body', {
          'name': _b['devotee_name'] ?? s('mn_the_devotee'),
          'n': _b['people'],
          'what': (_b['puja'] as Map?)?['name'] ??
              (_b['event'] as Map?)?['title'] ??
              s('mn_the_seva')
        })),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(s('mn_not_yet'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(s('received'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = await context
          .read<Session>()
          .api
          .post('bookings/verify', {'code': code});
      final data = (res['data'] as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _b = (data['booking'] as Map).cast<String, dynamic>());
      showMessage(
          context,
          data['outcome'] == 'already_verified'
              ? s('mn_already_received')
              : s('mn_marked_received'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final b = _b;
    // A seva booking carries its puja; an event ticket its event.
    final event = (b['event'] as Map?) ?? const {};
    final puja = (b['puja'] as Map?) ??
        {'name': event['title'], 'starts_at': event['starts_at']};
    final temple = (b['temple'] as Map?) ?? const {};
    final status = (b['status'] as Map?) ?? const {};
    final value = '${status['value']}';
    final day = DateTime.tryParse('${b['booked_for']}');
    final expired = b['expired_at'] != null;
    final verified = b['verified_at'] != null || value == 'verified';
    final confirmed = value == 'confirmed';
    final valid = confirmed && !expired;
    final color = expired
        ? Palette.stone
        : switch (value) {
            'confirmed' => Palette.tulsi,
            'verified' => Palette.tulsi,
            'cancelled' || 'refunded' => Palette.kumkum,
            _ => Palette.saffron,
          };
    final label = expired ? s('mn_expired') : '${status['label'] ?? value}';
    final slot = (b['slot'] as Map?)?['label'] as String?;
    final time = slot ?? showTime(puja['starts_at']);
    final verifiedAt = DateTime.tryParse('${b['verified_at']}')?.toLocal();

    Widget fact(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: Palette.saffron),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6))),
                    Text(text, style: theme.textTheme.bodyMedium),
                  ]),
            ),
          ]),
        );

    Widget cell(String title, String text, {String? sub}) => Expanded(
          child: Column(children: [
            Text(title,
                style: const TextStyle(
                    color: Palette.stone,
                    letterSpacing: 2,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Palette.deep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.15)),
            if (sub != null)
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.stone, fontSize: 11)),
          ]),
        );
    final rule = Container(
        width: 1, height: 44, color: Palette.gold.withValues(alpha: 0.5));

    return Scaffold(
      appBar: AppBar(title: Text('${puja['name'] ?? s('mn_booking')}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // The ticket, as the devotee sees it.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Palette.ivory,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: verified ? Palette.tulsi : Palette.gold, width: 3),
            ),
            child: Column(children: [
              Text(Brand.name.toUpperCase(),
                  style: const TextStyle(
                      color: Palette.deep,
                      letterSpacing: 3,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${puja['name'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Palette.deep, fontFamily: 'serif', fontSize: 22)),
              if (temple['name'] != null)
                Text('${temple['name']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Palette.stone, fontSize: 13)),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                    color: Palette.saffron.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  cell(s('mn_date').toUpperCase(),
                      day == null ? '—' : DateFormat('d MMM').format(day),
                      sub: day == null ? null : DateFormat('EEEE').format(day)),
                  rule,
                  cell(s('mn_time').toUpperCase(), time ?? s('mn_any_time'),
                      sub: time == null ? s('mn_during_darshan') : null),
                  rule,
                  cell(s('people').toUpperCase(), '${b['people'] ?? 1}'),
                ]),
              ),
              const SizedBox(height: 12),
              Row(
                  children: List.generate(
                      30,
                      (_) => Expanded(
                          child: Container(
                              height: 1.5,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              color: Palette.gold.withValues(alpha: 0.7))))),
              const SizedBox(height: 14),
              Text(s('mn_reference').toUpperCase(),
                  style: const TextStyle(
                      color: Palette.stone,
                      letterSpacing: 2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: '${b['reference']}'));
                  showMessage(context, s('mn_ref_copied'));
                },
                child: Text('${b['reference']}',
                    style: const TextStyle(
                        color: Palette.deep,
                        fontFamily: 'monospace',
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12)),
              ),
              if (valid && day != null) ...[
                const SizedBox(height: 8),
                Text(
                    s('mn_valid_on',
                        {'date': DateFormat('EEE, d MMM yyyy').format(day)}),
                    style: const TextStyle(
                        color: Palette.stone,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
          if (confirmed && !expired) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Palette.tulsi,
                  padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: _busy ? null : _markReceived,
              icon: const Icon(Icons.how_to_reg),
              label: Text(_busy ? s('mn_marking') : s('mn_mark_received')),
            ),
          ],
          const SizedBox(height: 18),
          fact(
              Icons.person,
              s('mn_in_name_of'),
              [
                b['devotee_name'] ?? s('mn_devotee'),
                if (b['gotram'] != null) s('mn_gotram', {'v': b['gotram']}),
                if (b['nakshatram'] != null) '${b['nakshatram']}'
              ].join(' · ')),
          if (b['devotee_phone'] != null)
            fact(Icons.phone, s('mn_phone'), '${b['devotee_phone']}'),
          if (day != null)
            fact(Icons.calendar_month, s('day'),
                '${DateFormat('EEEE, d MMMM yyyy').format(day)}${time != null ? ' · $time' : ''}'),
          if (verifiedAt != null)
            fact(Icons.verified, s('mn_received_at_temple'),
                DateFormat('d MMM yyyy, h:mm a').format(verifiedAt)),
          fact(Icons.groups, s('people'), '${b['people'] ?? 1}'),
          if (b['note'] != null)
            fact(Icons.notes, s('mn_devotee_note'), '${b['note']}'),
          fact(
            Icons.currency_rupee,
            s('mn_paid'),
            b['is_free'] == true
                ? s('mn_free')
                : '${b['amount'] ?? rupees(b['amount_paise'])}${(b['payment'] as Map?)?['status'] != null ? ' · ${(b['payment'] as Map)['status']}' : ''}',
          ),
          if (b['created_at'] != null)
            fact(
                Icons.schedule,
                s('mn_booked_on'),
                DateFormat('d MMM yyyy, h:mm a')
                    .format(DateTime.parse('${b['created_at']}').toLocal())),
          if (b['cancel_reason'] != null)
            fact(Icons.cancel_outlined, s('filter_cancelled'),
                '${b['cancel_reason']}'),
          if (puja['instructions'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Palette.saffron.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Palette.saffron.withValues(alpha: 0.3))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline,
                    color: Palette.saffron, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        s('mn_devotee_told', {'text': puja['instructions']}),
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.4))),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
