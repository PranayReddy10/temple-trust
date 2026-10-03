import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/photo_crop.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
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

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};

/// One temple: today at a glance, the money, then everything the team manages.
class TempleDashboardScreen extends StatefulWidget {
  const TempleDashboardScreen({super.key, required this.templeId, required this.title});

  final int templeId;
  final String title;

  @override
  State<TempleDashboardScreen> createState() => _TempleDashboardScreenState();
}

class _TempleDashboardScreenState extends State<TempleDashboardScreen> {
  late Future<TrustTemple> _future = _load();
  late Future<Json?> _finance = _loadFinance();
  bool _coverBusy = false;

  Future<TrustTemple> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}');
    return TrustTemple.fromJson((res['data'] as Map).cast<String, dynamic>());
  }

  /// The month and the balance, for the report card; null when it cannot be
  /// read, and the card simply points to the finance screen.
  Future<Json?> _loadFinance() async {
    try {
      final res = await context.read<Session>().api.get('temples/${widget.templeId}/finance');
      return _map(res['data']);
    } on ApiException {
      return null;
    }
  }

  void _reload() => setState(() {
        _future = _load();
        _finance = _loadFinance();
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
          ListTile(leading: const IconBadge(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const IconBadge(Icons.photo_library_outlined), title: const Text('Choose from the phone'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(leading: const IconBadge(Icons.collections_outlined), title: const Text('Pick one already uploaded'), onTap: () => Navigator.pop(c, 'existing')),
          const SizedBox(height: 8),
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
    // Framed at 4:3 first: the cover is seen at that shape on the devotee's
    // home screen and the temple page.
    final cropped = await cropPhoto(context, f, title: 'Crop the cover');
    if (cropped == null || !mounted) return;
    setState(() => _coverBusy = true);
    try {
      await context.read<Session>().api.multipart('temples/${t.id}/photos', fields: {
        'category': 'exterior',
        'is_primary': true,
        'is_published': true,
      }, files: [
        UploadFile(field: 'photo', filename: cropped.filename, bytes: cropped.bytes)
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
    final s = S.of(context);
    final theme = Theme.of(context);
    final isAdmin = context.watch<Session>().isSuperAdmin;
    return Scaffold(
      body: FutureBuilder<TrustTemple>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return Column(children: [
              AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
              const Expanded(child: Center(child: CircularProgressIndicator())),
            ]);
          }
          if (snap.hasError) {
            return Column(children: [
              AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
              Expanded(child: ErrorView(error: snap.error!, onRetry: _reload)),
            ]);
          }
          final t = snap.data!;
          final st = t.stats;
          int n(String k) => (st[k] as num?)?.toInt() ?? 0;
          final statusValue = '${(t.raw['status'] as Map?)?['value']}';
          final payments = st['payments'];

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 240,
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  foregroundColor: theme.colorScheme.onSurface,
                  actions: [
                    if (isAdmin)
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
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final collapsed = constraints.maxHeight <= kToolbarHeight + MediaQuery.paddingOf(context).top + 8;
                      return FlexibleSpaceBar(
                        titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 56),
                        centerTitle: false,
                        title: AnimatedOpacity(
                          opacity: collapsed ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                        ),
                        stretchModes: const [StretchMode.zoomBackground],
                        background: _Cover(temple: t, busy: _coverBusy, onChange: () => _changeCover(t)),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  sliver: SliverList.list(children: [
                    Text(t.name, style: theme.textTheme.headlineSmall),
                    if (_address(t).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.place_outlined, size: 17, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_address(t), style: theme.textTheme.bodySmall)),
                        ]),
                      ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      if (t.statusLabel != null) StatusChip.forStatus(statusValue, t.statusLabel!),
                      if (t.trustLabel != null) StatusChip(t.trustLabel!, icon: Icons.verified_outlined),
                      if (t.deity != null) StatusChip(t.deity!, color: theme.colorScheme.tertiary),
                    ]),
                    const SizedBox(height: 14),
                    if (statusValue != 'published') InfoBanner(icon: Icons.visibility_off_outlined, title: s('in_review'), body: s('not_visible_yet'), color: Palette.sky),
                    if (payments == 'rejected')
                      RejectionNotice(
                        reason: st['payments_rejection_reason'] as String?,
                        onTap: () => _open(PaymentsVerificationScreen(templeId: t.id)),
                      )
                    else if (payments != null && payments != 'approved')
                      InfoBanner(
                        icon: Icons.verified_user_outlined,
                        title: payments == 'pending' ? s('payments_checking') : s('payments_setup'),
                        body: payments == 'pending' ? s('payments_checking_body') : s('payments_setup_body'),
                        color: payments == 'pending' ? const Color(0xFFB08A10) : Palette.saffron,
                        onTap: () => _open(PaymentsVerificationScreen(templeId: t.id)),
                      ),

                    // Today, in one panel: who is coming and what they paid.
                    SectionTitle(s('today')),
                    HeroPanel(
                      onTap: () => _open(BookingsScreen(templeId: t.id, todayOnly: true)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s('paid_today_sevas').toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(rupees(st['amount_today_paise']), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 34, fontWeight: FontWeight.w600, height: 1.1)),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          _HeroFigure(s('bookings'), '${n('bookings_today')}'),
                          _HeroFigure(s('people'), '${n('people_today')}'),
                          _HeroFigure(s('received'), '${n('received_today')}'),
                          _HeroFigure(s('upcoming'), '${n('bookings_upcoming')}'),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    SoftCard(
                      onTap: () => _open(DonationsScreen(templeId: t.id)),
                      child: Row(children: [
                        const IconBadge(Icons.volunteer_activism_outlined, color: Palette.gold, size: 44),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Figure(
                            s('hundi_today'),
                            rupees(st['hundi_today_paise']),
                            color: const Color(0xFF8A6A00),
                            caption: payments != null && payments != 'approved'
                                ? s('opens_after_approval')
                                : st['hundi_enabled'] == false
                                    ? s('hundi_off')
                                    : '${s('n_gifts', {'n': n('hundi_today_count')})} · ${rupees(st['hundi_month_paise'])} ${s('this_month').toLowerCase()}',
                          ),
                        ),
                        Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                      ]),
                    ),

                    // The money, in short: this month and what is due.
                    SectionTitle(
                      s('financial_report'),
                      trailing: TextButton(onPressed: () => _open(FinanceScreen(templeId: t.id, title: t.name)), child: Text(s('see_all'))),
                    ),
                    FutureBuilder<Json?>(
                      future: _finance,
                      builder: (context, fin) => _ReportCard(
                        finance: fin.data,
                        loading: fin.connectionState != ConnectionState.done,
                        onOpen: () => _open(FinanceScreen(templeId: t.id, title: t.name)),
                      ),
                    ),
                    if (st['fee_percent'] != null) ...[
                      const SizedBox(height: 10),
                      FeeShareCard(feePercent: st['fee_percent'], donationFeePercent: st['donation_fee_percent'], compact: true),
                    ],

                    SectionTitle(s('at_a_glance')),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.98,
                      children: [
                        MetricTile(label: s('events_ahead'), value: '${n('events_upcoming')}', icon: Icons.celebration_outlined, color: Palette.saffron, onTap: () => _open(EventsScreen(templeId: t.id))),
                        MetricTile(label: s('in_review'), value: '${n('events_in_review')}', icon: Icons.hourglass_top_outlined, color: const Color(0xFFB08A10), onTap: () => _open(EventsScreen(templeId: t.id))),
                        MetricTile(label: s('to_answer'), value: '${n('reviews_to_answer')}', icon: Icons.rate_review_outlined, color: Palette.sky, onTap: () => _open(ReviewsScreen(templeId: t.id))),
                        MetricTile(label: s('followers'), value: '${n('followers')}', icon: Icons.notifications_active_outlined, color: Palette.kumkum),
                        MetricTile(label: s('likes'), value: '${n('likes')}', icon: Icons.favorite_border, color: const Color(0xFFD1476B)),
                        MetricTile(label: s('check_ins'), value: '${n('visits')}', icon: Icons.verified_outlined, color: Palette.tulsi),
                      ],
                    ),

                    SectionTitle(s('at_the_counter')),
                    HeroPanel(
                      gradient: Palette.saffronGradient,
                      onTap: () => _open(const ScanScreen()),
                      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                      child: Row(children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.qr_code_scanner, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s('scan_at_counter'), style: const TextStyle(fontFamily: TrustTheme.serif, fontSize: 19, fontWeight: FontWeight.w600)),
                            Text(s('scan_hint'), style: const TextStyle(fontSize: 12.5)),
                          ]),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    ActionTile(icon: Icons.person_search_outlined, color: Palette.sky, title: s('find_booking'), subtitle: s('find_booking_long'), onTap: () => _open(const FindBookingScreen())),

                    SectionTitle(s('manage')),
                    ActionTile(icon: Icons.confirmation_number_outlined, color: Palette.tulsi, title: s('seva_bookings'), subtitle: s('seva_bookings_hint'), onTap: () => _open(BookingsScreen(templeId: t.id))),
                    ActionTile(icon: Icons.account_balance_wallet_outlined, title: s('finance'), subtitle: s('finance_hint'), onTap: () => _open(FinanceScreen(templeId: t.id, title: t.name))),
                    ActionTile(icon: Icons.volunteer_activism_outlined, color: Palette.gold, title: s('online_hundi'), subtitle: s('hundi_hint'), onTap: () => _open(DonationsScreen(templeId: t.id))),
                    ActionTile(icon: Icons.local_fire_department_outlined, color: Palette.saffron, title: s('pujas_sevas'), subtitle: s('sevas_hint', {'n': n('sevas')}), onTap: () => _open(SevasScreen(templeId: t.id))),
                    ActionTile(icon: Icons.celebration_outlined, color: const Color(0xFFD1476B), title: s('events'), subtitle: s('events_hint'), onTap: () => _open(EventsScreen(templeId: t.id))),
                    ActionTile(icon: Icons.schedule, color: Palette.sky, title: s('darshan_timings'), subtitle: s('timings_hint'), onTap: () => _open(TimingsScreen(templeId: t.id))),
                    ActionTile(icon: Icons.event_busy_outlined, color: const Color(0xFF8D6E63), title: s('closures'), subtitle: s('closures_hint'), onTap: () => _open(ClosuresScreen(templeId: t.id))),
                    ActionTile(icon: Icons.edit_note, title: s('temple_details'), subtitle: s('temple_details_hint'), onTap: () => _open(ProfileEditScreen(temple: t))),
                    ActionTile(icon: Icons.photo_library_outlined, color: Palette.tulsi, title: s('photos'), subtitle: s('n_photos', {'n': n('photos')}), onTap: () => _open(PhotosScreen(templeId: t.id))),
                    ActionTile(icon: Icons.rate_review_outlined, color: Palette.sky, title: s('reviews'), subtitle: s('reviews_hint'), badge: n('reviews_to_answer') > 0 ? '${n('reviews_to_answer')}' : null, onTap: () => _open(ReviewsScreen(templeId: t.id))),
                    ActionTile(icon: Icons.qr_code_2, color: Palette.deep, title: s('temple_qr'), subtitle: s('temple_qr_hint'), onTap: () => _open(TempleQrScreen(templeId: t.id, title: t.name))),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.1)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// This month's takings and what is due to the temple, from the finance
/// endpoint; a pointer to the full report while it loads or if it cannot.
class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.finance, required this.loading, required this.onOpen});

  final Json? finance;
  final bool loading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final f = finance;
    if (f == null) {
      return ActionTile(
        icon: Icons.insert_chart_outlined,
        title: s('financial_report'),
        subtitle: s('full_report_hint'),
        onTap: onOpen,
        trailing: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      );
    }
    final month = _map(f['month']);
    final balance = _map(f['balance']);
    final ready = _map(balance['ready']);
    final paid = _map(balance['paid']);
    final allTime = f['all_time'] == null ? null : _map(f['all_time']);
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return SoftCard(
      onTap: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Figure(s('this_month'), rupees(month['total_paise'] ?? month['amount_paise']), emphasis: true, color: theme.colorScheme.primary, caption: '${s('n_bookings', {'n': n(month['bookings'])})} · ${s.people(n(month['people']))}')),
          Expanded(child: Figure(s('due_to_temple'), rupees(ready['net_paise']), emphasis: true, color: Palette.tulsi, caption: s('n_bookings', {'n': n(ready['bookings'])}))),
        ]),
        const Divider(height: 22),
        Row(children: [
          Expanded(child: Figure(s('paid_to_date'), rupees(paid['net_paise']), caption: s('n_settlements', {'n': n(paid['settlements'])}))),
          Expanded(
            child: allTime == null
                ? Figure(s('event_tickets'), rupees(_map(month['tickets'])['amount_paise']), caption: s('n_tickets', {'n': n(_map(month['tickets'])['count'])}))
                : Figure(s('all_time'), rupees(allTime['total_paise']), caption: s('n_bookings', {'n': n(allTime['bookings'])})),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.insert_chart_outlined, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(s('full_report_hint'), style: theme.textTheme.bodySmall)),
          Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ]),
      ]),
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
    final s = S.of(context);
    return Stack(fit: StackFit.expand, children: [
      if (temple.imageUrl != null)
        Image.network(temple.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const DecoratedBox(decoration: BoxDecoration(gradient: Palette.kumkumGradient)))
      else
        DecoratedBox(
          decoration: const BoxDecoration(gradient: Palette.kumkumGradient),
          child: Icon(Icons.temple_hindu, size: 72, color: Colors.white.withValues(alpha: 0.4)),
        ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.45, 1], colors: [Color(0x66000000), Colors.transparent, Color(0x80000000)]),
        ),
      ),
      Positioned(
        right: 12,
        bottom: 12,
        child: FilledButton.tonalIcon(
          style: FilledButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.9), foregroundColor: Palette.deep, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          onPressed: busy ? null : onChange,
          icon: busy ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(busy ? s('uploading') : (temple.imageUrl == null ? s('add_cover') : s('change_cover'))),
        ),
      ),
    ]);
  }
}
