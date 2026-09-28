import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// Festivals, programs and announcements. Publishing may wait for the
/// editors' review, depending on the temple's verification level.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/events');
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Future<void> _edit([Json? row]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EventForm(templeId: widget.templeId, row: row)));
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events & festivals')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add event')),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: 'No events yet. Add festivals, programs and announcements devotees should know about.',
        itemBuilder: (context, e, reload) {
          final status = (e['status'] as Map?) ?? const {};
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: e['image_url'] == null
                  ? const Icon(Icons.celebration_outlined)
                  : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${e['image_url']}', width: 48, height: 48, fit: BoxFit.cover)),
              title: Text('${e['title']}'),
              subtitle: Text([
                '${e['date_label']}',
                if (e['review_note'] != null) 'Editor: ${e['review_note']}',
              ].join('\n')),
              isThreeLine: e['review_note'] != null,
              trailing: StatusChip.forStatus('${status['value']}', '${status['label'] ?? status['value']}'),
              onTap: () => _edit(e),
            ),
          );
        },
      ),
    );
  }
}

class EventForm extends StatefulWidget {
  const EventForm({super.key, required this.templeId, this.row});

  final int templeId;
  final Json? row;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  late final _title = TextEditingController(text: widget.row?['title'] ?? '');
  late final _description = TextEditingController(text: widget.row?['description'] ?? '');
  late String _type = '${widget.row?['type'] ?? 'festival'}';
  late DateTime? _from = DateTime.tryParse('${widget.row?['starts_on']}') ?? DateTime.now();
  late DateTime? _to = widget.row == null ? null : DateTime.tryParse('${widget.row?['ends_on']}');
  late bool _allDay = widget.row?['is_all_day'] ?? true;
  late TimeOfDay? _startsAt = parseTime(widget.row?['starts_at']);
  late TimeOfDay? _endsAt = parseTime(widget.row?['ends_at']);
  late String _recurrence = '${widget.row?['recurrence'] ?? 'none'}';
  late bool _publish = ((widget.row?['status'] as Map?)?['value'] ?? 'published') != 'draft';
  XFile? _image;
  bool _removeImage = false;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    final path = widget.row == null ? 'temples/${widget.templeId}/events' : 'temples/${widget.templeId}/events/${widget.row!['id']}';
    try {
      final res = await api.multipart(path, fields: {
        'type': _type,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'starts_on': _from == null ? null : formatDate(_from!),
        'ends_on': _to == null ? null : formatDate(_to!),
        'is_all_day': _allDay,
        'starts_at': _allDay ? null : formatTime(_startsAt),
        'ends_at': _allDay ? null : formatTime(_endsAt),
        'recurrence': _recurrence,
        'status': _publish ? 'published' : 'draft',
        'remove_image': _removeImage,
      }, files: [
        if (_image != null) UploadFile(field: 'image', filename: _image!.name, bytes: await _image!.readAsBytes()),
      ]);
      if (!mounted) return;
      final status = ((res['data'] as Map?)?['status'] as Map?)?['value'];
      if (status == 'pending_review') showMessage(context, 'Sent to the editors. It goes live once they approve it.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this event?')) return;
    if (!mounted) return;
    try {
      await context.read<Session>().api.delete('temples/${widget.templeId}/events/${widget.row!['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = context.watch<Session>().options;
    final existingImage = widget.row?['image_url'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.row == null ? 'New event' : 'Edit event'),
        actions: [if (widget.row != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          OptionField(label: 'Type', options: o.eventTypes, value: _type, onChanged: (v) => setState(() => _type = '$v')),
          const SizedBox(height: 12),
          ApiTextField(controller: _title, label: 'Title', field: 'title', error: _error, required: true),
          ApiTextField(controller: _description, label: 'Description', field: 'description', error: _error, maxLines: 5),
          Row(children: [
            Expanded(child: DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 12),
            Expanded(child: DateField(label: 'To (optional)', value: _to, clearable: true, onChanged: (d) => setState(() => _to = d))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('All day'), value: _allDay, onChanged: (v) => setState(() => _allDay = v)),
          if (!_allDay)
            Row(children: [
              Expanded(child: TimeField(label: 'Starts', value: _startsAt, onChanged: (t) => setState(() => _startsAt = t))),
              const SizedBox(width: 12),
              Expanded(child: TimeField(label: 'Ends', value: _endsAt, onChanged: (t) => setState(() => _endsAt = t))),
            ]),
          const SizedBox(height: 12),
          OptionField(
            label: 'Repeats',
            options: const [Option('none', 'One-off'), Option('yearly', 'Every year on these dates')],
            value: _recurrence,
            onChanged: (v) => setState(() => _recurrence = '$v'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text('Festivals on the lunar calendar move each year; add those as separate entries.', style: TextStyle(fontSize: 12)),
          ),
          const SectionTitle('Image'),
          Row(children: [
            if (_image != null)
              Expanded(child: Text(_image!.name, overflow: TextOverflow.ellipsis))
            else if (existingImage != null && !_removeImage)
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('$existingImage', height: 120, fit: BoxFit.cover)))
            else
              const Expanded(child: Text('No image')),
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () async {
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
                if (f != null) setState(() => _image = f);
              },
            ),
            if (_image != null || (existingImage != null && !_removeImage))
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() {
                    _image = null;
                    _removeImage = existingImage != null;
                  })),
          ]),
          const SectionTitle('Publishing'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publish'),
            subtitle: const Text('Unless your temple is verified, the editors review it before devotees see it.'),
            value: _publish,
            onChanged: (v) => setState(() => _publish = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
        ],
      ),
    );
  }
}
