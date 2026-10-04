import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};

String _when(dynamic iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null
      ? ''
      : '${formatDate(d)} ${showTime(TimeOfDay.fromDateTime(d))}';
}

/// Help from the Darshan Saathi team: questions and problems go to the admin
/// panel's support queue, and the team's answers come back here.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('support');
    return [for (final r in res['data'] as List) _map(r)];
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('help_support'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const NewSupportScreen()),
        icon: const Icon(Icons.edit_outlined),
        label: Text(s('ob_ask_team')),
      ),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        header: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(s('ob_support_intro', {'name': Brand.name})),
        ),
        empty: s('ob_support_empty'),
        itemBuilder: (context, t, reload) {
          final status = _map(t['status']);
          final messages = (t['messages'] as List? ?? const []);
          return Card(
            child: ListTile(
              leading: IconBadge(
                  status['is_open'] == true
                      ? Icons.forum_outlined
                      : Icons.task_alt,
                  color: status['is_open'] == true
                      ? const Color(0xFFB08A10)
                      : Palette.tulsi),
              title: Text('${t['subject']}'),
              subtitle: Text([
                '${t['reference']}',
                _when(t['created_at']),
                if (messages.isNotEmpty)
                  messages.length == 1
                      ? s('ob_one_reply')
                      : s('ob_n_replies', {'n': messages.length}),
              ].join(' · ')),
              trailing: StatusChip.forStatus(
                  status['is_open'] == true ? 'pending' : 'approved',
                  '${status['label'] ?? ''}'),
              onTap: () =>
                  _open(SupportTicketScreen(reference: '${t['reference']}')),
            ),
          );
        },
      ),
    );
  }
}

/// A new question to the team, optionally about one of the account's temples.
class NewSupportScreen extends StatefulWidget {
  const NewSupportScreen({super.key});

  @override
  State<NewSupportScreen> createState() => _NewSupportScreenState();
}

class _NewSupportScreenState extends State<NewSupportScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String? _category;
  int? _templeId;
  List<Json> _categories = const [];
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final temples = context.read<Session>().account?.temples ?? const [];
    if (temples.length == 1) _templeId = temples.first.id;
    context.read<Session>().api.get('support/options').then((res) {
      if (!mounted) return;
      setState(() => _categories = [
            for (final c
                in (_map(res['data'])['categories'] as List? ?? const []))
              _map(c)
          ]);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await context.read<Session>().api.post('support', {
        'subject': _subject.text.trim(),
        'body': _body.text.trim(),
        if (_category != null) 'category': _category,
        if (_templeId != null) 'temple_id': _templeId,
      });
      if (!mounted) return;
      showMessage(
          context,
          S.of(context)(
              'ob_sent_reference', {'ref': _map(res['data'])['reference']}));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final temples = context.watch<Session>().account?.temples ?? const [];
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('ob_ask_team'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_categories.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(labelText: s('ob_what_about')),
              items: [
                for (final c in _categories)
                  DropdownMenuItem(
                      value: '${c['value']}',
                      child: Text('${c['label']}',
                          overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
          ],
          if (temples.isNotEmpty) ...[
            DropdownButtonFormField<int?>(
              initialValue: _templeId,
              isExpanded: true,
              decoration: InputDecoration(labelText: s('ob_temple_optional')),
              items: [
                DropdownMenuItem<int?>(
                    value: null, child: Text(s('ob_not_one_temple'))),
                for (final t in temples)
                  DropdownMenuItem<int?>(
                      value: t.id,
                      child: Text(t.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _templeId = v),
            ),
            const SizedBox(height: 12),
          ],
          ApiTextField(
              controller: _subject,
              label: s('ob_subject'),
              field: 'subject',
              error: _error,
              required: true),
          ApiTextField(
              controller: _body,
              label: s('ob_your_message'),
              field: 'body',
              error: _error,
              maxLines: 6,
              required: true,
              hint: s('ob_message_hint')),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_outlined),
            label: Text(_busy ? s('ob_sending') : s('ob_send_to_team')),
          ),
        ],
      ),
    );
  }
}

/// One conversation with the team, and a reply.
class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key, required this.reference});

  final String reference;

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  late Future<Json> _future = _load();

  void _retry() {
    _future = _load();
  }

  final _reply = TextEditingController();
  bool _busy = false;

  Future<Json> _load() async => _map((await context
      .read<Session>()
      .api
      .get('support/${widget.reference}'))['data']);

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<Session>().api.post(
          'support/${widget.reference}/replies', {'body': _reply.text.trim()});
      _reply.clear();
      if (mounted) {
        setState(() {
          _future = _load();
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.reference)),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorView(
                error: snap.error!, onRetry: () => setState(() => _retry()));
          }
          final t = snap.data!;
          final about = t['about'] == null ? null : _map(t['about']);
          final messages = [
            for (final m in (t['messages'] as List? ?? const [])) _map(m)
          ];
          Widget bubble(String who, String body, String when, bool staff) =>
              Align(
                alignment: staff ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: staff
                        ? theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.6)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(who,
                            style: theme.textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(body),
                        const SizedBox(height: 4),
                        Text(when, style: theme.textTheme.bodySmall),
                      ]),
                ),
              );
          return Column(children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('${t['subject']}', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      [
                        '${_map(t['status'])['label'] ?? ''}',
                        if (about?['label'] != null) '${about!['label']}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  bubble(s('ob_you'), '${t['body']}', _when(t['created_at']),
                      false),
                  for (final m in messages)
                    bubble(
                        m['from_staff'] == true
                            ? s('ob_team_name', {'name': Brand.name})
                            : s('ob_you'),
                        '${m['body']}',
                        _when(m['created_at']),
                        m['from_staff'] == true),
                  if (t['resolution'] != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(s('ob_resolved', {'text': t['resolution']}),
                            style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _reply,
                          minLines: 1,
                          maxLines: 4,
                          decoration:
                              InputDecoration(hintText: s('ob_write_reply')))),
                  const SizedBox(width: 8),
                  SendButton(onPressed: _send, busy: _busy),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
