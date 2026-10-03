import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';

import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../counter/find_booking_screen.dart';
import '../counter/scan_screen.dart';
import 'bookings_screen.dart';
import 'closures_screen.dart';
import 'donations_screen.dart';
import 'events_screen.dart';
import 'finance_screen.dart';
import 'payments_verification_screen.dart';
import 'photos_screen.dart';
import 'profile_edit_screen.dart';
import 'reviews_screen.dart';
import 'sevas_screen.dart';
import 'temple_qr_screen.dart';
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
  bool _coverBusy = false;

  Future<TrustTemple> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}');
    return TrustTemple.fromJson((res['data'] as Map).cast<String, dynamic>());
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _setStatus(String status) async {
    try {
      await context.read<Session>().api.patch('admin/temples/${widget.templeId}/status', {'status': status});
      if (mounted) showMessage(context, 'Listing status updated.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// The cover devotees see first: a new photo straight from the phone, or
  /// one already uploaded.
  Future<void> _changeCover(TrustTemple t) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Cover photo'), subtitle: Text('The first picture devotees see of the temple.')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from the phone'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(leading: const Icon(Icons.collections_outlined), title: const Text('Pick one already uploaded'), onTap: () => Navigator.pop(c, 'existing')),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'existing') {
      showMessage(context, 'Tap a photo, then "Make cover photo".');
      return _open(PhotosScreen(templeId: t.id));
    }
    final f = await ImagePicker().pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
    if (f == null || !mounted) return;
    setState(() => _coverBusy = true);
    try {
      await context.read<Session>().api.multipart('temples/${t.id}/photos', fields: {
        'category': 'exterior',
        'is_primary': true,
        'is_published': true,
      }, files: [
        UploadFile(field: 'photo', filename: f.name, bytes: await f.readAsBytes())
      ]);
      if (mounted) showMessage(context, 'Cover photo changed.');
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          // A super admin moves a temple between draft, review and published.
          if (context.watch<Session>().isSuperAdmin)
            PopupMenuButton<String>(
              tooltip: 'Listing status',
              icon: const Icon(Icons.publish_outlined),
              onSelected: _setStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'published', child: Text('Publish')),
                PopupMenuItem(value: 'in_review', child: Text('Move to review')),
                PopupMenuItem(value: 'draft', child: Text('Back to draft')),
                PopupMenuItem(value: 'archived', child: Text('Archive')),
              ],
            ),
        ],
      ),
      body: FutureBuilder<TrustTemple>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final t = snap.data!;
          final s = t.stats;
          int n(String k) => (s[k] as num?)?.toInt() ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Cover(temple: t, busy: _coverBusy, onChange: () => _changeCover(t)),
                if (_address(t).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.place_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_address(t), style: Theme.of(context).textTheme.bodyMedium)),
                    ]),
                  ),
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
                if (s['payments'] == 'rejected')
                  RejectionNotice(
                    reason: s['payments_rejection_reason'] as String?,
                    onTap: () => _open(PaymentsVerificationScreen(templeId: t.id)),
                  )
                else if (s['payments'] != null && s['payments'] != 'approved')
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(switch ('${s['payments']}') {
                        'pending' => 'Payments: being checked',
                        'rejected' => 'Payments: not approved',
                        _ => 'Take money in the app',
                      }),
                      subtitle: Text(switch ('${s['payments']}') {
                        'pending' => 'Paid sevas, tickets and the hundi open once our team approves your details.',
                        'rejected' => 'See why, fix it and send again.',
                        _ => 'For paid sevas, paid tickets or the online hundi: add the bank account, Aadhaar, temple proof and your photo.',
                      }),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(PaymentsVerificationScreen(templeId: t.id)),
                    ),
                  ),
                const SectionTitle('Today'),
                // Who is coming today and what they paid, at a glance.
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(FinanceScreen(templeId: t.id, title: t.name)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                          child: Figure(
                            'Paid for today\'s sevas',
                            rupees(s['amount_today_paise']),
                            emphasis: true,
                            color: Theme.of(context).colorScheme.primary,
                            caption: '${n('bookings_today')} bookings · ${n('people_today')} people',
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
                ),
                // Online hundi: what devotees gave in the app today and this month.
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _open(DonationsScreen(templeId: t.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Expanded(
                          child: Figure(
                            'Hundi today',
                            rupees(s['hundi_today_paise']),
                            emphasis: true,
                            color: Theme.of(context).colorScheme.secondary,
                            caption: s['payments'] != null && s['payments'] != 'approved'
                                ? 'Opens after payments are approved'
                                : s['hundi_enabled'] == false
                                    ? 'Online hundi is off'
                                    : '${n('hundi_today_count')} gifts · ${rupees(s['hundi_month_paise'])} this month',
                          ),
                        ),
                        const Icon(Icons.volunteer_activism_outlined),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right),
                      ]),
                    ),
                  ),
                ),
                if (s['fee_percent'] != null) ...[
                  const SizedBox(height: 4),
                  FeeShareCard(feePercent: s['fee_percent'], donationFeePercent: s['donation_fee_percent'], compact: true),
                ],
                const SizedBox(height: 10),
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
                _Tile(Icons.celebration_outlined, 'Events & festivals', 'Festivals, bhajans, programs; tickets and who is coming', () => _open(EventsScreen(templeId: t.id))),
                _Tile(Icons.local_fire_department_outlined, 'Pujas & sevas', '${n('sevas')} listed · fees and app booking', () => _open(SevasScreen(templeId: t.id))),
                _Tile(Icons.photo_library_outlined, 'Photos', '${n('photos')} photos', () => _open(PhotosScreen(templeId: t.id))),
                _Tile(Icons.confirmation_number_outlined, 'Seva bookings', 'Who is coming, by day', () => _open(BookingsScreen(templeId: t.id))),
                _Tile(Icons.account_balance_wallet_outlined, 'Finance', 'Amounts by day, payouts, payout account', () => _open(FinanceScreen(templeId: t.id, title: t.name))),
                _Tile(Icons.volunteer_activism_outlined, 'Online hundi', 'Gifts from devotees in the app', () => _open(DonationsScreen(templeId: t.id))),
                _Tile(Icons.rate_review_outlined, 'Devotee reviews', 'Read and reply', () => _open(ReviewsScreen(templeId: t.id))),
                _Tile(Icons.qr_code_2, 'Temple QR code', 'Check-in code for the gate; print the poster', () => _open(TempleQrScreen(templeId: t.id, title: t.name))),
                _Tile(Icons.person_search_outlined, 'Find a booking', 'Devotee without a phone: by mobile number, reference or name', () => _open(const FindBookingScreen())),
                _Tile(Icons.qr_code_scanner, 'Scan at counter', 'Seva bookings, event tickets, and stamping a devotee\'s passport', () => _open(const ScanScreen())),
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

/// Address, town, district, state and PIN, as devotees see it.
String _address(TrustTemple t) {
  final p = t.profile;
  final parts = <String>[];
  for (final k in ['address', 'city', 'district', 'state']) {
    final v = '${p[k] ?? (k == 'state' ? t.state ?? '' : '')}'.trim();
    if (v.isNotEmpty && v != 'null' && !parts.any((e) => e.toLowerCase() == v.toLowerCase())) parts.add(v);
  }
  if ('${p['pincode'] ?? ''}'.trim().isNotEmpty) parts.add('PIN ${p['pincode']}');
  return parts.join(', ');
}

class _Cover extends StatelessWidget {
  const _Cover({required this.temple, required this.busy, required this.onChange});

  final TrustTemple temple;
  final bool busy;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            if (temple.imageUrl != null)
              Image.network(temple.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: theme.colorScheme.surfaceContainerHighest))
            else
              ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.temple_hindu, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              ),
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.tonalIcon(
                onPressed: busy ? null : onChange,
                icon: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(busy ? 'Uploading…' : (temple.imageUrl == null ? 'Add cover photo' : 'Change cover')),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
