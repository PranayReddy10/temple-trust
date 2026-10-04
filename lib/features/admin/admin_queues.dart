import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

Future<String?> _askReason(BuildContext context, String title,
    {String? hint}) async {
  final s = S.of(context);
  final c = TextEditingController();
  final v = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration:
              InputDecoration(hintText: hint ?? s('ad_requester_sees'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(s('cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: Text(s('ad_send'))),
      ],
    ),
  );
  return (v == null || v.isEmpty) ? null : v;
}

Future<void> _act(BuildContext context, Future<void> Function() action,
    String done, VoidCallback reload) async {
  try {
    await action();
    if (context.mounted) showMessage(context, done);
    reload();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

Widget _call(String? phone) => phone == null || phone.isEmpty
    ? const SizedBox()
    : TextButton.icon(
        onPressed: () => launchUrl(Uri(scheme: 'tel', path: phone)),
        icon: const Icon(Icons.call, size: 18),
        label: Text(phone));

/// Who wants to manage which temple. Staff usually call before approving.
class ClaimsQueueScreen extends StatelessWidget {
  const ClaimsQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Session>().api;
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('ad_requests_to_manage'))),
      body: AsyncList<Json>(
        load: () async => [
          for (final r in (await api.get('admin/claims'))['data'] as List)
            (r as Map).cast<String, dynamic>()
        ],
        empty: s('ad_no_requests'),
        itemBuilder: (context, c, reload) {
          final t = (c['temple'] as Map?) ?? const {};
          final u = (c['user'] as Map?) ?? const {};
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${t['name']}${t['city'] != null ? ', ${t['city']}' : ''}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(s('ad_user_as_role', {
                      'name': u['name'],
                      'email': u['email'],
                      'role': c['role']
                    })),
                    if (c['note'] != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('“${c['note']}”')),
                    _askedFrom(context, c['location'] as Map?),
                    Row(children: [
                      _call(u['phone'] as String?),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final reason =
                              await _askReason(context, s('ad_reject_request'));
                          if (reason == null || !context.mounted) return;
                          await _act(
                              context,
                              () => api.post('admin/claims/${c['id']}/reject',
                                  {'reason': reason}),
                              s('event_rejected'),
                              reload);
                        },
                        child: Text(s('reject')),
                      ),
                      FilledButton(
                        onPressed: () => _act(
                            context,
                            () => api.post('admin/claims/${c['id']}/approve'),
                            s('ad_claim_approved'),
                            reload),
                        child: Text(s('approve')),
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
    final l = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l('temples_to_list'))),
      body: AsyncList<Json>(
        load: () async => [
          for (final r
              in (await api.get('admin/registrations'))['data'] as List)
            (r as Map).cast<String, dynamic>()
        ],
        empty: l('ad_no_registrations'),
        itemBuilder: (context, r, reload) {
          final s = (r['submitter'] as Map?) ?? const {};
          final photos = (r['photos'] as List?) ?? const [];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (photos.isNotEmpty)
                    SizedBox(
                      height: 140,
                      child:
                          ListView(scrollDirection: Axis.horizontal, children: [
                        for (final p in photos)
                          Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Image.network('$p',
                                  height: 140, fit: BoxFit.cover)),
                      ]),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text('${r['name']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium)),
                            StatusChip(r['from_trust_app'] == true
                                ? l('ad_temple_team')
                                : l('ad_devotee')),
                          ]),
                          Text([
                            r['deity'],
                            r['city'],
                            r['district'],
                            r['state'],
                            r['pincode']
                          ].where((e) => e != null).join(' · ')),
                          if (r['opens_at'] != null)
                            Text(l('ad_open_hours', {
                              'from': showTime(r['opens_at']),
                              'to': showTime(r['closes_at']) ?? '?'
                            })),
                          if (r['description'] != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${r['description']}')),
                          const SizedBox(height: 6),
                          Text(
                              '${l('ad_from_submitter', {
                                    'name': s['name'] ?? l('ad_someone'),
                                    'role': s['role']
                                  })}${s['email'] != null ? ' · ${s['email']}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (s['note'] != null)
                            Text('“${s['note']}”',
                                style: Theme.of(context).textTheme.bodySmall),
                          Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _call(s['phone'] as String?),
                                TextButton(
                                  onPressed: () async {
                                    final note = await _askReason(
                                        context, l('reject'),
                                        hint: l('ad_why_not_listed'));
                                    if (note == null || !context.mounted) {
                                      return;
                                    }
                                    await _act(
                                        context,
                                        () => api.post(
                                            'admin/registrations/${r['id']}/reject',
                                            {'note': note}),
                                        l('event_rejected'),
                                        reload);
                                  },
                                  child: Text(l('reject')),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final id = await _askReason(
                                        context, l('ad_already_listed'),
                                        hint: l('ad_existing_temple_id'));
                                    final templeId = int.tryParse(id ?? '');
                                    if (templeId == null || !context.mounted) {
                                      return;
                                    }
                                    await _act(
                                        context,
                                        () => api.post(
                                            'admin/registrations/${r['id']}/duplicate',
                                            {'temple_id': templeId}),
                                        l('ad_matched_existing'),
                                        reload);
                                  },
                                  child: Text(l('ad_duplicate')),
                                ),
                                FilledButton(
                                  onPressed: () => _act(
                                    context,
                                    () => api.post(
                                        'admin/registrations/${r['id']}/approve'),
                                    r['from_trust_app'] == true
                                        ? l('ad_listed_draft_claim')
                                        : l('ad_listed_draft'),
                                    reload,
                                  ),
                                  child: Text(l('ad_list_as_draft')),
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
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('events_to_review'))),
      body: AsyncList<Json>(
        load: () async => [
          for (final r in (await api.get('admin/events'))['data'] as List)
            (r as Map).cast<String, dynamic>()
        ],
        empty: s('ad_no_events'),
        itemBuilder: (context, e, reload) {
          final t = (e['temple'] as Map?) ?? const {};
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (e['image_url'] != null)
                    Image.network('${e['image_url']}',
                        height: 140, fit: BoxFit.cover),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e['title']}',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('${t['name']} · ${e['date_label']}'),
                          // A devotee proposed it from the app, not the temple's team:
                          // free, with "I'll join"; the temple is not asked first.
                          if (e['raised_by_devotee'] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: StatusChip(
                                  '${s('ad_raised_by_devotee')}${e['raised_by'] != null ? ' · ${e['raised_by']}' : ''} · ${s('ad_free')}',
                                  color: Palette.saffron,
                                  icon: Icons.music_note_outlined),
                            ),
                          if (e['description'] != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${e['description']}')),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final note = await _askReason(
                                        context, s('ad_reject_event'),
                                        hint: s('ad_temple_sees'));
                                    if (note == null || !context.mounted) {
                                      return;
                                    }
                                    await _act(
                                        context,
                                        () => api.post(
                                            'admin/events/${e['id']}/reject',
                                            {'note': note}),
                                        s('event_rejected'),
                                        reload);
                                  },
                                  child: Text(s('reject')),
                                ),
                                FilledButton(
                                  onPressed: () => _act(
                                      context,
                                      () => api.post(
                                          'admin/events/${e['id']}/approve'),
                                      s('ad_published_done'),
                                      reload),
                                  child: Text(s('ad_publish')),
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
      child: Text(S.of(context)('ad_no_location'),
          style: theme.textTheme.bodySmall),
    );
  }
  final distance = loc['distance_m'] as num?;
  final near = distance != null && distance <= 500;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: InkWell(
      onTap: loc['map_url'] == null
          ? null
          : () => launchUrl(Uri.parse('${loc['map_url']}'),
              mode: LaunchMode.externalApplication),
      child: Row(children: [
        Icon(Icons.place_outlined,
            size: 18,
            color: distance == null
                ? theme.hintColor
                : (near ? Colors.green.shade700 : theme.colorScheme.error)),
        const SizedBox(width: 6),
        Expanded(
            child: Text('${loc['summary']}', style: theme.textTheme.bodySmall)),
        if (loc['map_url'] != null)
          Text(S.of(context)('ad_map'),
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
      ]),
    ),
  );
}
