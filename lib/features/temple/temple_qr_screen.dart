import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// The temple's check-in code, to show at the gate: devotees scan it with
/// the Darshan Saathi app to collect the temple's stamp in their passport.
/// The code is signed by the server, so one copied for another temple does
/// not verify. The printable A4 poster opens on the web.
class TempleQrScreen extends StatefulWidget {
  const TempleQrScreen(
      {super.key, required this.templeId, required this.title});

  final int templeId;
  final String title;

  @override
  State<TempleQrScreen> createState() => _TempleQrScreenState();
}

class _TempleQrScreenState extends State<TempleQrScreen> {
  late Future<Json> _future = _load();

  void _retry() {
    _future = _load();
  }

  Future<Json> _load() async {
    final res =
        await context.read<Session>().api.get('temples/${widget.templeId}/qr');
    return (res['data'] as Map).cast<String, dynamic>();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('temple_qr'))),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(
                error: snap.error!, onRetry: () => setState(() => _retry()));
          }
          final q = snap.data!;
          final url = '${q['url']}';
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(s('tp_qr_check_in'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Palette.gold.withValues(alpha: 0.6), width: 2),
                    boxShadow: TrustStyle.of(context).cardShadow,
                  ),
                  child: QrImageView(
                      data: url,
                      size: 250,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square, color: Palette.deep),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Palette.deep),
                      semanticsLabel:
                          s('tp_qr_semantics', {'name': widget.title})),
                ),
              ),
              if (q['is_published'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(s('tp_qr_not_published'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Text(
                s('tp_qr_display_note'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('${q['print_url']}'),
                    mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.print_outlined),
                label: Text(s('tp_qr_print')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    showMessage(context, s('tp_link_copied'));
                  }
                },
                icon: const Icon(Icons.link),
                label: Text(s('tp_copy_link')),
              ),
              const SizedBox(height: 8),
              Text(s('tp_qr_poster_note'), textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}
