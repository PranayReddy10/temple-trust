import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// What devotees wrote about visiting, with the temple's replies.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _unanswered = false;
  final _list = GlobalKey<AsyncListState<Json>>();

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get(
        'temples/${widget.templeId}/reviews',
        {'unanswered': _unanswered ? '1' : null});
    return [
      for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()
    ];
  }

  Future<void> _reply(Json r) async {
    final s = S.of(context);
    final c = TextEditingController(text: r['temple_reply'] ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s('tp_reply_as_temple')),
        content: TextField(
            controller: c,
            maxLines: 5,
            minLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(hintText: s('tp_reply_hint'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: Text(s('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(d, c.text),
              child: Text(s('tp_send'))),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      await context.read<Session>().api.post(
          'temples/${widget.templeId}/reviews/${r['id']}/reply',
          {'reply': text.trim()});
      _list.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s('reviews')),
        actions: [
          FilterChip(
            label: Text(s('tp_unanswered')),
            selected: _unanswered,
            onSelected: (v) {
              setState(() => _unanswered = v);
              _list.currentState?.reload();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncList<Json>(
        key: _list,
        load: _load,
        empty: s('tp_reviews_empty'),
        itemBuilder: (context, r, reload) {
          final devotee = (r['devotee'] as Map?) ?? const {};
          final ratings = (r['ratings'] as List?) ?? const [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    InitialsAvatar('${devotee['name'] ?? s('tp_devotee')}',
                        size: 36,
                        color: r['temple_reply'] == null
                            ? Palette.saffron
                            : Palette.tulsi),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            '${devotee['name'] ?? s('tp_devotee')}${r['visited_on'] != null ? ' · ${s('tp_visited_on', {
                                    'date': r['visited_on']
                                  })}' : ''}',
                            style: theme.textTheme.titleSmall)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final x in ratings)
                      if ((x as Map)['value'] != null)
                        StatusChip('${x['label']}: ${x['value']}/5'),
                  ]),
                  if (r['body'] != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('${r['body']}')),
                  if (r['temple_reply'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(
                          s('tp_temple_reply', {'reply': r['temple_reply']})),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _reply(r),
                      icon: const Icon(Icons.reply, size: 18),
                      label: Text(r['temple_reply'] == null
                          ? s('tp_reply')
                          : s('tp_edit_reply')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
