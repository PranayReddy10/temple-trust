import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// The temple's name and details in the languages devotees read the app in.
///
/// What the team can change in English publishes straight away; the name and
/// the fields our editors keep go to them first. Auto-translate only fills
/// the box: nothing is saved until someone reads it and taps Save.
class TranslationsScreen extends StatefulWidget {
  const TranslationsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<TranslationsScreen> createState() => _TranslationsScreenState();
}

class _TranslationsScreenState extends State<TranslationsScreen> {
  Json? _data;
  Object? _error;
  String? _language;

  String get _path => 'temples/${widget.templeId}/translations';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await context.read<Session>().api.get(_path);
      if (mounted) _apply((res['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _apply(Json data) {
    final codes = [
      for (final l in data['languages'] as List) (l as Map)['code'] as String
    ];
    final mine = Localizations.localeOf(context).languageCode;
    setState(() {
      _data = data;
      _language ??=
          codes.contains(mine) ? mine : (codes.isEmpty ? null : codes.first);
    });
  }

  List<Json> get _fields => [
        for (final f in (_data?['fields'] as List? ?? const []))
          (f as Map).cast<String, dynamic>()
      ];

  Json? _current(Json field) {
    final t = field['translations'];
    if (t is Map && t[_language] is Map) {
      return (t[_language] as Map).cast<String, dynamic>();
    }
    return null;
  }

  String _languageName(String code) {
    for (final l in (_data?['languages'] as List? ?? const [])) {
      final m = (l as Map).cast<String, dynamic>();
      if (m['code'] == code) {
        return (m['native'] ?? m['name'] ?? code) as String;
      }
    }
    return code;
  }

  Future<void> _edit(Json field) async {
    final s = S.of(context);
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _EditSheet(
        path: _path,
        field: field,
        language: _language!,
        languageName: _languageName(_language!),
        current: _current(field)?['value'] as String?,
        autoTranslate: _data?['auto_translate'] == true,
        onSaved: _apply,
      ),
    );
    if (saved != null && mounted) showMessage(context, s(saved));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final fields = _fields;
    final done = fields.where((f) => _current(f) != null).length;

    return Scaffold(
      appBar: AppBar(title: Text(s('tr_title'))),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : _data == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Text(s('tr_intro'), style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final l in _data!['languages'] as List)
                          ChoiceChip(
                            label: Text((l as Map)['native'] as String),
                            selected: _language == l['code'],
                            onSelected: (_) =>
                                setState(() => _language = l['code'] as String),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      if (fields.isEmpty)
                        EmptyState(icon: Icons.translate, text: s('tr_nothing'))
                      else ...[
                        Text(
                            s('tr_done_count',
                                {'done': done, 'total': fields.length}),
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        for (final f in fields) _tile(context, f),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tile(BuildContext context, Json field) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final current = _current(field);
    final reviewed = current?['is_reviewed'] == true;
    final color = current == null
        ? theme.colorScheme.outline
        : reviewed
            ? Palette.tulsi
            : const Color(0xFFB08A10);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _edit(field),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(s('tr_field_${field['field']}'),
                      style: theme.textTheme.titleSmall)),
              StatusChip(
                current == null
                    ? s('tr_missing')
                    : reviewed
                        ? s('tr_live')
                        : s('tr_in_review'),
                color: color,
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              (current?['value'] ?? field['english']) as String,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: current == null
                  ? theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                  : theme.textTheme.bodyMedium,
            ),
          ]),
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.path,
    required this.field,
    required this.language,
    required this.languageName,
    required this.current,
    required this.autoTranslate,
    required this.onSaved,
  });

  final String path;
  final Json field;
  final String language;
  final String languageName;
  final String? current;
  final bool autoTranslate;
  final void Function(Json data) onSaved;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _text = TextEditingController(text: widget.current ?? '');
  bool _busy = false;
  bool _suggested = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _auto() async {
    setState(() => _busy = true);
    try {
      final res = await context.read<Session>().api.post(
          '${widget.path}/suggest',
          {'field': widget.field['field'], 'locale': widget.language});
      _text.text = ((res['data'] as Map)['value'] ?? '') as String;
      _suggested = true;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save({bool remove = false}) async {
    setState(() => _busy = true);
    try {
      final res = await context.read<Session>().api.put(widget.path, {
        'field': widget.field['field'],
        'locale': widget.language,
        'value': remove ? '' : _text.text.trim(),
      });
      widget.onSaved((res['data'] as Map).cast<String, dynamic>());
      if (!mounted) return;
      Navigator.pop(
          context,
          remove || _text.text.trim().isEmpty
              ? 'tr_removed'
              : widget.field['publishes_directly'] == true
                  ? 'tr_saved_live'
                  : 'tr_saved_review');
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final long = (widget.field['english'] as String).length > 80;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s('tr_field_${widget.field['field']}'),
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(s('tr_english'), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(widget.field['english'] as String),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              minLines: long ? 3 : 1,
              maxLines: long ? 8 : 2,
              maxLength: 5000,
              decoration: InputDecoration(
                labelText:
                    s('tr_in_language', {'language': widget.languageName}),
                helperText: _suggested ? s('tr_auto_hint') : null,
                helperMaxLines: 2,
              ),
            ),
            if (widget.field['publishes_directly'] != true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child:
                    Text(s('tr_review_note'), style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.autoTranslate)
                OutlinedButton.icon(
                  onPressed: _busy ? null : _auto,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(s('tr_auto')),
                ),
              if (widget.current != null)
                TextButton(
                  onPressed: _busy ? null : () => _save(remove: true),
                  child: Text(s('tr_remove')),
                ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : () => _save(),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(s('tr_save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
