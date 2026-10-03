import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
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

  /// Which bookings: the successful ones (confirmed, and received at the
  /// temple) by default; the others on request.
  String _status = 'successful';
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

  void _setDay(DateTime? d) {
    setState(() {
      _day = d;
      _summary = null;
    });
    _list.currentState?.reload();
  }

  Future<List<Json>> _load() async {
    final q = _search.text.trim();
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/bookings', {
      'date': _day == null ? null : formatDate(_day!),
      'status': _status,
      if (q.length >= 2) 'q': q,
    });
    final summary = (res['summary'] as Map?)?.cast<String, dynamic>();
    if (mounted) setState(() => _summary = summary);
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Widget? _header(BuildContext context) {
    final s = S.of(context);
    final sm = _summary;
    if (_day == null || sm == null) return null;
    int n(String k) => (sm[k] as num?)?.toInt() ?? 0;
    final tickets = (sm['tickets'] as Map?) ?? const {};
    final gifts = (sm['donations'] as Map?) ?? const {};
    int c(Map m) => (m['count'] as num?)?.toInt() ?? 0;
    // Event tickets and hundi gifts the same day, for the full picture.
    final extras = [
      if (c(tickets) > 0) '${s('n_tickets', {'n': c(tickets)})} ${rupees(tickets['amount_paise'])}',
      if (c(gifts) > 0) '${s('n_gifts', {'n': c(gifts)})} ${rupees(gifts['amount_paise'])}',
      if (c(tickets) > 0 || c(gifts) > 0) '${s('in_all').toLowerCase()} ${rupees(sm['total_paise'])}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HeroPanel(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(prettyDate(_day!).toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Row(children: [
            _HeroFigure(s('booked'), '${n('bookings')}', s.people(n('people'))),
            _HeroFigure(s('received'), '${n('received')}', s('n_to_come', {'n': n('to_receive')})),
            _HeroFigure(s('amount_paid'), rupeesShort(sm['amount_paise']), null, flex: 3),
          ]),
          if (extras.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(extras.join(' · '), style: const TextStyle(color: Colors.white70, fontSize: 12))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text(s('seva_bookings')),
        actions: [
          IconButton(
            tooltip: s('find_booking_hint'),
            icon: const Icon(Icons.person_search_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const FindBookingScreen()));
              _list.currentState?.reload();
            },
          ),
          IconButton(
            tooltip: s('scan'),
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
          // The day: today, tomorrow, any day, or all days.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              children: [
                _DayChip(label: s('today'), selected: _day != null && formatDate(_day!) == formatDate(today), onTap: () => _setDay(today)),
                _DayChip(label: DateFormat.MMMd(Localizations.localeOf(context).toString()).format(today.add(const Duration(days: 1))), selected: _day != null && formatDate(_day!) == formatDate(today.add(const Duration(days: 1))), onTap: () => _setDay(today.add(const Duration(days: 1)))),
                _DayChip(label: s('all_days'), selected: _day == null, onTap: () => _setDay(null)),
                _DayChip(
                  label: _day == null || formatDate(_day!) == formatDate(today) || formatDate(_day!) == formatDate(today.add(const Duration(days: 1))) ? s('day') : formatDate(_day!),
                  icon: Icons.calendar_today_outlined,
                  selected: _day != null && formatDate(_day!) != formatDate(today) && formatDate(_day!) != formatDate(today.add(const Duration(days: 1))),
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _day ?? today, firstDate: DateTime(today.year - 2), lastDate: DateTime(today.year + 3));
                    if (d != null) _setDay(d);
                  },
                ),
              ],
            ),
          ),
          // Which bookings: successful by default; the rest on request.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              children: [
                for (final (value, label, icon) in [
                  ('successful', s('filter_successful'), Icons.task_alt),
                  ('expired', s('filter_expired'), Icons.person_off_outlined),
                  ('cancelled', s('filter_cancelled'), Icons.cancel_outlined),
                  ('pending_payment', s('filter_awaiting'), Icons.hourglass_top_outlined),
                  ('all', s('filter_all'), Icons.list_alt_outlined),
                ])
                  _DayChip(
                    label: label,
                    icon: icon,
                    selected: _status == value,
                    onTap: () {
                      setState(() => _status = value);
                      _list.currentState?.reload();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _searchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: s('search_bookings'),
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
              emptyIcon: Icons.confirmation_number_outlined,
              empty: _search.text.trim().length >= 2
                  ? 'No booking matches "${_search.text.trim()}"${_day == null ? '' : ' on this day'}.'
                  : (_day == null ? s('no_bookings_yet') : s('no_bookings_day')),
              itemBuilder: (context, b, reload) {
                final status = (b['status'] as Map?) ?? const {};
                final puja = (b['puja'] as Map?) ?? const {};
                final value = '${status['value']}';
                final people = (b['people'] as num?)?.toInt() ?? 1;
                final name = '${b['devotee_name'] ?? 'Devotee'}';
                return SoftCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)));
                    reload();
                  },
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    InitialsAvatar(name, color: value == 'verified' ? Palette.tulsi : (value == 'confirmed' ? Palette.kumkum : Palette.stone)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$name · ${people == 1 ? '1 person' : '$people people'}', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          [
                            '${puja['name'] ?? ''}',
                            '${b['booked_for']}${(b['slot'] as Map?)?['label'] != null ? ' ${(b['slot'] as Map)['label']}' : ''}',
                            if (b['amount'] != null) '${b['amount']}',
                          ].where((e) => e.isNotEmpty).join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          [
                            'Ref ${b['reference']}',
                            if (b['gotram'] != null) 'Gotram ${b['gotram']}',
                            if (b['nakshatram'] != null) 'Nakshatram ${b['nakshatram']}',
                            if (b['devotee_phone'] != null) '${b['devotee_phone']}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    StatusChip.forStatus(value, '${status['label'] ?? status['value']}'),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value, this.caption, {this.flex = 2});

  final String label;
  final String value;
  final String? caption;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.2))),
        if (caption != null) Text(caption!, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 16, color: selected ? Colors.white : theme.colorScheme.primary),
        selected: selected,
        showCheckmark: false,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 13),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
