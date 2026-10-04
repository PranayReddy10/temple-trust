import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The devotee's passport as the counter sees it: their photo and name, how
/// far their pilgrimage has gone, and their latest visits, so the person at
/// the counter can tell they have the right devotee in front of them.
class PassportCard extends StatelessWidget {
  const PassportCard(
      {super.key, required this.passport, required this.templeIds});

  final Map<String, dynamic> passport;
  final Set<int> templeIds;

  static String _date(S s, String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day} ${s('mn_mon_${d.month}')} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final name = '${passport['name'] ?? s('mn_devotee')}';
    final avatar = passport['avatar_url'] is String &&
            '${passport['avatar_url']}'.isNotEmpty
        ? '${passport['avatar_url']}'
        : null;
    final visits = [
      for (final v in (passport['visits'] as List? ?? const []))
        (v as Map).cast<String, dynamic>()
    ];
    // Here before: the latest visit to one of this account's temples.
    final hereBefore = visits
        .where((v) =>
            templeIds.contains(((v['temple'] as Map?)?['id'] as num?)?.toInt()))
        .firstOrNull;
    int n(String k) => (passport[k] as num?)?.toInt() ?? 0;

    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, color: primary)),
            Text(label, style: theme.textTheme.bodySmall),
          ]),
        );

    return SoftCard(
      border: primary,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: primary,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 64,
                child: avatar == null
                    ? InitialsAvatar(name, size: 64, color: Palette.gold)
                    : Image.network(avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => InitialsAvatar(name,
                            size: 64, color: Palette.gold)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontFamily: TrustTheme.serif,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    if (passport['home_state'] != null)
                      Text(s('pp_from', {'place': passport['home_state']}),
                          style: const TextStyle(color: Colors.white70)),
                    if (passport['joined_at'] != null)
                      Text(
                          s('pp_since',
                              {'date': _date(s, '${passport['joined_at']}')}),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
          child: Row(children: [
            stat('${n('stamps')}', s('pp_stamps')),
            stat('${n('temples_visited')}', s('pp_temples')),
            stat('${n('states_covered')}', s('pp_states')),
          ]),
        ),
        if (hereBefore != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Palette.tulsi.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.history, size: 18, color: Palette.tulsi),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(s('pp_here_before',
                      {'date': _date(s, '${hereBefore['visited_on']}')}))),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s('pp_recent'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            if (visits.isEmpty)
              Text(s('pp_no_visits'), style: theme.textTheme.bodySmall),
            for (final v in visits.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(
                      v['is_verified'] == true
                          ? Icons.verified
                          : Icons.place_outlined,
                      size: 18,
                      color: v['is_verified'] == true
                          ? Palette.tulsi
                          : theme.hintColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        ((v['temple'] as Map?)?['name'] ?? ''),
                        ((v['temple'] as Map?)?['city'])
                      ].where((x) => x != null && '$x'.isNotEmpty).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(_date(s, '${v['visited_on']}'),
                      style: theme.textTheme.bodySmall),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
