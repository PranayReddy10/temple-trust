import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
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
    'short_description', 'address', 'city', 'pincode', 'latitude', 'longitude',
    'official_website', 'contact_phone', 'contact_email',
    'dress_code', 'photography_policy', 'mobile_policy', 'footwear_policy', 'entry_rules', 'queue_information',
  ];

  late final Map<String, TextEditingController> _c = {
    for (final f in _fields) f: TextEditingController(text: widget.temple.profile[f]?.toString() ?? ''),
  };
  bool _busy = false;
  ApiException? _error;

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
        for (final f in _fields) f: _c[f]!.text.trim().isEmpty ? null : _c[f]!.text.trim(),
      });
      if (!mounted) return;
      showMessage(context, 'Saved. Devotees see the changes at once.');
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

  Widget _f(String key, String label, {int lines = 1, TextInputType? type, String? hint}) =>
      ApiTextField(controller: _c[key]!, label: label, field: key, error: _error, maxLines: lines, keyboardType: type, hint: hint);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Temple details'),
        actions: [TextButton(onPressed: _busy ? null : _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(widget.temple.name),
              subtitle: const Text('Name, deity and classification are kept by the editorial team. Write to support if any of it is wrong.'),
            ),
          ),
          const SectionTitle('About'),
          _f('short_description', 'Short description', lines: 3, hint: 'One or two sentences, shown in search results'),
          const SectionTitle('Location'),
          _f('address', 'Address', lines: 3),
          _f('city', 'City / town / village'),
          _f('pincode', 'PIN code', type: TextInputType.number),
          Row(children: [
            Expanded(child: _f('latitude', 'Latitude', type: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            const SizedBox(width: 12),
            Expanded(child: _f('longitude', 'Longitude', type: const TextInputType.numberWithOptions(decimal: true, signed: true))),
          ]),
          const SectionTitle('Official contact'),
          _f('contact_phone', 'Phone', type: TextInputType.phone),
          _f('contact_email', 'Email', type: TextInputType.emailAddress),
          _f('official_website', 'Website', type: TextInputType.url),
          const SectionTitle('Visitor rules'),
          _f('dress_code', 'Dress code', lines: 2),
          _f('photography_policy', 'Photography'),
          _f('mobile_policy', 'Mobile phones'),
          _f('footwear_policy', 'Footwear'),
          _f('entry_rules', 'Entry rules', lines: 3),
          _f('queue_information', 'Queue information', lines: 3),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save')),
        ],
      ),
    );
  }
}
