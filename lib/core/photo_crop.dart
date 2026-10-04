import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'theme.dart';

/// The shape every temple photo is shown in: 4:3, on the devotee app's home
/// cards and the temple page's header alike. A photo is cropped to it here,
/// on the phone, before it is uploaded, so what the team frames is what
/// devotees see.
const double photoAspect = 4 / 3;

/// The longest side kept after the crop; the server makes its own 1200 px
/// copy from this.
const int photoMaxWidth = 1600;

/// A photo ready to upload: the cropped JPEG and a name for it.
class CroppedPhoto {
  const CroppedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Opens the cropper for a picked photo and returns the 4:3 JPEG, or null
/// when the team backs out.
Future<CroppedPhoto?> cropPhoto(BuildContext context, XFile file, {String? title}) async {
  final bytes = await file.readAsBytes();
  if (!context.mounted) return null;
  final out = await Navigator.push<Uint8List>(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => CropScreen(bytes: bytes, title: title)));
  if (out == null) return null;
  final base = file.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
  return CroppedPhoto(bytes: out, filename: '$base.jpg');
}

/// Decodes, straightens (EXIF orientation) and brings a photo down to a
/// workable size, so the cropper has true pixel dimensions to go by.
Future<_Prepared> _prepare(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not a photo the app can read.');
  var image = img.bakeOrientation(decoded);
  if (image.width > 2400) image = img.copyResize(image, width: 2400, interpolation: img.Interpolation.linear);
  return _Prepared(Uint8List.fromList(img.encodeJpg(image, quality: 92)), image.width, image.height);
}

class _Prepared {
  const _Prepared(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Crops the prepared photo to the rect (in its own pixels), keeps it to
/// [photoMaxWidth], and encodes the JPEG that is uploaded.
Future<Uint8List> _crop(_CropJob job) async {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) throw const FormatException('Not a photo the app can read.');
  var image = img.copyCrop(decoded, x: job.x, y: job.y, width: job.width, height: job.height);
  if (image.width > photoMaxWidth) image = img.copyResize(image, width: photoMaxWidth, interpolation: img.Interpolation.linear);
  return Uint8List.fromList(img.encodeJpg(image, quality: 88));
}

class _CropJob {
  const _CropJob(this.bytes, this.x, this.y, this.width, this.height);

  final Uint8List bytes;
  final int x;
  final int y;
  final int width;
  final int height;
}

/// Pinch and drag the photo inside a 4:3 frame; what shows in the frame is
/// what is uploaded.
class CropScreen extends StatefulWidget {
  const CropScreen({super.key, required this.bytes, this.title});

  final Uint8List bytes;
  final String? title;

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = TransformationController();
  late final Future<_Prepared> _prepared = compute(_prepare, widget.bytes);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _done(_Prepared p, Size frame, double base) async {
    setState(() => _busy = true);
    try {
      // The viewport's corners, back in the photo's own pixels.
      final inverse = Matrix4.inverted(_controller.value);
      final tl = MatrixUtils.transformPoint(inverse, Offset.zero);
      final br = MatrixUtils.transformPoint(inverse, Offset(frame.width, frame.height));
      final x = (tl.dx / base).round().clamp(0, p.width - 1);
      final y = (tl.dy / base).round().clamp(0, p.height - 1);
      final w = ((br.dx - tl.dx) / base).round().clamp(1, p.width - x);
      final h = ((br.dy - tl.dy) / base).round().clamp(1, p.height - y);
      final out = await compute(_crop, _CropJob(p.bytes, x, y, w, h));
      if (mounted) Navigator.pop(context, out);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not crop this photo: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Palette.ebony,
      appBar: AppBar(
        backgroundColor: Palette.ebony,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Crop to 4:3'),
      ),
      body: FutureBuilder<_Prepared>(
        future: _prepared,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center)));
          }
          final p = snap.data;
          if (p == null) return const Center(child: CircularProgressIndicator(color: Colors.white));
          return LayoutBuilder(
            builder: (context, box) {
              final frameW = box.maxWidth;
              final frameH = frameW / photoAspect;
              final frame = Size(frameW, frameH);
              // The photo covers the frame at scale 1; it can only grow from there.
              final base = [frameW / p.width, frameH / p.height].reduce((a, b) => a > b ? a : b);
              return Column(
                children: [
                  const Spacer(),
                  ClipRect(
                    child: SizedBox(
                      width: frameW,
                      height: frameH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _controller,
                            constrained: false,
                            minScale: 1,
                            maxScale: 6,
                            panEnabled: true,
                            child: SizedBox(
                              width: p.width * base,
                              height: p.height * base,
                              child: Image.memory(p.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(painter: _GridPainter(color: Colors.white.withValues(alpha: 0.35))),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Pinch to zoom, drag to move. What is in the frame is what devotees see on the home screen and the temple page.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 16),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                          onPressed: _busy ? null : () => _controller.value = Matrix4.identity(),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _done(p, frame, base),
                          icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check),
                          label: Text(_busy ? 'Cropping…' : 'Use this crop'),
                        ),
                      ),
                    ]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Thirds, so the gopuram or the deity can be placed with intent.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), paint);
    }
    canvas.drawRect(Offset.zero & size, paint..color = Palette.gold..strokeWidth = 2..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}
