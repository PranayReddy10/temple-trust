import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../temple/booking_detail_screen.dart';

typedef Json = Map<String, dynamic>;

/// A devotee at the counter without their phone: find the seva booking or
/// event ticket by mobile number, booking reference or name, open it, and
/// mark them received. Today's bookings come first.
class FindBookingScreen extends StatefulWidget {
  const FindBookingScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<FindBookingScreen> createState() => _FindBookingScreenState();
}

class _FindBookingScreenState extends State<FindBookingScreen> {
  late final _q = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<Json>? _results;
  String? _searched;
  bool _busy = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().length >= 3) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 3) {
      setState(() {
        _results = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res =
          await context.read<Session>().api.get('bookings/search', {'q': q});
      if (!mounted || _q.text.trim() != q) return;
      setState(() {
        _results = [
          for (final r in (res['data'] as List? ?? const []))
            (r as Map).cast<String, dynamic>()
        ];
        _searched = q;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(Json b) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => BookingDetailScreen(booking: b)));
    if (mounted) _search();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final today = formatDate(DateTime.now());
    final results = _results;
    return Scaffold(
      appBar: AppBar(title: Text(s('find_booking'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _q,
            autofocus: widget.initialQuery == null,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: s('mn_find_hint'),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _q.clear();
                        _search();
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            s('mn_find_intro'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _error != null
              ? ErrorView(error: _error!, onRetry: _search)
              : results == null
                  ? const SizedBox.shrink()
                  : results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(s('mn_find_no_match', {'q': _searched}),
                              textAlign: TextAlign.center),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final b = results[i];
                            final status = (b['status'] as Map?) ?? const {};
                            final isTicket =
                                b['kind'] == 'event' || b['event'] is Map;
                            final event = (b['event'] as Map?) ?? const {};
                            final puja = (b['puja'] as Map?) ?? const {};
                            final what =
                                isTicket ? event['title'] : puja['name'];
                            final day = '${b['booked_for'] ?? ''}';
                            final slot = (b['slot'] as Map?)?['label'];
                            final expired = b['expired_at'] != null;
                            final name =
                                '${b['devotee_name'] ?? s('mn_devotee')}';
                            final people = (b['people'] as num?)?.toInt() ?? 1;
                            return Card(
                              child: ListTile(
                                leading: InitialsAvatar(name,
                                    color: day == today
                                        ? theme.colorScheme.primary
                                        : Palette.stone),
                                title: Text('$name · ${s.people(people)}'),
                                subtitle: Text([
                                  '${what ?? (isTicket ? s('mn_event') : s('mn_seva'))}',
                                  '${day == today ? s('today') : day}${slot != null ? ' $slot' : ''}',
                                  s('mn_ref', {'ref': b['reference']}),
                                  if (b['devotee_phone'] != null)
                                    '${b['devotee_phone']}',
                                ].join(' · ')),
                                trailing: StatusChip.forStatus(
                                    expired ? 'expired' : '${status['value']}',
                                    expired
                                        ? s('mn_expired')
                                        : '${status['label'] ?? status['value']}'),
                                onTap: () => _open(b),
                              ),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
