import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// Days the temple is closed or keeps different hours.
class ClosuresScreen extends StatefulWidget {
  const ClosuresScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<ClosuresScreen> createState() => _ClosuresScreenState();
}

class _ClosuresScreenState extends State<ClosuresScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/closures');
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Future<void> _edit([Json? row]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClosureForm(templeId: widget.templeId, row: row),
    );
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Closures')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add closure')),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: 'No closures. Add eclipses, renovations or days with changed hours so devotees are not turned away at the gate.',
        itemBuilder: (context, c, reload) {
          final dates = c['starts_on'] == c['ends_on'] ? '${c['starts_on']}' : '${c['starts_on']} → ${c['ends_on']}';
          return Card(
            child: ListTile(
              title: Text('${c['reason']}'),
              subtitle: Text([
                dates,
                c['is_full_day'] == true ? 'Closed all day' : 'Open ${showTime(c['opens_at']) ?? '?'} – ${showTime(c['closes_at']) ?? '?'}',
                if (c['notes'] != null) c['notes'],
              ].join(' · ')),
              leading: c['is_active_today'] == true ? const StatusChip('Today') : null,
              onTap: () => _edit(c),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (!await confirm(context, 'Remove this closure?')) return;
                  if (!context.mounted) return;
                  try {
                    await context.read<Session>().api.delete('temples/${widget.templeId}/closures/${c['id']}');
                    reload();
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClosureForm extends StatefulWidget {
  const _ClosureForm({required this.templeId, this.row});

  final int templeId;
  final Json? row;

  @override
  State<_ClosureForm> createState() => _ClosureFormState();
}

class _ClosureFormState extends State<_ClosureForm> {
  late final _reason = TextEditingController(text: widget.row?['reason'] ?? '');
  late final _notes = TextEditingController(text: widget.row?['notes'] ?? '');
  late DateTime? _from = DateTime.tryParse('${widget.row?['starts_on']}') ?? DateTime.now();
  late DateTime? _to = widget.row == null ? null : DateTime.tryParse('${widget.row?['ends_on']}');
  late bool _fullDay = widget.row?['is_full_day'] ?? true;
  late TimeOfDay? _opens = parseTime(widget.row?['opens_at']);
  late TimeOfDay? _closes = parseTime(widget.row?['closes_at']);
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _reason.dispose();
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
      'reason': _reason.text.trim(),
      'starts_on': _from == null ? null : formatDate(_from!),
      'ends_on': _to == null ? null : formatDate(_to!),
      'is_full_day': _fullDay,
      'opens_at': _fullDay ? null : formatTime(_opens),
      'closes_at': _fullDay ? null : formatTime(_closes),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.row == null) {
        await api.post('temples/${widget.templeId}/closures', body);
      } else {
        await api.put('temples/${widget.templeId}/closures/${widget.row!['id']}', body);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.row == null ? 'Add closure' : 'Edit closure', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ApiTextField(controller: _reason, label: 'Reason', hint: 'e.g. Chandra grahanam', field: 'reason', error: _error, required: true),
            Row(children: [
              Expanded(child: DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
              const SizedBox(width: 12),
              Expanded(child: DateField(label: 'To (optional)', value: _to, clearable: true, onChanged: (d) => setState(() => _to = d))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Closed all day'),
              value: _fullDay,
              onChanged: (v) => setState(() => _fullDay = v),
            ),
            if (!_fullDay)
              Row(children: [
                Expanded(child: TimeField(label: 'Opens', value: _opens, onChanged: (t) => setState(() => _opens = t))),
                const SizedBox(width: 12),
                Expanded(child: TimeField(label: 'Closes', value: _closes, onChanged: (t) => setState(() => _closes = t))),
              ]),
            const SizedBox(height: 12),
            ApiTextField(controller: _notes, label: 'Notes', field: 'notes', error: _error, maxLines: 2),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!.details, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
          ],
        ),
      ),
    );
  }
}
