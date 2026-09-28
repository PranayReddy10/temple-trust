import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// Pujas, sevas and prasadam, with fees and in-app booking.
class SevasScreen extends StatefulWidget {
  const SevasScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<SevasScreen> createState() => _SevasScreenState();
}

class _SevasScreenState extends State<SevasScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/sevas');
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Future<void> _edit([Json? row]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SevaForm(templeId: widget.templeId, row: row)));
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pujas & sevas')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add seva')),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: 'No pujas or sevas yet. Add what the temple offers, with its fee, so devotees know before they come.',
        itemBuilder: (context, p, reload) {
          final fee = (p['fee'] as Map?) ?? const {};
          final app = (p['app_booking'] as Map?) ?? const {};
          return Card(
            child: ListTile(
              leading: p['image_url'] == null
                  ? const Icon(Icons.local_fire_department_outlined)
                  : ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${p['image_url']}', width: 48, height: 48, fit: BoxFit.cover)),
              title: Text('${p['name']}'),
              subtitle: Text([
                '${fee['label'] ?? ''}',
                if (p['starts_at'] != null) 'at ${p['starts_at']}',
                if (app['enabled'] == true) 'Bookable in app',
              ].where((e) => e.isNotEmpty).join(' · ')),
              trailing: p['is_published'] == true ? null : const StatusChip('Hidden'),
              onTap: () => _edit(p),
            ),
          );
        },
      ),
    );
  }
}

class SevaForm extends StatefulWidget {
  const SevaForm({super.key, required this.templeId, this.row});

  final int templeId;
  final Json? row;

  @override
  State<SevaForm> createState() => _SevaFormState();
}

class _SevaFormState extends State<SevaForm> {
  Json get _r => widget.row ?? const {};
  Json get _fee => (_r['fee'] as Map?)?.cast<String, dynamic>() ?? const {};
  Json get _booking => (_r['booking'] as Map?)?.cast<String, dynamic>() ?? const {};
  Json get _app => (_r['app_booking'] as Map?)?.cast<String, dynamic>() ?? const {};
  Json get _raw => (_r['raw'] as Map?)?.cast<String, dynamic>() ?? const {};

  late final Map<String, TextEditingController> _c = {
    'name': TextEditingController(text: _r['name'] ?? ''),
    'description': TextEditingController(text: _r['description'] ?? ''),
    'includes': TextEditingController(text: _r['includes'] ?? ''),
    'eligibility': TextEditingController(text: _r['eligibility'] ?? ''),
    'duration_minutes': TextEditingController(text: _r['duration_minutes']?.toString() ?? ''),
    'schedule_note': TextEditingController(text: _r['schedule_note'] ?? ''),
    'fee_amount': TextEditingController(text: _fee['amount']?.toString() ?? ''),
    'booking_url': TextEditingController(text: _booking['url'] ?? ''),
    'booking_note': TextEditingController(text: _booking['note'] ?? ''),
    'max_people_per_booking': TextEditingController(text: '${_app['max_people'] ?? 10}'),
    'booking_advance_days': TextEditingController(text: '${_app['advance_days'] ?? 30}'),
    'booking_capacity_per_day': TextEditingController(text: _app['capacity_per_day']?.toString() ?? ''),
    'booking_instructions': TextEditingController(text: _app['instructions'] ?? ''),
  };
  late String _kind = '${_r['kind'] ?? 'seva'}';
  late TimeOfDay? _startsAt = parseTime(_r['starts_at']);
  late bool _free = _fee['is_free'] == true;
  late bool _official = _raw['booking_is_official'] == true;
  late bool _appBooking = _raw['app_booking_enabled'] == true;
  late bool _perPerson = _app['fee_per_person'] ?? true;
  late bool _published = _r['is_published'] ?? true;
  XFile? _image;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(String k) => _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    final path = widget.row == null ? 'temples/${widget.templeId}/sevas' : 'temples/${widget.templeId}/sevas/${widget.row!['id']}';
    try {
      final res = await api.multipart(path, fields: {
        'kind': _kind,
        for (final k in _c.keys) k: _t(k),
        'fee_amount': _free ? null : _t('fee_amount'),
        'starts_at': formatTime(_startsAt),
        'is_free': _free,
        'booking_is_official': _official,
        'app_booking_enabled': _appBooking,
        'fee_per_person': _perPerson,
        'is_published': _published,
      }, files: [
        if (_image != null) UploadFile(field: 'image', filename: _image!.name, bytes: await _image!.readAsBytes()),
      ]);
      if (!mounted) return;
      final saved = (res['data'] as Map?) ?? const {};
      if (_appBooking && ((saved['raw'] as Map?)?['app_booking_enabled'] != true)) {
        showMessage(context, 'Saved. App booking needs a fee, or the seva marked free.');
      }
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
    if (!await confirm(context, 'Delete this seva?', body: 'If devotees have booked it, hide it instead by turning Published off.')) return;
    if (!mounted) return;
    try {
      await context.read<Session>().api.delete('temples/${widget.templeId}/sevas/${widget.row!['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _f(String k, String label, {int lines = 1, TextInputType? type, bool required = false, String? hint}) =>
      ApiTextField(controller: _c[k]!, label: label, field: k, error: _error, maxLines: lines, keyboardType: type, required: required, hint: hint);

  @override
  Widget build(BuildContext context) {
    final o = context.watch<Session>().options;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.row == null ? 'New seva' : 'Edit seva'),
        actions: [if (widget.row != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          OptionField(label: 'Kind', options: o.pujaKinds, value: _kind, onChanged: (v) => setState(() => _kind = '$v')),
          const SizedBox(height: 12),
          _f('name', 'Name', required: true),
          _f('description', 'Description', lines: 3),
          _f('includes', 'Includes', lines: 2, hint: 'e.g. Archana, prasadam, kumkum'),
          _f('eligibility', 'Who may take part', lines: 2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: Text(_image?.name ?? (_r['image_url'] == null ? 'Add image' : 'Change image')),
            onTap: () async {
              final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
              if (f != null) setState(() => _image = f);
            },
          ),
          const SectionTitle('When'),
          TimeField(label: 'Start time', value: _startsAt, onChanged: (t) => setState(() => _startsAt = t)),
          const SizedBox(height: 12),
          _f('duration_minutes', 'Duration (minutes)', type: TextInputType.number),
          _f('schedule_note', 'Schedule note', hint: 'e.g. Every Saturday; on Ekadashi'),
          const SectionTitle('Fee'),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Free'), value: _free, onChanged: (v) => setState(() => _free = v)),
          if (!_free) _f('fee_amount', 'Fee (₹)', type: const TextInputType.numberWithOptions(decimal: true), hint: 'Leave empty if not known — it will not show as free'),
          const SectionTitle('Booking outside the app'),
          _f('booking_url', 'Booking link', type: TextInputType.url),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('This is the temple\'s official booking site'),
            value: _official,
            onChanged: (v) => setState(() => _official = v),
          ),
          _f('booking_note', 'Booking note', hint: 'e.g. Book at the counter by 7 am'),
          const SectionTitle('Book through the app'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Devotees can book in the app'),
            subtitle: const Text('Needs a fee or Free. Paid bookings are confirmed only when the payment clears.'),
            value: _appBooking,
            onChanged: (v) => setState(() => _appBooking = v),
          ),
          if (_appBooking) ...[
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Fee is per person'), value: _perPerson, onChanged: (v) => setState(() => _perPerson = v)),
            _f('max_people_per_booking', 'Most people per booking', type: TextInputType.number),
            _f('booking_advance_days', 'Bookable up to (days ahead)', type: TextInputType.number),
            _f('booking_capacity_per_day', 'Bookings per day (empty for no limit)', type: TextInputType.number),
            _f('booking_instructions', 'Instructions for devotees', lines: 3, hint: 'e.g. Come to counter 3 with this code 30 minutes early'),
          ],
          const SectionTitle('Publishing'),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Published'), value: _published, onChanged: (v) => setState(() => _published = v)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
        ],
      ),
    );
  }
}
