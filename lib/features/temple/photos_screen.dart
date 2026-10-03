import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// The temple's own photographs. Display sizes are made on the server.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  late Future<List<Json>> _future = _load();
  bool _uploading = false;

  Future<List<Json>> _load() async {
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/photos');
    return [for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()];
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _upload() async {
    final session = context.read<Session>();
    final categories = session.options.photoCategories;
    final picked = await ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 3000);
    if (picked.isEmpty || !mounted) return;

    final category = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('What do these show?'),
        children: [
          for (final o in categories.isEmpty ? const [Option('gallery', 'Gallery')] : categories)
            SimpleDialogOption(onPressed: () => Navigator.pop(c, '${o.value}'), child: Text(o.label)),
        ],
      ),
    );
    if (category == null) return;

    setState(() => _uploading = true);
    var done = 0;
    try {
      for (final f in picked) {
        await session.api.multipart('temples/${widget.templeId}/photos',
            fields: {'category': category}, files: [UploadFile(field: 'photo', filename: f.name, bytes: await f.readAsBytes())]);
        done++;
      }
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
        if (done > 0) showMessage(context, '$done photo${done == 1 ? '' : 's'} uploaded.');
        _reload();
      }
    }
  }

  Future<void> _options(Json p) async {
    if (p['is_devotee_photo'] == true) {
      showMessage(context, 'Shared by a devotee. Raise an objection from the temple portal if it should not be shown.');
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p['is_primary'] != true)
            ListTile(leading: const Icon(Icons.star_outline), title: const Text('Make cover photo'), onTap: () => Navigator.pop(c, 'primary')),
          ListTile(
            leading: Icon(p['is_published'] == true ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            title: Text(p['is_published'] == true ? 'Hide from devotees' : 'Show to devotees'),
            onTap: () => Navigator.pop(c, 'toggle'),
          ),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit caption'), onTap: () => Navigator.pop(c, 'caption')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(c, 'delete')),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final api = context.read<Session>().api;
    final path = 'temples/${widget.templeId}/photos/${p['id']}';
    try {
      switch (action) {
        case 'primary':
          await api.patch(path, {'is_primary': true});
        case 'toggle':
          await api.patch(path, {'is_published': p['is_published'] != true});
        case 'caption':
          final c = TextEditingController(text: p['caption'] ?? '');
          final v = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Caption'),
              content: TextField(controller: c, autofocus: true),
              actions: [FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Save'))],
            ),
          );
          if (v == null) return;
          await api.patch(path, {'caption': v.trim().isEmpty ? null : v.trim()});
        case 'delete':
          if (!mounted || !await confirm(context, 'Delete this photo?')) return;
          await api.delete(path);
      }
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
        label: Text(_uploading ? 'Uploading…' : 'Upload'),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final photos = snap.data!;
          if (photos.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No photos yet. The first one you upload becomes the cover.', textAlign: TextAlign.center)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final p = photos[i];
                final urls = (p['urls'] as Map?) ?? const {};
                return GestureDetector(
                  onTap: () => _options(p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network('${urls['thumbnail'] ?? urls['medium'] ?? urls['original']}', fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12, child: Icon(Icons.image_not_supported_outlined))),
                      if (p['is_published'] != true) const ColoredBox(color: Color(0x88000000)),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Wrap(spacing: 4, children: [
                          if (p['is_primary'] == true) const _Badge('Cover'),
                          if (p['is_published'] != true) const _Badge('Hidden'),
                          if (p['is_devotee_photo'] == true) const _Badge('Devotee'),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
