import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/session.dart';
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
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/reviews', {'unanswered': _unanswered ? '1' : null});
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  Future<void> _reply(Json r) async {
    final c = TextEditingController(text: r['temple_reply'] ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reply as the temple'),
        content: TextField(controller: c, maxLines: 5, minLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'The devotee sees this under their review')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Send')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      await context.read<Session>().api.post('temples/${widget.templeId}/reviews/${r['id']}/reply', {'reply': text.trim()});
      _list.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devotee reviews'),
        actions: [
          FilterChip(
            label: const Text('Unanswered'),
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
        empty: 'No published reviews yet.',
        itemBuilder: (context, r, reload) {
          final devotee = (r['devotee'] as Map?) ?? const {};
          final ratings = (r['ratings'] as List?) ?? const [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${devotee['name'] ?? 'Devotee'}${r['visited_on'] != null ? ' · visited ${r['visited_on']}' : ''}', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    for (final x in ratings)
                      if ((x as Map)['value'] != null) StatusChip('${x['label']}: ${x['value']}/5'),
                  ]),
                  if (r['body'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${r['body']}')),
                  if (r['temple_reply'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Text('Temple: ${r['temple_reply']}'),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _reply(r),
                      icon: const Icon(Icons.reply, size: 18),
                      label: Text(r['temple_reply'] == null ? 'Reply' : 'Edit reply'),
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
