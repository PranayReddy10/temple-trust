import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

Future<String?> _askReason(BuildContext context, String title, {String hint = 'The requester sees this'}) async {
  final c = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, maxLines: 3, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Send')),
      ],
    ),
  );
  return (v == null || v.isEmpty) ? null : v;
}

Future<void> _act(BuildContext context, Future<void> Function() action, String done, VoidCallback reload) async {
  try {
    await action();
    if (context.mounted) showMessage(context, done);
    reload();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Widget _call(String? phone) =>
    phone == null || phone.isEmpty ? const SizedBox() : TextButton.icon(onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)), icon: const Icon(Icons.call, size: 18), label: Text(phone));

/// Who wants to manage which temple. Staff usually call before approving.
class ClaimsQueueScreen extends StatelessWidget {
  const ClaimsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Requests to manage')),
      body: AsyncList<Json>(
        load: () async => [for (final r in (await api.get('admin/claims'))['data'] as List) (r as Map).cast<String, dynamic>()],
        empty: 'No requests waiting.',
        itemBuilder: (context, c, reload) {
          final t = (c['temple'] as Map?) ?? const {};
          final u = (c['user'] as Map?) ?? const {};
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['name']}${t['city'] != null ? ', ${t['city']}' : ''}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${u['name']} · ${u['email']} · as ${c['role']}'),
                if (c['note'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${c['note']}”')),
                _askedFrom(context, c['location'] as Map?),
                Row(children: [
                  _call(u['phone'] as String?),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final reason = await _askReason(context, 'Reject request');
                      if (reason == null || !context.mounted) return;
                      await _act(context, () => api.post('admin/claims/${c['id']}/reject', {'reason': reason}), 'Rejected.', reload);
                    },
                    child: const Text('Reject'),
                  ),
                  FilledButton(
                    onPressed: () => _act(context, () => api.post('admin/claims/${c['id']}/approve'), 'Approved. They can manage the temple now.', reload),
                    child: const Text('Approve'),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Temples registered by temple teams and suggested by devotees.
class RegistrationsQueueScreen extends StatelessWidget {
  const RegistrationsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Temples to list')),
      body: AsyncList<Json>(
        load: () async => [for (final r in (await api.get('admin/registrations'))['data'] as List) (r as Map).cast<String, dynamic>()],
        empty: 'No temples waiting to be listed.',
        itemBuilder: (context, r, reload) {
          final s = (r['submitter'] as Map?) ?? const {};
          final photos = (r['photos'] as List?) ?? const [];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (photos.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final p in photos) Padding(padding: const EdgeInsets.only(right: 2), child: Image.network('$p', height: 140, fit: BoxFit.cover)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['name']}', style: Theme.of(context).textTheme.titleMedium)),
                    StatusChip(r['from_trust_app'] == true ? 'Temple team' : 'Devotee'),
                  ]),
                  Text([r['deity'], r['city'], r['district'], r['state'], r['pincode']].where((e) => e != null).join(' · ')),
                  if (r['opens_at'] != null) Text('Open ${showTime(r['opens_at'])} – ${showTime(r['closes_at']) ?? '?'}'),
                  if (r['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['description']}')),
                  const SizedBox(height: 6),
                  Text('From ${s['name'] ?? 'someone'} (${s['role']})${s['email'] != null ? ' · ${s['email']}' : ''}', style: Theme.of(context).textTheme.bodySmall),
                  if (s['note'] != null) Text('“${s['note']}”', style: Theme.of(context).textTheme.bodySmall),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _call(s['phone'] as String?),
                    TextButton(
                      onPressed: () async {
                        final note = await _askReason(context, 'Reject', hint: 'Why it will not be listed');
                        if (note == null || !context.mounted) return;
                        await _act(context, () => api.post('admin/registrations/${r['id']}/reject', {'note': note}), 'Rejected.', reload);
                      },
                      child: const Text('Reject'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final id = await _askReason(context, 'Already listed', hint: 'ID of the existing temple');
                        final templeId = int.tryParse(id ?? '');
                        if (templeId == null || !context.mounted) return;
                        await _act(context, () => api.post('admin/registrations/${r['id']}/duplicate', {'temple_id': templeId}), 'Matched to the existing temple.', reload);
                      },
                      child: const Text('Duplicate'),
                    ),
                    FilledButton(
                      onPressed: () => _act(
                        context,
                        () => api.post('admin/registrations/${r['id']}/approve'),
                        r['from_trust_app'] == true ? 'Listed as a draft. Approve their request to manage it under Requests.' : 'Listed as a draft temple.',
                        reload,
                      ),
                      child: const Text('List as draft'),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Events temple teams published, waiting for review.
class EventsQueueScreen extends StatelessWidget {
  const EventsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    return Scaffold(
      appBar: AppBar(title: const Text('Events to review')),
      body: AsyncList<Json>(
        load: () async => [for (final r in (await api.get('admin/events'))['data'] as List) (r as Map).cast<String, dynamic>()],
        empty: 'No events waiting for review.',
        itemBuilder: (context, e, reload) {
          final t = (e['temple'] as Map?) ?? const {};
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (e['image_url'] != null) Image.network('${e['image_url']}', height: 140, fit: BoxFit.cover),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${e['title']}', style: Theme.of(context).textTheme.titleMedium),
                  Text('${t['name']} · ${e['date_label']}'),
                  // A devotee proposed it from the app, not the temple's team:
                  // free, with "I'll join"; the temple is not asked first.
                  if (e['raised_by_devotee'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StatusChip('Raised by a devotee${e['raised_by'] != null ? ' · ${e['raised_by']}' : ''} · free', color: Palette.saffron, icon: Icons.music_note_outlined),
                    ),
                  if (e['description'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${e['description']}')),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(
                      onPressed: () async {
                        final note = await _askReason(context, 'Reject event', hint: 'The temple sees this');
                        if (note == null || !context.mounted) return;
                        await _act(context, () => api.post('admin/events/${e['id']}/reject', {'note': note}), 'Rejected.', reload);
                      },
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: () => _act(context, () => api.post('admin/events/${e['id']}/approve'), 'Published.', reload),
                      child: const Text('Publish'),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Where the person stood when they asked, with the map one tap away.
Widget _askedFrom(BuildContext context, Map? loc) {
  final theme = Theme.of(context);
  if (loc == null) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('No location sent with this request', style: theme.textTheme.bodySmall),
    );
  }
  final distance = loc['distance_m'] as num?;
  final near = distance != null && distance <= 500;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: InkWell(
      onTap: loc['map_url'] == null ? null : () => launchUrl(Uri.parse('${loc['map_url']}'), mode: LaunchMode.externalApplication),
      child: Row(children: [
        Icon(Icons.place_outlined, size: 18, color: distance == null ? theme.hintColor : (near ? Colors.green.shade700 : theme.colorScheme.error)),
        const SizedBox(width: 6),
        Expanded(child: Text('${loc['summary']}', style: theme.textTheme.bodySmall)),
        if (loc['map_url'] != null) Text('Map', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
      ]),
    ),
  );
}
