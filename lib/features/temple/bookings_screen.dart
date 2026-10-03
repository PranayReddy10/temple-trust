import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';
import 'booking_detail_screen.dart';
import '../counter/find_booking_screen.dart';
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

  /// Name, phone number (or part of it) or reference; searched on the server.
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
    _debounce = Timer(const Duration(milliseconds: 400), () => _list.currentState?.reload());
  }

  Future<List<Json>> _load() async {
    final q = _search.text.trim();
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/bookings', {
      'date': _day == null ? null : formatDate(_day!),
      if (q.length >= 2) 'q': q,
    });
    final summary = (res['summary'] as Map?)?.cast<String, dynamic>();
    if (mounted) setState(() => _summary = summary);
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Widget? _header(BuildContext context) {
    final s = _summary;
    if (_day == null || s == null) return null;
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    final theme = Theme.of(context);
    final tickets = (s['tickets'] as Map?) ?? const {};
    final gifts = (s['donations'] as Map?) ?? const {};
    int c(Map m) => (m['count'] as num?)?.toInt() ?? 0;
    // Event tickets and hundi gifts the same day, for the full picture.
    final extras = [
      if (c(tickets) > 0) '${c(tickets)} event tickets ${rupees(tickets['amount_paise'])}',
      if (c(gifts) > 0) '${c(gifts)} hundi gifts ${rupees(gifts['amount_paise'])}',
      if (c(tickets) > 0 || c(gifts) > 0) 'in all ${rupees(s['total_paise'])}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Figure('Booked', '${n('bookings')}', caption: '${n('people')} people')),
              Expanded(child: Figure('Received', '${n('received')}', caption: '${n('to_receive')} to come')),
              Expanded(child: Figure('Amount paid', rupees(s['amount_paise']), color: theme.colorScheme.primary)),
            ]),
            if (extras.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(extras.join(' · '), style: theme.textTheme.bodySmall)),
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
            tooltip: 'Find by mobile number, reference or name',
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const FindBookingScreen()));
              _list.currentState?.reload();
            },
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name, mobile number or reference',
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
          ),
          Expanded(
            child: AsyncList<Json>(
              key: _list,
              load: _load,
              header: _header(context),
              empty: _search.text.trim().length >= 2
                  ? 'No booking matches "${_search.text.trim()}"${_day == null ? '' : ' on this day'}.'
                  : (_day == null ? 'No bookings yet.' : 'No bookings for this day.'),
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
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)));
                      reload();
                    },
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
