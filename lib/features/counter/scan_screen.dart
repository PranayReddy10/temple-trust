import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';

typedef Json = Map<String, dynamic>;

/// At the counter: scan a devotee's seva booking and receive them, or look
/// at the passport they show. A code from another temple reads as unknown.
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
    final showingResult = _booking != null || _passportData != null || _error != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan at counter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Seva booking'), icon: Icon(Icons.confirmation_number_outlined)),
              ButtonSegment(value: true, label: Text('Passport'), icon: Icon(Icons.badge_outlined)),
            ],
            selected: {_passport},
            onSelectionChanged: (s) {
              _clear();
              setState(() => _passport = s.first);
            },
          ),
          const SizedBox(height: 12),
          if (!showingResult)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 300,
                child: MobileScanner(
                  controller: _scanner,
                  onDetect: (capture) {
                    final v = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
                    if (v != null) _lookup(v);
                  },
                  errorBuilder: (context, error, child) => const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Camera unavailable. Type the reference below.'))),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!showingResult)
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(hintText: _passport ? 'Passport code' : 'Booking reference'),
                  onSubmitted: _lookup,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _busy ? null : () => _lookup(_typed.text), child: const Text('Check')),
            ]),
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null) _ResultCard(color: Theme.of(context).colorScheme.error, icon: Icons.error_outline, title: 'Not found', body: _error!),
          if (_booking != null) _bookingCard(_booking!),
          if (_passportData != null) _passportCard(_passportData!),
          if (showingResult) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan next')),
          ],
        ],
      ),
    );
  }

  Widget _bookingCard(Json b) {
    final puja = (b['puja'] as Map?) ?? const {};
    final temple = (b['temple'] as Map?) ?? const {};
    final status = '${(b['status'] as Map?)?['value']}';
    final (color, icon, title) = switch (_outcome) {
      'verified' => (const Color(0xFF2E7D55), Icons.check_circle, 'Received — welcome them in'),
      'already_verified' => (const Color(0xFFC9A227), Icons.warning_amber_rounded, 'Already used${b['verified_at'] != null ? ' at ${b['verified_at']}' : ''}'),
      _ => status == 'confirmed'
          ? (Theme.of(context).colorScheme.primary, Icons.confirmation_number_outlined, 'Valid booking')
          : (Theme.of(context).colorScheme.error, Icons.block, '${(b['status'] as Map?)?['label']}'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ResultCard(
        color: color,
        icon: icon,
        title: title,
        body: [
          '${puja['name']} · ${temple['name']}',
          'For ${b['booked_for']}${(b['slot'] as Map?)?['label'] != null ? ' · ${(b['slot'] as Map)['label']}' : ''} · ${b['people']} ${b['people'] == 1 ? 'person' : 'people'}',
          '${b['devotee_name'] ?? ''}${b['devotee_phone'] != null ? ' · ${b['devotee_phone']}' : ''}',
          if (b['gotram'] != null) 'Gotram: ${b['gotram']}',
          if (b['nakshatram'] != null) 'Nakshatram: ${b['nakshatram']}',
          if (b['note'] != null) 'Note: ${b['note']}',
          '${b['amount'] ?? ''} · Ref ${b['reference']}',
        ].join('\n'),
      ),
      if (_outcome == null && status == 'confirmed')
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: FilledButton.icon(onPressed: _busy ? null : _verify, icon: const Icon(Icons.how_to_reg), label: const Text('Mark as received')),
        ),
    ]);
  }

  Widget _passportCard(Json p) {
    // Only temples this account manages can stamp a passport; a super admin
    // without a claim of their own has none here.
    final temples = context.read<Session>().account?.temples ?? const [];
    final chosen = _visitTemple ?? (temples.isEmpty ? null : temples.first.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _ResultCard(
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.badge_outlined,
        title: '${p['name'] ?? 'Devotee'}',
        body: [
          for (final e in p.entries)
            if (e.value is String || e.value is num) '${e.key.replaceAll('_', ' ')}: ${e.value}',
        ].join('\n'),
      ),
      if (_visitMessage != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _ResultCard(color: const Color(0xFF2E7D55), icon: Icons.verified, title: 'Stamped', body: _visitMessage!),
        )
      else if (temples.isNotEmpty) ...[
        const SizedBox(height: 12),
        if (temples.length > 1)
          DropdownButtonFormField<int>(
            initialValue: chosen,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Visited which temple'),
            items: [for (final t in temples) DropdownMenuItem(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _visitTemple = v),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy || chosen == null ? null : () => _markVisited(chosen),
          icon: const Icon(Icons.approval),
          label: Text(temples.length == 1 ? 'Mark visited today at ${temples.first.name}' : 'Mark visited today'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Only while they are here with you. The stamp goes into their passport, verified by the temple.', textAlign: TextAlign.center),
        ),
      ],
    ]);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.color, required this.icon, required this.title, required this.body});

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: color, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color))),
          ]),
          const SizedBox(height: 10),
          Text(body),
        ]),
      ),
    );
  }
}
