import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/live_location.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

/// The part of the listing the temple owns. Name, deity and classification
/// stay with the editors, as in the temple portal.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.temple});

  final TrustTemple temple;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  static const _fields = [
    'short_description',
    'address',
    'city',
    'district',
    'pincode',
    'official_website',
    'contact_phone',
    'contact_email',
    'dress_code',
    'photography_policy',
    'mobile_policy',
    'footwear_policy',
    'entry_rules',
    'queue_information',
  ];

  late final Map<String, TextEditingController> _c = {
    for (final f in _fields)
      f: TextEditingController(
          text: widget.temple.profile[f]?.toString() ?? ''),
  };
  LiveFix? _fix;
  late dynamic _stateId = widget.temple.profile['state_id'];
  bool _busy = false;
  ApiException? _error;

  String? get _saved {
    final lat = widget.temple.profile['latitude'],
        lng = widget.temple.profile['longitude'];
    return lat == null || lng == null
        ? null
        : S.of(context)('tp_location_on_file', {'lat': lat, 'lng': lng});
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<Session>().api.patch('temples/${widget.temple.id}', {
        for (final f in _fields)
          f: _c[f]!.text.trim().isEmpty ? null : _c[f]!.text.trim(),
        'state_id': _stateId,
        // Coordinates change only with a fresh fix taken at the temple.
        if (_fix != null) ..._fix!.toFields(),
      });
      if (!mounted) return;
      showMessage(context, S.of(context)('tp_profile_saved'));
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

  Widget _f(String key, String label,
          {int lines = 1, TextInputType? type, String? hint}) =>
      ApiTextField(
          controller: _c[key]!,
          label: label,
          field: key,
          error: _error,
          maxLines: lines,
          keyboardType: type,
          hint: hint);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s('temple_details')),
        actions: [
          TextButton(onPressed: _busy ? null : _save, child: Text(s('save')))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(widget.temple.name),
              subtitle: Text(s('tp_profile_locked_note')),
            ),
          ),
          SectionTitle(s('tp_about')),
          _f('short_description', s('tp_short_description'),
              lines: 3, hint: s('tp_short_description_hint')),
          SectionTitle(s('tp_location')),
          _f('address', s('tp_address'), lines: 3),
          _f('city', s('tp_city')),
          _f('district', s('tp_district')),
          OptionField(
            label: s('tp_state'),
            options: context.watch<Session>().options.states,
            value: _stateId,
            allowNone: true,
            onChanged: (v) => setState(() => _stateId = v),
          ),
          const SizedBox(height: 12),
          _f('pincode', s('tp_pin_code'), type: TextInputType.number),
          LiveLocationField(
            value: _fix,
            saved: _saved,
            error:
                _error?.field('location_accuracy') ?? _error?.field('latitude'),
            onChanged: (f) => setState(() => _fix = f),
          ),
          SectionTitle(s('tp_official_contact')),
          _f('contact_phone', s('tp_phone'), type: TextInputType.phone),
          _f('contact_email', s('email'), type: TextInputType.emailAddress),
          _f('official_website', s('tp_website'), type: TextInputType.url),
          SectionTitle(s('tp_visitor_rules')),
          _f('dress_code', s('tp_dress_code'), lines: 2),
          _f('photography_policy', s('tp_photography')),
          _f('mobile_policy', s('tp_mobile_phones')),
          _f('footwear_policy', s('tp_footwear')),
          _f('entry_rules', s('tp_entry_rules'), lines: 3),
          _f('queue_information', s('tp_queue_info'), lines: 3),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? s('saving') : s('save'))),
        ],
      ),
    );
  }
}
