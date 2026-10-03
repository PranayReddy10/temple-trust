import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/live_location.dart';
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
  final List<XFile> _photos = [];
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
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2400);
    if (picked.isEmpty) return;
    setState(() {
      _photos.addAll(picked.take(max - _photos.length));
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_fix == null) {
      showMessage(context, 'Record the temple location: stand at the temple and tap "Use my current location".');
      return;
    }
    if (_photos.isEmpty) {
      showMessage(context, 'Add at least one photo of the temple.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<Session>();
    try {
      final files = <UploadFile>[
        for (var i = 0; i < _photos.length; i++) UploadFile(field: 'photos[$i]', filename: _photos[i].name, bytes: await _photos[i].readAsBytes()),
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
      showMessage(context, 'Thank you. Our team will review the temple and call you.');
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

  Widget _field(String key, String label, {bool required = false, int lines = 1, String? hint, TextInputType? type}) =>
      ApiTextField(controller: _c[key]!, label: label, field: key, error: _error, required: required, maxLines: lines, hint: hint, keyboardType: type);

  @override
  Widget build(BuildContext context) {
    final options = context.watch<Session>().options;
    return Scaffold(
      appBar: AppBar(title: const Text('Register a temple')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const Text('Tell us about the temple. The editors check every registration before it is listed.'),
            const SectionTitle('The temple'),
            _field('name', 'Temple name', required: true),
            _field('alternate_names', 'Other names', hint: 'Local or popular names, comma separated'),
            OptionField(label: 'Main deity', options: options.deities, value: _deityId, allowNone: true, noneLabel: 'Not in the list', onChanged: (v) => setState(() => _deityId = v)),
            const SizedBox(height: 12),
            if (_deityId == null) _field('deity_name', 'Deity name'),
            _field('description', 'About the temple', required: true, lines: 4, hint: 'At least a few sentences'),
            _field('history', 'History', lines: 3),
            _field('built_period', 'Built in', hint: 'e.g. 12th century, Kakatiya period'),
            _field('festivals', 'Main festivals', lines: 2),
            const SectionTitle('Where'),
            _field('address', 'Address', lines: 2),
            _field('city', 'Village / town / city', required: true),
            _field('district', 'District'),
            OptionField(label: 'State', options: options.states, value: _stateId, allowNone: true, onChanged: (v) => setState(() => _stateId = v)),
            const SizedBox(height: 12),
            _field('pincode', 'PIN code', type: TextInputType.number),
            LiveLocationField(
              value: _fix,
              required: true,
              error: _error?.field('location_accuracy') ?? _error?.field('latitude'),
              onChanged: (f) => setState(() => _fix = f),
            ),
            const SectionTitle('Timings and contact'),
            Row(children: [
              Expanded(child: TimeField(label: 'Opens', value: _opens, onChanged: (t) => setState(() => _opens = t))),
              const SizedBox(width: 12),
              Expanded(child: TimeField(label: 'Closes', value: _closes, onChanged: (t) => setState(() => _closes = t))),
            ]),
            const SizedBox(height: 12),
            _field('timings_note', 'Timings note', hint: 'e.g. Closed 12:30 to 16:00'),
            _field('contact_phone', 'Temple phone', type: TextInputType.phone),
            _field('official_website', 'Website', type: TextInputType.url),
            const SectionTitle('You'),
            OptionField(
              label: 'Your role at the temple',
              options: options.registrationRoles,
              value: _role,
              onChanged: (v) => setState(() => _role = '$v'),
            ),
            const SizedBox(height: 12),
            _field('submitter_note', 'Anything the editors should know', lines: 3),
            SectionTitle('Photos (${_photos.length}/${options.maxRegistrationPhotos})'),
            if (_error?.field('photos') != null) Text(_error!.field('photos')!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _photos) Chip(label: Text(p.name, overflow: TextOverflow.ellipsis), onDeleted: () => setState(() => _photos.remove(p))),
                if (_photos.length < options.maxRegistrationPhotos) ActionChip(avatar: const Icon(Icons.add_a_photo_outlined, size: 18), label: const Text('Add photos'), onPressed: _addPhotos),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending…' : 'Send for review')),
          ],
        ),
      ),
    );
  }
}
