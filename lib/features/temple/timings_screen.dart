import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// Darshan, aarti and special timings: every day, or on some days (most
/// temples keep other hours on Saturday and Sunday).
class TimingsScreen extends StatefulWidget {
  const TimingsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<TimingsScreen> createState() => _TimingsScreenState();
}

class _TimingsScreenState extends State<TimingsScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context
        .read<Session>()
        .api
        .get('temples/${widget.templeId}/timings');
    return [
      for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()
    ];
  }

  Future<void> _edit([Json? row]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TimingForm(templeId: widget.templeId, row: row),
    );
    if (saved == true) _list.currentState?.reload();
  }

  /// Every-day timings become Mon–Fri, each with a Sat & Sun copy to edit.
  Future<void> _splitWeekend() async {
    final ok = await confirm(
      context,
      'Different timings on Sat & Sun?',
      body:
          'Every-day timings become Mon–Fri, and a Sat & Sun copy of each is added with the same hours. Then tap the Sat & Sun ones to change their hours.',
      action: 'Add',
    );
    if (!ok || !mounted) return;
    try {
      final res = await context
          .read<Session>()
          .api
          .post('temples/${widget.templeId}/timings/weekend', const {});
      if (!mounted) return;
      final n = (res['data'] as List?)?.length ?? 0;
      showMessage(context,
          '$n Sat & Sun ${n == 1 ? 'timing' : 'timings'} added. Tap them to set the weekend hours.');
      _list.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = {
      for (final o in context.watch<Session>().options.timingKinds)
        o.value: o.label
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Darshan timings')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Add timing')),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: 'No timings yet. Add when the temple opens for darshan.',
        header: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton.icon(
            onPressed: _splitWeekend,
            icon: const Icon(Icons.weekend_outlined),
            label: const Text('Different timings on Sat & Sun'),
          ),
        ),
        itemBuilder: (context, t, reload) => Card(
          child: ListTile(
            title: Text('${t['day_label'] ?? 'Every day'} · ${t['window']}'),
            subtitle: Text([
              kinds[t['kind']] ?? t['kind'],
              if (t['label'] != null) t['label'],
              if (t['notes'] != null) t['notes'],
            ].join(' · ')),
            onTap: () => _edit(t),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirm(context, 'Remove this timing?')) return;
                if (!context.mounted) return;
                try {
                  await context
                      .read<Session>()
                      .api
                      .delete('temples/${widget.templeId}/timings/${t['id']}');
                  reload();
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TimingForm extends StatefulWidget {
  const _TimingForm({required this.templeId, this.row});

  final int templeId;
  final Json? row;

  @override
  State<_TimingForm> createState() => _TimingFormState();
}

class _TimingFormState extends State<_TimingForm> {
  late String _kind = '${widget.row?['kind'] ?? 'darshan'}';
  late List<int> _days = [
    for (final d in (widget.row?['days'] as List?) ??
        (widget.row?['day_of_week'] != null
            ? [widget.row!['day_of_week']]
            : const []))
      if (d is num) d.toInt()
  ];
  late TimeOfDay? _opens = parseTime(widget.row?['opens_at']);
  late TimeOfDay? _closes = parseTime(widget.row?['closes_at']);
  late final _label = TextEditingController(text: widget.row?['label'] ?? '');
  late final _notes = TextEditingController(text: widget.row?['notes'] ?? '');
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    final body = {
      'kind': _kind,
      // Empty is every day.
      'days': _days,
      'opens_at': formatTime(_opens),
      'closes_at': formatTime(_closes),
      'label': _label.text.trim().isEmpty ? null : _label.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.row == null) {
        await api.post('temples/${widget.templeId}/timings', body);
      } else {
        await api.put(
            'temples/${widget.templeId}/timings/${widget.row!['id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<Session>().options;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.row == null ? 'Add timing' : 'Edit timing',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            OptionField(
                label: 'Kind',
                options: o.timingKinds,
                value: _kind,
                onChanged: (v) => setState(() => _kind = '$v')),
            const SizedBox(height: 12),
            DaysPicker(
                value: _days, onChanged: (v) => setState(() => _days = v)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TimeField(
                      label: 'Opens',
                      value: _opens,
                      onChanged: (t) => setState(() => _opens = t))),
              const SizedBox(width: 12),
              Expanded(
                  child: TimeField(
                      label: 'Closes',
                      value: _closes,
                      onChanged: (t) => setState(() => _closes = t))),
            ]),
            const SizedBox(height: 12),
            ApiTextField(
                controller: _label,
                label: 'Label',
                hint: 'e.g. Morning darshan, Suprabhatam',
                field: 'label',
                error: _error),
            ApiTextField(
                controller: _notes,
                label: 'Notes',
                field: 'notes',
                error: _error,
                maxLines: 2),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!.details,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : 'Save')),
          ],
        ),
      ),
    );
  }
}
