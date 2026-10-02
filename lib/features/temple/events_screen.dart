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
          final reg = (e['registration'] as Map?) ?? const {};
          final summary = (e['registrations_summary'] as Map?) ?? const {};
          final joinable = reg['enabled'] == true;
          final tertiary = Theme.of(context).colorScheme.tertiary;
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ListTile(
                leading: e['image_url'] == null
                    ? Icon(e['type'] == 'bhajan' ? Icons.music_note_outlined : Icons.celebration_outlined)
                    : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${e['image_url']}', width: 48, height: 48, fit: BoxFit.cover)),
                title: Text('${e['title']}'),
                subtitle: Text([
                  '${e['date_label']}',
                  if (e['group_name'] != null) '${e['group_name']}',
                  if (e['review_note'] != null) 'Editor: ${e['review_note']}',
                ].join('\n')),
                isThreeLine: e['review_note'] != null || e['group_name'] != null,
                trailing: StatusChip.forStatus('${status['value']}', '${status['label'] ?? status['value']}'),
                onTap: () => _edit(e),
              ),
              if (e['type'] == 'bhajan' || e['recurrence'] == 'weekly' || joinable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                  child: Row(children: [
                    Expanded(
                      child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        if (e['type'] == 'bhajan') StatusChip('Bhajan', color: tertiary),
                        if (e['recurrence'] == 'weekly') const StatusChip('Every week'),
                        if (joinable) StatusChip(reg['is_paid'] == true ? '${reg['price'] ?? 'Paid'}' : 'Free', color: const Color(0xFF2E7D55)),
                        if (joinable) Text('${summary['going'] ?? reg['going'] ?? 0} going${summary['next_on'] != null ? ' on ${summary['next_on']}' : ''}', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                    if (joinable)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EventAttendeesScreen(templeId: widget.templeId, eventId: (e['id'] as num).toInt(), title: '${e['title']}')),
                        ),
                        icon: const Icon(Icons.groups_outlined, size: 18),
                        label: const Text('Attendees'),
                      ),
                  ]),
                ),
            ]),
          );
        },
      ),
    );
  }
}

/// Who is coming to an event on one of its dates: "I'll join" and tickets,
/// with what they paid.
class EventAttendeesScreen extends StatefulWidget {
  const EventAttendeesScreen({super.key, required this.templeId, required this.eventId, required this.title});

  final int templeId;
  final int eventId;
  final String title;

  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen> {
  String? _date;
  late Future<Json> _future = _load();

  Future<Json> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/events/${widget.eventId}/registrations', {'date': _date});
    return (res['data'] as Map).cast<String, dynamic>();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final d = snap.data!;
          final date = '${d['date']}';
          final dates = <String>{date, for (final x in (d['dates'] as List? ?? const [])) '$x'}.toList()..sort();
          final s = (d['summary'] as Map?) ?? const {};
          final items = [for (final r in (d['items'] as List? ?? const [])) (r as Map).cast<String, dynamic>()];
          final theme = Theme.of(context);
          int n(String k) => (s[k] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: date,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Date'),
                  items: [for (final x in dates) DropdownMenuItem(value: x, child: Text(x))],
                  onChanged: (v) {
                    if (v == null || v == date) return;
                    _date = v;
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Figure('Registrations', '${n('registrations')}', caption: '${n('received')} received')),
                        Expanded(
                          child: Figure('People', '${n('people')}', caption: s['capacity'] == null ? 'no limit' : 'of ${s['capacity']}'),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Figure('Amount', '${s['amount'] ?? rupees(s['amount_paise'])}', emphasis: true, color: theme.colorScheme.primary)),
                      ]),
                    ]),
                  ),
                ),
                const SectionTitle('Who is coming'),
                if (items.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Text('No one has joined for this date yet.', textAlign: TextAlign.center)),
                for (final r in items)
                  Card(
                    child: ListTile(
                      title: Text('${r['devotee_name'] ?? 'Devotee'} · ${r['people']} ${r['people'] == 1 ? 'person' : 'people'}'),
                      subtitle: Text([
                        if (r['devotee_phone'] != null) '${r['devotee_phone']}',
                        '${r['amount'] ?? rupees(r['amount_paise'])}',
                        'Ref ${r['reference']}',
                      ].join(' · ')),
                      trailing: StatusChip.forStatus('${(r['status'] as Map?)?['value']}', '${(r['status'] as Map?)?['label'] ?? ''}'),
                    ),
                  ),
              ],
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
  Json get _reg => (widget.row?['registration'] as Map?)?.cast<String, dynamic>() ?? const {};
  late final _groupName = TextEditingController(text: widget.row?['group_name'] as String? ?? '');
  late final _price = TextEditingController(text: _priceText(widget.row?['ticket_price']));
  late final _capacity = TextEditingController(text: _reg['capacity']?.toString() ?? '');
  late final _maxPeople = TextEditingController(text: '${_reg['max_people'] ?? 10}');
  late final _songs = TextEditingController(text: widget.row?['songs_text'] as String? ?? '');
  late final bool _hadSongs = _songs.text.trim().isNotEmpty;
  late bool _openToAll = widget.row?['open_to_all'] ?? true;
  late bool _registration = _reg['enabled'] == true;
  XFile? _image;
  bool _removeImage = false;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_title, _description, _groupName, _price, _capacity, _maxPeople, _songs]) {
      c.dispose();
    }
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
        'group_name': _v(_groupName),
        'open_to_all': _openToAll,
        'registration_enabled': _registration,
        // Kept as they are while the switch is off, so turning it back on
        // finds the same price and limits.
        'ticket_price': _v(_price) ?? 0,
        'capacity': _v(_capacity),
        'max_people_per_registration': _v(_maxPeople) ?? 10,
        'songs': _v(_songs),
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

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete this event?', body: 'If devotees have tickets for it, set it back to draft instead.')) return;
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
    // Older servers may not list bhajan gatherings yet.
    final types = [...o.eventTypes, if (!o.eventTypes.any((t) => t.value == 'bhajan')) const Option('bhajan', 'Bhajan gathering')];
    final weekday = _from == null ? null : _weekdayNames[_from!.weekday - 1];
    final existingImage = widget.row?['image_url'];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.row == null ? 'New event' : 'Edit event'),
        actions: [if (widget.row != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          OptionField(label: 'Type', options: types, value: _type, onChanged: (v) => setState(() => _type = '$v')),
          const SizedBox(height: 12),
          ApiTextField(controller: _title, label: 'Title', field: 'title', error: _error, required: true),
          ApiTextField(controller: _description, label: 'Description', field: 'description', error: _error, maxLines: 5),
          ApiTextField(
            controller: _groupName,
            label: _type == 'bhajan' ? 'Bhajan mandali' : 'Group or organiser (optional)',
            field: 'group_name',
            error: _error,
            hint: 'e.g. Sri Rama Bhajan Mandali',
          ),
          Row(children: [
            Expanded(child: DateField(label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
            const SizedBox(width: 12),
            Expanded(child: DateField(label: _recurrence == 'weekly' ? 'Last date (optional)' : 'To (optional)', value: _to, clearable: true, onChanged: (d) => setState(() => _to = d))),
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
            options: const [Option('none', 'One-off'), Option('weekly', 'Every week'), Option('yearly', 'Every year on these dates')],
            value: _recurrence,
            onChanged: (v) => setState(() => _recurrence = '$v'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _recurrence == 'weekly'
                  ? 'Repeats every ${weekday ?? 'week'}, the weekday of the start date. The last date ends the series; leave it empty to keep it going.'
                  : 'Festivals on the lunar calendar move each year; add those as separate entries.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open to all'),
            subtitle: const Text('Anyone may come, not only members.'),
            value: _openToAll,
            onChanged: (v) => setState(() => _openToAll = v),
          ),
          const SectionTitle('Joining in the app'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Devotees can join in the app'),
            subtitle: const Text('Free: they tap "I\'ll join". With a price: they buy tickets, shown at the counter as a QR code.'),
            value: _registration,
            onChanged: (v) => setState(() => _registration = v),
          ),
          if (_registration) ...[
            ApiTextField(
              controller: _price,
              label: 'Ticket price per person (₹)',
              field: 'ticket_price',
              error: _error,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              hint: 'Empty or 0 for free',
            ),
            ApiTextField(controller: _capacity, label: 'People per date (empty for no limit)', field: 'capacity', error: _error, keyboardType: TextInputType.number),
            ApiTextField(controller: _maxPeople, label: 'Most people per registration', field: 'max_people_per_registration', error: _error, keyboardType: TextInputType.number),
          ],
          if (_type == 'bhajan' || _hadSongs) ...[
            const SectionTitle('Songs'),
            ApiTextField(controller: _songs, label: 'Songs', field: 'songs', error: _error, maxLines: 8, hint: 'One song per line'),
          ],
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

const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The editor's rupee price as typed: 100 rather than 100.0, empty when free.
String _priceText(dynamic v) {
  final p = (v as num?)?.toDouble() ?? 0;
  if (p <= 0) return '';
  return p == p.roundToDouble() ? p.toInt().toString() : p.toStringAsFixed(2);
}
