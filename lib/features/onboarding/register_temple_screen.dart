import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/live_location.dart';
import '../../core/photo_crop.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

/// Register a temple that is not on the app yet.
///
/// It goes to the editors' review queue; once approved the temple is listed
/// and this account's request to manage it is confirmed separately.
class RegisterTempleScreen extends StatefulWidget {
  const RegisterTempleScreen({super.key});

  @override
  State<RegisterTempleScreen> createState() => _RegisterTempleScreenState();
}

class _RegisterTempleScreenState extends State<RegisterTempleScreen> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in [
      'name',
      'alternate_names',
      'deity_name',
      'address',
      'city',
      'district',
      'pincode',
      'description',
      'history',
      'built_period',
      'festivals',
      'timings_note',
      'contact_phone',
      'official_website',
      'submitter_note',
    ])
      k: TextEditingController(),
  };
  dynamic _deityId;
  dynamic _stateId;
  String _role = 'trustee';
  TimeOfDay? _opens;
  TimeOfDay? _closes;
  final List<CroppedPhoto> _photos = [];
  LiveFix? _fix;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final max = context.read<Session>().options.maxRegistrationPhotos;
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2400);
    if (picked.isEmpty) return;
    // Each framed at 4:3, the shape devotees see every temple photo in.
    for (final (i, f) in picked.take(max - _photos.length).toList().indexed) {
      if (!mounted) return;
      final s = S.of(context);
      final c = await cropPhoto(context, f,
          title: picked.length == 1
              ? s('ob_crop_photo')
              : s('ob_crop_photo_n', {'i': i + 1, 'n': picked.length}));
      if (c != null) setState(() => _photos.add(c));
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_fix == null) {
      showMessage(context, S.of(context)('ob_need_location'));
      return;
    }
    if (_photos.isEmpty) {
      showMessage(context, S.of(context)('ob_need_photo'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      final files = <UploadFile>[
        for (var i = 0; i < _photos.length; i++)
          UploadFile(
              field: 'photos[$i]',
              filename: _photos[i].filename,
              bytes: _photos[i].bytes),
      ];
      await session.api.multipart('registrations',
          fields: {
            for (final e in _c.entries)
              if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
            'deity_id': _deityId,
            'state_id': _stateId,
            'submitter_role': _role,
            'opens_at': formatTime(_opens),
            'closes_at': formatTime(_closes),
            ..._fix!.toFields(),
          },
          files: files);
      await session.refresh();
      if (!mounted) return;
      showMessage(context, S.of(context)('ob_registration_sent'));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label,
          {bool required = false,
          int lines = 1,
          String? hint,
          TextInputType? type}) =>
      ApiTextField(
          controller: _c[key]!,
          label: label,
          field: key,
          error: _error,
          required: required,
          maxLines: lines,
          hint: hint,
          keyboardType: type);

  @override
  Widget build(BuildContext context) {
    final options = context.watch<Session>().options;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('ob_register_title'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(s('ob_register_intro')),
            SectionTitle(s('ob_the_temple')),
            _field('name', s('ob_temple_name'), required: true),
            _field('alternate_names', s('ob_other_names'),
                hint: s('ob_other_names_hint')),
            OptionField(
                label: s('ob_main_deity'),
                options: options.deities,
                value: _deityId,
                allowNone: true,
                noneLabel: s('ob_not_in_list'),
                onChanged: (v) => setState(() => _deityId = v)),
            const SizedBox(height: 12),
            if (_deityId == null) _field('deity_name', s('ob_deity_name')),
            _field('description', s('ob_about_temple'),
                required: true, lines: 4, hint: s('ob_about_hint')),
            _field('history', s('ob_history'), lines: 3),
            _field('built_period', s('ob_built_in'),
                hint: s('ob_built_in_hint')),
            _field('festivals', s('ob_main_festivals'), lines: 2),
            SectionTitle(s('ob_where')),
            _field('address', s('ob_address'), lines: 2),
            _field('city', s('ob_city'), required: true),
            _field('district', s('ob_district')),
            OptionField(
                label: s('ob_state'),
                options: options.states,
                value: _stateId,
                allowNone: true,
                onChanged: (v) => setState(() => _stateId = v)),
            const SizedBox(height: 12),
            _field('pincode', s('ob_pincode'), type: TextInputType.number),
            LiveLocationField(
              value: _fix,
              required: true,
              error: _error?.field('location_accuracy') ??
                  _error?.field('latitude'),
              onChanged: (f) => setState(() => _fix = f),
            ),
            SectionTitle(s('ob_timings_contact')),
            Row(children: [
              Expanded(
                  child: TimeField(
                      label: s('ob_opens'),
                      value: _opens,
                      onChanged: (t) => setState(() => _opens = t))),
              const SizedBox(width: 12),
              Expanded(
                  child: TimeField(
                      label: s('ob_closes'),
                      value: _closes,
                      onChanged: (t) => setState(() => _closes = t))),
            ]),
            const SizedBox(height: 12),
            _field('timings_note', s('ob_timings_note'),
                hint: s('ob_timings_note_hint')),
            _field('contact_phone', s('ob_temple_phone'),
                type: TextInputType.phone),
            _field('official_website', s('ob_website'),
                type: TextInputType.url),
            SectionTitle(s('ob_you')),
            OptionField(
              label: s('ob_your_role'),
              options: options.registrationRoles,
              value: _role,
              onChanged: (v) => setState(() => _role = '$v'),
            ),
            const SizedBox(height: 12),
            _field('submitter_note', s('ob_editor_note'), lines: 3),
            SectionTitle(s('ob_photos_count',
                {'n': _photos.length, 'max': options.maxRegistrationPhotos})),
            if (_error?.field('photos') != null)
              Text(_error!.field('photos')!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _photos)
                  Chip(
                    avatar: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(p.bytes,
                            width: 28, height: 21, fit: BoxFit.cover)),
                    label: Text(p.filename, overflow: TextOverflow.ellipsis),
                    onDeleted: () => setState(() => _photos.remove(p)),
                  ),
                if (_photos.length < options.maxRegistrationPhotos)
                  ActionChip(
                      avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(s('ob_add_photos')),
                      onPressed: _addPhotos),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? s('ob_sending') : s('ob_send_review'))),
          ],
        ),
      ),
    );
  }
}
