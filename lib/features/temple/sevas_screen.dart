import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
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
    final res = await context
        .read<Session>()
        .api
        .get('temples/${widget.templeId}/sevas');
    return [
      for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()
    ];
  }

  Future<void> _edit([Json? row]) async {
    final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => SevaForm(templeId: widget.templeId, row: row)));
    if (saved == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('pujas_sevas'))),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: Text(s('tp_add_seva'))),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: s('tp_sevas_empty'),
        itemBuilder: (context, p, reload) {
          final fee = (p['fee'] as Map?) ?? const {};
          final app = (p['app_booking'] as Map?) ?? const {};
          return Card(
            child: ListTile(
              leading: p['image_url'] == null
                  ? const IconBadge(Icons.local_fire_department_outlined,
                      color: Palette.saffron)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network('${p['image_url']}',
                          width: 48, height: 48, fit: BoxFit.cover)),
              title: Text('${p['name']}'),
              subtitle: Text([
                '${fee['label'] ?? ''}',
                if (p['starts_at'] != null)
                  s('tp_at_time', {'time': showTime(p['starts_at'])}),
                if (app['enabled'] == true) s('tp_bookable_in_app'),
              ].where((e) => e.isNotEmpty).join(' · ')),
              trailing:
                  p['is_published'] == true ? null : StatusChip(s('tp_hidden')),
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
  Json get _booking =>
      (_r['booking'] as Map?)?.cast<String, dynamic>() ?? const {};
  Json get _app =>
      (_r['app_booking'] as Map?)?.cast<String, dynamic>() ?? const {};
  Json get _raw => (_r['raw'] as Map?)?.cast<String, dynamic>() ?? const {};

  late final Map<String, TextEditingController> _c = {
    'name': TextEditingController(text: _r['name'] ?? ''),
    'description': TextEditingController(text: _r['description'] ?? ''),
    'includes': TextEditingController(text: _r['includes'] ?? ''),
    'eligibility': TextEditingController(text: _r['eligibility'] ?? ''),
    'duration_minutes':
        TextEditingController(text: _r['duration_minutes']?.toString() ?? ''),
    'schedule_note': TextEditingController(text: _r['schedule_note'] ?? ''),
    'fee_amount': TextEditingController(text: _fee['amount']?.toString() ?? ''),
    'booking_url': TextEditingController(text: _booking['url'] ?? ''),
    'booking_note': TextEditingController(text: _booking['note'] ?? ''),
    'max_people_per_booking':
        TextEditingController(text: '${_app['max_people'] ?? 10}'),
    'booking_advance_days':
        TextEditingController(text: '${_app['advance_days'] ?? 30}'),
    'booking_capacity_per_day':
        TextEditingController(text: _app['capacity_per_day']?.toString() ?? ''),
    'booking_instructions':
        TextEditingController(text: _app['instructions'] ?? ''),
  };
  late String _kind = '${_r['kind'] ?? 'seva'}';
  late TimeOfDay? _startsAt = parseTime(_r['starts_at']);
  late bool _free = _fee['is_free'] == true;
  late bool _official = _raw['booking_is_official'] == true;
  late bool _appBooking = _raw['app_booking_enabled'] == true;
  late bool _perPerson = _app['fee_per_person'] ?? true;
  late bool _published = _r['is_published'] ?? true;

  /// Time slots, like show times: devotees pick one when they book.
  late final List<_Slot> _slots = [
    for (final r in (_raw['slots'] as List? ?? const []))
      _Slot.fromJson((r as Map).cast<String, dynamic>()),
  ];
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

  String? _t(String k) =>
      _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    final path = widget.row == null
        ? 'temples/${widget.templeId}/sevas'
        : 'temples/${widget.templeId}/sevas/${widget.row!['id']}';
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
        // Sent whole: what is sent replaces what was there. An empty value
        // clears them all.
        if (_slots.isEmpty) 'slots': null,
        for (final (i, slot) in _slots.indexed) ...slot.fields(i),
      }, files: [
        if (_image != null)
          UploadFile(
              field: 'image',
              filename: _image!.name,
              bytes: await _image!.readAsBytes()),
      ]);
      if (!mounted) return;
      final saved = (res['data'] as Map?) ?? const {};
      if (_appBooking &&
          ((saved['raw'] as Map?)?['app_booking_enabled'] != true)) {
        showMessage(context, S.of(context)('tp_saved_app_booking_needs_fee'));
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
    final s = S.of(context);
    if (!await confirm(context, s('tp_delete_seva_q'),
        body: s('tp_delete_seva_body'), action: s('tp_delete'))) {
      return;
    }
    if (!mounted) return;
    try {
      await context
          .read<Session>()
          .api
          .delete('temples/${widget.templeId}/sevas/${widget.row!['id']}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Fills the slots for a stretch of the day, e.g. 9:00 to 12:00 hourly,
  /// 15 people each.
  Future<void> _makeSlots() async {
    final s = S.of(context);
    var from = const TimeOfDay(hour: 9, minute: 0);
    var to = const TimeOfDay(hour: 12, minute: 0);
    final every = TextEditingController(text: '60');
    final people = TextEditingController(text: '15');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(s('tp_make_slots')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TimeField(
                label: s('tp_from'),
                value: from,
                onChanged: (t) => set(() => from = t ?? from)),
            const SizedBox(height: 8),
            TimeField(
                label: s('tp_to'),
                value: to,
                onChanged: (t) => set(() => to = t ?? to)),
            TextField(
                controller: every,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: s('tp_slot_minutes'))),
            TextField(
                controller: people,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: s('tp_people_per_slot'))),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(s('tp_make'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final step = int.tryParse(every.text.trim()) ?? 60;
    final cap = int.tryParse(people.text.trim());
    final end = to.hour * 60 + to.minute;
    if (step < 5) return;
    final made = <_Slot>[];
    for (var m = from.hour * 60 + from.minute;
        m + step <= end && made.length < 48;
        m += step) {
      made.add(_Slot(
          from: TimeOfDay(hour: m ~/ 60, minute: m % 60),
          to: TimeOfDay(hour: (m + step) ~/ 60, minute: (m + step) % 60),
          capacity: cap));
    }
    if (made.isEmpty) {
      if (mounted) showMessage(context, s('tp_no_slot_fits'));
      return;
    }
    setState(() => _slots
      ..clear()
      ..addAll(made));
  }

  Future<void> _editSlot(int? index) async {
    final s = S.of(context);
    final slot = index == null
        ? _Slot(from: const TimeOfDay(hour: 9, minute: 0))
        : _slots[index].copy();
    final cap = TextEditingController(text: slot.capacity?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(index == null ? s('tp_add_slot') : s('tp_edit_slot')),
          content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TimeField(
                      label: s('tp_starts'),
                      value: slot.from,
                      onChanged: (t) => set(() => slot.from = t ?? slot.from)),
                  const SizedBox(height: 8),
                  TimeField(
                      label: s('tp_ends_optional'),
                      value: slot.to,
                      onChanged: (t) => set(() => slot.to = t)),
                  TextField(
                      controller: cap,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: s('tp_people_a_day_limit'))),
                  const SizedBox(height: 12),
                  Text(s('tp_days_none_every')),
                  Wrap(spacing: 6, children: [
                    for (var d = 0; d < 7; d++)
                      FilterChip(
                        label: Text(s(_weekdays[d])),
                        selected: slot.days.contains(d),
                        onSelected: (on) => set(
                            () => on ? slot.days.add(d) : slot.days.remove(d)),
                      ),
                  ]),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s('tp_taking_bookings')),
                      value: slot.active,
                      onChanged: (v) => set(() => slot.active = v)),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(s('cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(s('tp_done'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    slot.capacity = int.tryParse(cap.text.trim());
    setState(() => index == null ? _slots.add(slot) : _slots[index] = slot);
  }

  Widget _f(String k, String label,
          {int lines = 1,
          TextInputType? type,
          bool required = false,
          String? hint}) =>
      ApiTextField(
          controller: _c[k]!,
          label: label,
          field: k,
          error: _error,
          maxLines: lines,
          keyboardType: type,
          required: required,
          hint: hint);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final o = context.watch<Session>().options;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.row == null ? s('tp_new_seva') : s('tp_edit_seva')),
        actions: [
          if (widget.row != null)
            IconButton(
                onPressed: _delete, icon: const Icon(Icons.delete_outline))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          OptionField(
              label: s('tp_kind'),
              options: o.pujaKinds,
              value: _kind,
              onChanged: (v) => setState(() => _kind = '$v')),
          const SizedBox(height: 12),
          _f('name', s('name'), required: true),
          _f('description', s('tp_description'), lines: 3),
          _f('includes', s('tp_includes'),
              lines: 2, hint: s('tp_includes_hint')),
          _f('eligibility', s('tp_eligibility'), lines: 2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: Text(_image?.name ??
                (_r['image_url'] == null
                    ? s('tp_add_image')
                    : s('tp_change_image'))),
            onTap: () async {
              final f = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1200);
              if (f != null) setState(() => _image = f);
            },
          ),
          SectionTitle(s('tp_when')),
          TimeField(
              label: s('tp_start_time'),
              value: _startsAt,
              onChanged: (t) => setState(() => _startsAt = t)),
          const SizedBox(height: 12),
          _f('duration_minutes', s('tp_duration_minutes'),
              type: TextInputType.number),
          _f('schedule_note', s('tp_schedule_note'),
              hint: s('tp_schedule_note_hint')),
          SectionTitle(s('tp_fee')),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s('tp_free')),
              value: _free,
              onChanged: (v) => setState(() => _free = v)),
          if (!_free)
            _f('fee_amount', s('tp_fee_rupees'),
                type: const TextInputType.numberWithOptions(decimal: true),
                hint: s('tp_fee_hint')),
          SectionTitle(s('tp_booking_outside')),
          _f('booking_url', s('tp_booking_link'), type: TextInputType.url),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('tp_official_site')),
            value: _official,
            onChanged: (v) => setState(() => _official = v),
          ),
          _f('booking_note', s('tp_booking_note'),
              hint: s('tp_booking_note_hint')),
          SectionTitle(s('tp_book_through_app')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('tp_can_book_in_app')),
            subtitle: Text(s('tp_can_book_hint')),
            value: _appBooking,
            onChanged: (v) => setState(() => _appBooking = v),
          ),
          if (_appBooking) ...[
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s('tp_fee_per_person')),
                value: _perPerson,
                onChanged: (v) => setState(() => _perPerson = v)),
            _f('max_people_per_booking', s('tp_max_people_booking'),
                type: TextInputType.number),
            _f('booking_advance_days', s('tp_advance_days'),
                type: TextInputType.number),
            _f('booking_capacity_per_day', s('tp_bookings_per_day'),
                type: TextInputType.number),
            SectionTitle(
              s('tp_time_slots'),
              trailing: TextButton.icon(
                  onPressed: _makeSlots,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(s('tp_make_slots'))),
            ),
            Text(s('tp_slots_hint')),
            const SizedBox(height: 8),
            for (final (i, slot) in _slots.indexed)
              Card(
                child: ListTile(
                  title: Text(
                      '${showTime(slot.from)}${slot.to == null ? '' : ' – ${showTime(slot.to)}'}${slot.active ? '' : ' (${s('tp_off')})'}'),
                  subtitle: Text([
                    slot.capacity == null
                        ? s('tp_no_limit')
                        : s('tp_n_people_a_day', {'n': slot.capacity}),
                    slot.days.isEmpty || slot.days.length == 7
                        ? s('tp_every_day_lc')
                        : [for (final d in slot.days..sort()) s(_weekdays[d])]
                            .join(', '),
                  ].join(' · ')),
                  onTap: () => _editSlot(i),
                  trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _slots.removeAt(i))),
                ),
              ),
            OutlinedButton.icon(
                onPressed: () => _editSlot(null),
                icon: const Icon(Icons.add),
                label: Text(s('tp_add_slot'))),
            const SizedBox(height: 12),
            _f('booking_instructions', s('tp_instructions'),
                lines: 3, hint: s('tp_instructions_hint')),
          ],
          SectionTitle(s('tp_publishing')),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s('tp_published')),
              value: _published,
              onChanged: (v) => setState(() => _published = v)),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? s('saving') : s('save'))),
        ],
      ),
    );
  }
}

/// Keys of the short weekday names, 0 (Sunday) to 6.
const _weekdays = [
  'tp_sun',
  'tp_mon',
  'tp_tue',
  'tp_wed',
  'tp_thu',
  'tp_fri',
  'tp_sat'
];

/// One time slot as the form edits it; days are 0 (Sunday) to 6.
class _Slot {
  _Slot(
      {required this.from,
      this.to,
      this.capacity,
      List<int>? days,
      this.active = true,
      this.id})
      : days = days ?? [];

  factory _Slot.fromJson(Json j) => _Slot(
        id: (j['id'] as num?)?.toInt(),
        from: parseTime(j['starts_at']) ?? const TimeOfDay(hour: 9, minute: 0),
        to: parseTime(j['ends_at']),
        capacity: (j['capacity'] as num?)?.toInt(),
        days: [
          for (final d in (j['days'] as List? ?? const [])) (d as num).toInt()
        ],
        active: j['is_active'] != false,
      );

  final int? id;
  TimeOfDay from;
  TimeOfDay? to;
  int? capacity;
  final List<int> days;
  bool active;

  _Slot copy() => _Slot(
      id: id,
      from: from,
      to: to,
      capacity: capacity,
      days: [...days],
      active: active);

  /// As multipart fields: slots[0][starts_at] and so on.
  Map<String, dynamic> fields(int i) => {
        if (id != null) 'slots[$i][id]': id,
        'slots[$i][starts_at]': formatTime(from),
        if (to != null) 'slots[$i][ends_at]': formatTime(to),
        if (capacity != null) 'slots[$i][capacity]': capacity,
        for (final (k, d) in days.indexed) 'slots[$i][days][$k]': d,
        'slots[$i][is_active]': active,
      };
}
