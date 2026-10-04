import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import '../temple/temple_dashboard_screen.dart';

/// Every temple, for a super admin: search, filter by status, open any one.
class AllTemplesScreen extends StatefulWidget {
  const AllTemplesScreen({super.key});

  @override
  State<AllTemplesScreen> createState() => _AllTemplesScreenState();
}

class _AllTemplesScreenState extends State<AllTemplesScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  String? _status;
  final List<TrustTemple> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  ApiException? _error;

  /// Status filters; each label is a key in [S].
  static const _statuses = [
    Option(null, 'filter_all'),
    Option('published', 'ad_status_published'),
    Option('in_review', 'in_review'),
    Option('draft', 'ad_status_draft'),
    Option('archived', 'ad_status_archived'),
  ];

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<Session>().api.get('temples',
          {'q': _q.text.trim(), 'status': _status, 'page': '$_page'});
      final data = [
        for (final t in res['data'] as List)
          TrustTemple.fromJson((t as Map).cast<String, dynamic>())
      ];
      final meta = (res['meta'] as Map?) ?? const {};
      setState(() {
        _items.addAll(data);
        _hasMore = (meta['current_page'] ?? 1) < (meta['last_page'] ?? 1);
        _page++;
      });
    } on ApiException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l('all_temples'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l('ad_search_temples')),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(
                  const Duration(milliseconds: 350), () => _fetch(reset: true));
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final s in _statuses)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(l(s.label)),
                    selected: _status == s.value,
                    onSelected: (_) {
                      setState(() => _status = s.value as String?);
                      _fetch(reset: true);
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _error != null && _items.isEmpty
              ? ErrorView(error: _error!, onRetry: () => _fetch(reset: true))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) {
                      _fetch();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        if (_loading) {
                          return const Padding(
                              padding: EdgeInsets.all(24),
                              child:
                                  Center(child: CircularProgressIndicator()));
                        }
                        return _items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(l('ad_no_temples_match'),
                                    textAlign: TextAlign.center))
                            : const SizedBox();
                      }
                      final t = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: const IconBadge(Icons.temple_hindu),
                            title: Text(t.name),
                            subtitle: Text([t.deity, t.place]
                                .where((e) => e != null && e.isNotEmpty)
                                .join(' · ')),
                            trailing: t.statusLabel == null
                                ? null
                                : StatusChip.forStatus(
                                    '${(t.raw['status'] as Map?)?['value']}',
                                    t.statusLabel!),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => TempleDashboardScreen(
                                          templeId: t.id, title: t.name)));
                              _fetch(reset: true);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
