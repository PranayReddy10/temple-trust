import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/live_location.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import 'register_temple_screen.dart';

/// Find a temple already listed and ask to manage it.
class ClaimTempleScreen extends StatefulWidget {
  const ClaimTempleScreen({super.key});

  @override
  State<ClaimTempleScreen> createState() => _ClaimTempleScreenState();
}

class _ClaimTempleScreenState extends State<ClaimTempleScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v));
  }

  Future<void> _search(String v) async {
    if (v.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context
          .read<Session>()
          .api
          .get('claimable-temples', {'q': v.trim()});
      if (!mounted) return;
      setState(() => _results = [
            for (final r in res['data'] as List)
              (r as Map).cast<String, dynamic>()
          ]);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.details);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('ob_find_temple_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _q,
            autofocus: true,
            onChanged: _changed,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: s('ob_search_hint')),
          ),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          const SizedBox(height: 12),
          for (final t in _results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text('${t['name']}'),
                  subtitle: Text([t['deity'], t['city'], t['state']]
                      .where((e) => e != null)
                      .join(' · ')),
                  trailing: switch (t['claim_status']) {
                    'approved' => StatusChip(s('ob_you_manage')),
                    'pending' =>
                      StatusChip.forStatus('pending', s('ob_requested')),
                    _ => const Icon(Icons.chevron_right),
                  },
                  onTap: t['claim_status'] == 'approved' ||
                          t['claim_status'] == 'pending'
                      ? null
                      : () => _claim(t),
                ),
              ),
            ),
          if (_q.text.trim().length >= 2 && !_loading && _results.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s('ob_not_finding')),
                    const SizedBox(height: 8),
                    Text(s('ob_not_finding_body')),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterTempleScreen())),
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: Text(s('ob_register_this')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _claim(Map<String, dynamic> temple) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClaimSheet(temple: temple),
    );
    if (sent == true && mounted) {
      showMessage(context, S.of(context)('ob_request_sent'));
      Navigator.pop(context);
    }
  }
}

class _ClaimSheet extends StatefulWidget {
  const _ClaimSheet({required this.temple});

  final Map<String, dynamic> temple;

  @override
  State<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends State<_ClaimSheet> {
  final _note = TextEditingController();
  String _role = 'owner';
  LiveFix? _fix;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_fix == null) {
      showMessage(context, S.of(context)('ob_claim_need_location'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      await session.api.post('claims', {
        'temple_id': widget.temple['id'],
        'role': _role,
        'note': _note.text.trim(),
        ..._fix!.toFields()
      });
      await session.refresh();
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = context.watch<Session>().options.claimLevels;
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s('ob_manage_name', {'name': widget.temple['name']}),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            OptionField(
              label: s('ob_you_are'),
              options: levels.isEmpty
                  ? [
                      Option('owner', s('ob_level_owner')),
                      Option('manager', s('ob_level_manager'))
                    ]
                  : levels,
              value: _role,
              onChanged: (v) => setState(() => _role = '$v'),
            ),
            const SizedBox(height: 12),
            ApiTextField(
              controller: _note,
              label: s('ob_how_connected'),
              hint: s('ob_how_connected_hint'),
              field: 'note',
              error: _error,
              maxLines: 4,
              required: true,
            ),
            LiveLocationField(
              value: _fix,
              required: true,
              error: _error?.field('latitude') ??
                  _error?.field('location_accuracy'),
              onChanged: (f) => setState(() => _fix = f),
            ),
            const SizedBox(height: 12),
            if (_error != null &&
                _error!.field('note') == null &&
                _error!.field('latitude') == null &&
                _error!.field('location_accuracy') == null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!.details,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(_busy ? s('ob_sending') : s('ob_send_request'))),
          ],
        ),
      ),
    );
  }
}
