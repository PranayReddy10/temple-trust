import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';
import '../counter/scan_screen.dart';

typedef Json = Map<String, dynamic>;

/// Seva bookings for one temple, a day at a time.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, required this.templeId, this.todayOnly = false, this.initialDay});

  final int templeId;
  final bool todayOnly;

  /// Opens on this day, as from the finance screen.
  final DateTime? initialDay;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late DateTime? _day = widget.initialDay ?? (widget.todayOnly ? DateTime.now() : null);
  final _list = GlobalKey<AsyncListState<Json>>();

  /// The day's totals, sent with the list when a day is chosen.
  Json? _summary;

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/bookings', {'date': _day == null ? null : formatDate(_day!)});
    final summary = (res['summary'] as Map?)?.cast<String, dynamic>();
    if (mounted) setState(() => _summary = summary);
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Widget? _header(BuildContext context) {
    final s = _summary;
    if (_day == null || s == null) return null;
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Figure('Booked', '${n('bookings')}', caption: '${n('people')} people')),
            Expanded(child: Figure('Received', '${n('received')}', caption: '${n('to_receive')} to come')),
            Expanded(child: Figure('Amount paid', rupees(s['amount_paise']), color: theme.colorScheme.primary)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seva bookings'),
        actions: [
          IconButton(
            tooltip: 'Scan a booking',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
              _list.currentState?.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(children: [
              Expanded(
                child: DateField(
                  label: 'Day',
                  value: _day,
                  clearable: true,
                  onChanged: (d) {
                    setState(() {
                      _day = d;
                      _summary = null;
                    });
                    _list.currentState?.reload();
                  },
                ),
              ),
            ]),
          ),
          Expanded(
            child: AsyncList<Json>(
              key: _list,
              load: _load,
              header: _header(context),
              empty: _day == null ? 'No bookings yet.' : 'No bookings for this day.',
              itemBuilder: (context, b, reload) {
                final status = (b['status'] as Map?) ?? const {};
                final puja = (b['puja'] as Map?) ?? const {};
                return Card(
                  child: ListTile(
                    title: Text('${b['devotee_name'] ?? 'Devotee'} · ${b['people']} ${b['people'] == 1 ? 'person' : 'people'}'),
                    subtitle: Text([
                      '${puja['name'] ?? ''}',
                      '${b['booked_for']}${(b['slot'] as Map?)?['label'] != null ? ' ${(b['slot'] as Map)['label']}' : ''}',
                      'Ref ${b['reference']}',
                      if (b['amount'] != null) '${b['amount']}',
                      if (b['gotram'] != null) 'Gotram ${b['gotram']}',
                      if (b['nakshatram'] != null) 'Nakshatram ${b['nakshatram']}',
                      if (b['devotee_phone'] != null) '${b['devotee_phone']}',
                    ].join(' · ')),
                    trailing: StatusChip.forStatus('${status['value']}', '${status['label'] ?? status['value']}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
