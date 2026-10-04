import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/photo_crop.dart';
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
    final res = await context
        .read<Session>()
        .api
        .get('temples/${widget.templeId}/photos');
    return [
      for (final r in res['data'] as List) (r as Map).cast<String, dynamic>()
    ];
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _upload() async {
    final session = context.read<Session>();
    final s = S.of(context);
    final categories = session.options.photoCategories;
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 3000);
    if (picked.isEmpty || !mounted) return;

    final category = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text(s('tp_photos_category_q')),
        children: [
          for (final o in categories.isEmpty
              ? [Option('gallery', s('tp_gallery'))]
              : categories)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(c, '${o.value}'),
                child: Text(o.label)),
        ],
      ),
    );
    if (category == null) return;

    // Each photo is framed at 4:3 here, the shape devotees see it in.
    final cropped = <CroppedPhoto>[];
    for (final (i, f) in picked.indexed) {
      if (!mounted) return;
      final c = await cropPhoto(context, f,
          title: picked.length == 1
              ? s('tp_crop_photo')
              : s('tp_crop_photo_n', {'i': i + 1, 'n': picked.length}));
      if (c != null) cropped.add(c);
    }
    if (cropped.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    var done = 0;
    try {
      for (final c in cropped) {
        await session.api.multipart('temples/${widget.templeId}/photos',
            fields: {
              'category': category
            },
            files: [
              UploadFile(field: 'photo', filename: c.filename, bytes: c.bytes)
            ]);
        done++;
      }
    } on ApiException catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
        if (done > 0) {
          showMessage(
              context,
              done == 1
                  ? s('tp_photo_uploaded_one')
                  : s('tp_photos_uploaded_n', {'n': done}));
        }
        _reload();
      }
    }
  }

  Future<void> _options(Json p) async {
    final s = S.of(context);
    if (p['is_devotee_photo'] == true) {
      showMessage(context, s('tp_devotee_photo_note'));
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (p['is_primary'] != true)
            ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(s('tp_make_cover')),
                onTap: () => Navigator.pop(c, 'primary')),
          ListTile(
            leading: Icon(p['is_published'] == true
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            title: Text(p['is_published'] == true
                ? s('tp_hide_from_devotees')
                : s('tp_show_to_devotees')),
            onTap: () => Navigator.pop(c, 'toggle'),
          ),
          ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(s('tp_edit_caption')),
              onTap: () => Navigator.pop(c, 'caption')),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(s('tp_delete')),
              onTap: () => Navigator.pop(c, 'delete')),
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
              title: Text(s('tp_caption')),
              content: TextField(controller: c, autofocus: true),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(d, c.text),
                    child: Text(s('save')))
              ],
            ),
          );
          if (v == null) return;
          await api
              .patch(path, {'caption': v.trim().isEmpty ? null : v.trim()});
        case 'delete':
          if (!mounted ||
              !await confirm(context, s('tp_delete_photo_q'),
                  action: s('tp_delete'))) {
            return;
          }
          await api.delete(path);
      }
      _reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('photos'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _upload,
        icon: _uploading
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_a_photo_outlined),
        label: Text(_uploading ? s('uploading') : s('tp_upload')),
      ),
      body: FutureBuilder<List<Json>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final photos = snap.data!;
          if (photos.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(s('tp_photos_empty'),
                        textAlign: TextAlign.center)));
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
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final p = photos[i];
                final urls = (p['urls'] as Map?) ?? const {};
                return GestureDetector(
                  onTap: () => _options(p),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(
                          '${urls['thumbnail'] ?? urls['medium'] ?? urls['original']}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Colors.black12,
                              child: Icon(Icons.image_not_supported_outlined))),
                      if (p['is_published'] != true)
                        const ColoredBox(color: Color(0x88000000)),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Wrap(spacing: 4, children: [
                          if (p['is_primary'] == true) _Badge(s('tp_cover')),
                          if (p['is_published'] != true) _Badge(s('tp_hidden')),
                          if (p['is_devotee_photo'] == true)
                            _Badge(s('tp_devotee')),
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
      decoration: BoxDecoration(
          color: Colors.black54, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
