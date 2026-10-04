import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'find_booking_screen.dart';

typedef Json = Map<String, dynamic>;

/// At the counter: scan a devotee's seva booking or event ticket and receive
/// them, or look at the passport they show. A code from another temple
/// reads as unknown.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _typed = TextEditingController();
  bool _passport = false;
  bool _busy = false;
  bool _torch = false;
  String? _code;
  Json? _booking;
  Json? _passportData;
  String? _outcome;
  String? _error;

  /// After a passport scan: the temple the stamp is for, and the answer.
  int? _visitTemple;
  String? _visitMessage;

  @override
  void dispose() {
    _scanner.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _code = null;
        _booking = null;
        _passportData = null;
        _outcome = null;
        _error = null;
        _visitMessage = null;
        _typed.clear();
      });

  Future<void> _lookup(String code) async {
    if (_busy || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
      _booking = null;
      _passportData = null;
      _code = code.trim();
    });
    final api = context.read<Session>().api;
    try {
      if (_passport) {
        final res = await api.post('passports/lookup', {'code': _code});
        setState(() => _passportData = (res['data'] as Map).cast<String, dynamic>());
      } else {
        final res = await api.post('bookings/scan', {'code': _code});
        final data = (res['data'] as Map).cast<String, dynamic>();
        setState(() {
          _booking = (data['booking'] as Map).cast<String, dynamic>();
          _outcome = data['outcome'] as String?;
        });
      }
    } on ApiException catch (e) {
      setState(() => _error = e.details);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final res = await context.read<Session>().api.post('bookings/verify', {'code': _code});
      final data = (res['data'] as Map).cast<String, dynamic>();
      setState(() {
        _booking = (data['booking'] as Map).cast<String, dynamic>();
        _outcome = data['outcome'] as String?;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.details);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stamps the scanned passport for today at one of this account's temples.
  Future<void> _markVisited(int templeId) async {
    setState(() => _busy = true);
    try {
      final res = await context.read<Session>().api.post('passports/visit', {'code': _code, 'temple_id': templeId});
      setState(() => _visitMessage = '${(res['data'] as Map)['message']}');
    } on ApiException catch (e) {
      setState(() => _error = e.details);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final showingResult = _booking != null || _passportData != null || _error != null;
    return Scaffold(
      appBar: AppBar(title: Text(s('scan_at_counter'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s('seva_event_ticket')), icon: const Icon(Icons.confirmation_number_outlined)),
              ButtonSegment(value: true, label: Text(s('passport')), icon: const Icon(Icons.badge_outlined)),
            ],
            selected: {_passport},
            onSelectionChanged: (v) {
              _clear();
              setState(() => _passport = v.first);
            },
          ),
          const SizedBox(height: 14),
          if (!showingResult) ...[
            _ScannerFrame(
              controller: _scanner,
              torch: _torch,
              onTorch: () {
                _scanner.toggleTorch();
                setState(() => _torch = !_torch);
              },
              onDetect: (capture) {
                final v = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                if (v != null) _lookup(v);
              },
              hint: s('point_camera'),
              unavailable: s('camera_unavailable'),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s('or_type'), style: theme.textTheme.bodySmall)),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(hintText: _passport ? s('passport_code') : s('booking_reference'), prefixIcon: const Icon(Icons.keyboard_alt_outlined)),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : () => _lookup(_typed.text), child: Text(s('check'))),
            ]),
            // No phone at the counter: find the booking by number or name.
            if (!_passport)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindBookingScreen())),
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(s('no_phone_find')),
                ),
              ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null) _ResultCard(color: theme.colorScheme.error, icon: Icons.error_outline, title: s('not_found'), body: _error!),
          if (_error != null && !_passport)
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FindBookingScreen(initialQuery: _typed.text.trim().isEmpty ? null : _typed.text.trim()))),
              icon: const Icon(Icons.person_search_outlined),
              label: Text(s('search_instead')),
            ),
          if (_booking != null) _bookingCard(_booking!),
          if (_passportData != null) _passportCard(_passportData!),
          if (showingResult) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Palette.saffron),
              onPressed: _clear,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(s('scan_next')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bookingCard(Json b) {
    final s = S.of(context);
    final puja = (b['puja'] as Map?) ?? const {};
    final event = (b['event'] as Map?) ?? const {};
    final isTicket = b['kind'] == 'event';
    final temple = (b['temple'] as Map?) ?? const {};
    final status = '${(b['status'] as Map?)?['value']}';
    final (color, icon, title) = switch (_outcome) {
      'verified' => (Palette.tulsi, Icons.check_circle, s('received_welcome')),
      'already_verified' => (const Color(0xFFB08A10), Icons.warning_amber_rounded, '${s('already_used')}${b['verified_at'] != null ? ' · ${b['verified_at']}' : ''}'),
      _ => status == 'confirmed'
          ? (Theme.of(context).colorScheme.primary, Icons.confirmation_number_outlined, isTicket ? s('valid_ticket') : s('valid_booking'))
          : (Theme.of(context).colorScheme.error, Icons.block, '${(b['status'] as Map?)?['label']}'),
    };
    final rows = <(IconData, String)>[
      (isTicket ? Icons.celebration_outlined : Icons.local_fire_department_outlined, '${isTicket ? event['title'] : puja['name']} · ${temple['name']}'),
      if (isTicket && event['group_name'] != null) (Icons.groups_outlined, '${event['group_name']}'),
      (Icons.calendar_month_outlined, '${isTicket ? (b['occurs_on'] ?? b['booked_for']) : b['booked_for']}${(b['slot'] as Map?)?['label'] != null ? ' · ${(b['slot'] as Map)['label']}' : ''} · ${s.people((b['people'] as num?)?.toInt() ?? 1)}'),
      (Icons.person_outline, '${b['devotee_name'] ?? ''}${b['devotee_phone'] != null ? ' · ${b['devotee_phone']}' : ''}'),
      if (b['gotram'] != null) (Icons.family_restroom_outlined, 'Gotram: ${b['gotram']}'),
      if (b['nakshatram'] != null) (Icons.star_outline, 'Nakshatram: ${b['nakshatram']}'),
      if (b['note'] != null) (Icons.notes_outlined, '${b['note']}'),
      (Icons.currency_rupee, '${b['amount'] ?? ''} · ${isTicket ? 'Ticket' : 'Ref'} ${b['reference']}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ResultCard(color: color, icon: icon, title: title, rows: rows),
      if (_outcome == null && status == 'confirmed')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Palette.tulsi, padding: const EdgeInsets.symmetric(vertical: 18)),
            onPressed: _busy ? null : _verify,
            icon: const Icon(Icons.how_to_reg),
            label: Text(s('mark_received')),
          ),
        ),
    ]);
  }

  Widget _passportCard(Json p) {
    final s = S.of(context);
    // Only temples this account manages can stamp a passport; a super admin
    // without a claim of their own has none here.
    final temples = context.read<Session>().account?.temples ?? const [];
    final chosen = _visitTemple ?? (temples.isEmpty ? null : temples.first.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ResultCard(
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.badge_outlined,
        title: '${p['name'] ?? 'Devotee'}',
        rows: [
          for (final e in p.entries)
            if ((e.value is String || e.value is num) && e.key != 'name') (Icons.circle, '${e.key.replaceAll('_', ' ')}: ${e.value}'),
        ],
      ),
      if (_visitMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _ResultCard(color: Palette.tulsi, icon: Icons.verified, title: s('stamped'), body: _visitMessage!),
        )
      else if (temples.isNotEmpty) ...[
        const SizedBox(height: 12),
        if (temples.length > 1)
          DropdownButtonFormField<int>(
            initialValue: chosen,
            isExpanded: true,
            decoration: InputDecoration(labelText: s('visited_which')),
            items: [for (final t in temples) DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _visitTemple = v),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Palette.tulsi, padding: const EdgeInsets.symmetric(vertical: 18)),
          onPressed: _busy || chosen == null ? null : () => _markVisited(chosen),
          icon: const Icon(Icons.approval),
          label: Text(temples.length == 1 ? '${s('mark_visited')} · ${temples.first.name}' : s('mark_visited'), overflow: TextOverflow.ellipsis),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Only while they are here with you. The stamp goes into their passport, verified by the temple.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ]);
  }
}

/// The camera, framed with corner marks and a torch button.
class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame({required this.controller, required this.onDetect, required this.torch, required this.onTorch, required this.hint, required this.unavailable});

  final MobileScannerController controller;
  final void Function(BarcodeCapture) onDetect;
  final bool torch;
  final VoidCallback onTorch;
  final String hint;
  final String unavailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: TrustStyle.of(context).cardShadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 320,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(color: Palette.ebony),
            MobileScanner(
              controller: controller,
              onDetect: onDetect,
              errorBuilder: (context, error, child) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
                    const SizedBox(height: 12),
                    Text(unavailable, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  ]),
                ),
              ),
            ),
            Center(child: CustomPaint(size: const Size(210, 210), painter: _CornersPainter(color: Palette.goldLight))),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                child: Text(hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.45), foregroundColor: torch ? Palette.goldLight : Colors.white),
                onPressed: onTorch,
                icon: Icon(torch ? Icons.flashlight_on : Icons.flashlight_off),
                tooltip: 'Torch',
              ),
            ),
            if (theme.brightness == Brightness.light) const SizedBox.shrink(),
          ]),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 28.0;
    const r = 18.0;
    final w = size.width;
    final h = size.height;
    void corner(Offset o, double sx, double sy) {
      final path = Path()
        ..moveTo(o.dx, o.dy + sy * len)
        ..lineTo(o.dx, o.dy + sy * r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + sx * r, o.dy)
        ..lineTo(o.dx + sx * len, o.dy);
      canvas.drawPath(path, paint);
    }

    corner(Offset.zero, 1, 1);
    corner(Offset(w, 0), -1, 1);
    corner(Offset(0, h), 1, -1);
    corner(Offset(w, h), -1, -1);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.color, required this.icon, required this.title, this.body, this.rows = const []});

  final Color color;
  final IconData icon;
  final String title;
  final String? body;
  final List<(IconData, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      border: color,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: color,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontFamily: TrustTheme.serif, fontSize: 18, fontWeight: FontWeight.w600))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (body != null) Text(body!, style: theme.textTheme.bodyMedium),
            for (final (i, r) in rows.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(r.$1, size: r.$1 == Icons.circle ? 8 : 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.$2, style: i == 0 ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
