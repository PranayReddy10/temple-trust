import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import 'bookings_screen.dart';
import 'closures_screen.dart';
import 'events_screen.dart';
import 'photos_screen.dart';
import 'profile_edit_screen.dart';
import 'reviews_screen.dart';
import 'sevas_screen.dart';
import 'timings_screen.dart';

/// One temple: today at a glance, then everything the team manages.
class TempleDashboardScreen extends StatefulWidget {
  const TempleDashboardScreen({super.key, required this.templeId, required this.title});

  final int templeId;
  final String title;

  @override
  State<TempleDashboardScreen> createState() => _TempleDashboardScreenState();
}

class _TempleDashboardScreenState extends State<TempleDashboardScreen> {
  late Future<TrustTemple> _future = _load();

  Future<TrustTemple> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}');
    return TrustTemple.fromJson((res['data'] as Map).cast<String, dynamic>());
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: FutureBuilder<TrustTemple>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final t = snap.data!;
          final s = t.stats;
          int n(String k) => (s[k] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (t.statusLabel != null) StatusChip.forStatus('${(t.raw['status'] as Map?)?['value']}', t.statusLabel!),
                  if (t.trustLabel != null) StatusChip(t.trustLabel!),
                  if (t.deity != null) StatusChip(t.deity!, color: Theme.of(context).colorScheme.tertiary),
                ]),
                if ((t.raw['status'] as Map?)?['value'] != 'published')
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Not yet visible to devotees. Fill in timings, sevas and photos; the editors publish it once reviewed.'),
                  ),
                const SectionTitle('Today'),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    _Stat('Bookings today', n('bookings_today'), Icons.confirmation_number_outlined, onTap: () => _open(BookingsScreen(templeId: t.id, todayOnly: true))),
                    _Stat('Received', n('received_today'), Icons.how_to_reg_outlined),
                    _Stat('Upcoming', n('bookings_upcoming'), Icons.event_available_outlined, onTap: () => _open(BookingsScreen(templeId: t.id))),
                    _Stat('Events ahead', n('events_upcoming'), Icons.celebration_outlined, onTap: () => _open(EventsScreen(templeId: t.id))),
                    _Stat('In review', n('events_in_review'), Icons.hourglass_top_outlined, onTap: () => _open(EventsScreen(templeId: t.id))),
                    _Stat('To answer', n('reviews_to_answer'), Icons.rate_review_outlined, onTap: () => _open(ReviewsScreen(templeId: t.id))),
                    _Stat('Followers', n('followers'), Icons.notifications_active_outlined),
                    _Stat('Likes', n('likes'), Icons.favorite_border),
                    _Stat('Check-ins', n('visits'), Icons.verified_outlined),
                  ],
                ),
                const SectionTitle('Manage'),
                _Tile(Icons.edit_note, 'Temple details', 'Contact, location, visitor rules', () => _open(ProfileEditScreen(temple: t))),
                _Tile(Icons.schedule, 'Darshan timings', 'Daily and weekday timings', () => _open(TimingsScreen(templeId: t.id))),
                _Tile(Icons.event_busy_outlined, 'Closures', 'Eclipses, renovations, special days', () => _open(ClosuresScreen(templeId: t.id))),
                _Tile(Icons.celebration_outlined, 'Events & festivals', 'Festivals, programs, announcements', () => _open(EventsScreen(templeId: t.id))),
                _Tile(Icons.local_fire_department_outlined, 'Pujas & sevas', '${n('sevas')} listed · fees and app booking', () => _open(SevasScreen(templeId: t.id))),
                _Tile(Icons.photo_library_outlined, 'Photos', '${n('photos')} photos', () => _open(PhotosScreen(templeId: t.id))),
                _Tile(Icons.confirmation_number_outlined, 'Seva bookings', 'Who is coming, by day', () => _open(BookingsScreen(templeId: t.id))),
                _Tile(Icons.rate_review_outlined, 'Devotee reviews', 'Read and reply', () => _open(ReviewsScreen(templeId: t.id))),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.onTap});

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              Text('$value', style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
