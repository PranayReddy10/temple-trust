import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
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

  static const _statuses = [
    Option(null, 'All'),
    Option('published', 'Published'),
    Option('in_review', 'In review'),
    Option('draft', 'Draft'),
    Option('archived', 'Archived'),
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
      final res = await context.read<Session>().api.get('temples', {'q': _q.text.trim(), 'status': _status, 'page': '$_page'});
      final data = [for (final t in res['data'] as List) TrustTemple.fromJson((t as Map).cast<String, dynamic>())];
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
    return Scaffold(
      appBar: AppBar(title: const Text('All temples')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Name, local name or town'),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(reset: true));
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
                    label: Text(s.label),
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
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _fetch();
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _items.length + 1,
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        if (_loading) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                        return _items.isEmpty ? const Padding(padding: EdgeInsets.all(32), child: Text('No temples match.', textAlign: TextAlign.center)) : const SizedBox();
                      }
                      final t = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            title: Text(t.name),
                            subtitle: Text([t.deity, t.place].where((e) => e != null && e.isNotEmpty).join(' · ')),
                            trailing: t.statusLabel == null ? null : StatusChip.forStatus('${(t.raw['status'] as Map?)?['value']}', t.statusLabel!),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => TempleDashboardScreen(templeId: t.id, title: t.name)));
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
