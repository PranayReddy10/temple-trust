import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session.dart';
import '../../core/widgets.dart';

typedef Json = Map<String, dynamic>;

/// The temple's check-in code, to show at the gate: devotees scan it with
/// the Darshan Saathi app to collect the temple's stamp in their passport.
/// The code is signed by the server, so one copied for another temple does
/// not verify. The printable A4 poster opens on the web.
class TempleQrScreen extends StatefulWidget {
  const TempleQrScreen({super.key, required this.templeId, required this.title});

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
    final res = await context.read<Session>().api.get('temples/${widget.templeId}/qr');
    return (res['data'] as Map).cast<String, dynamic>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Temple QR code')),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: () => setState(() => _retry()));
          }
          final q = snap.data!;
          final url = '${q['url']}';
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Text(widget.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Check in with Darshan Saathi', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
                  child: QrImageView(data: url, size: 260, backgroundColor: Colors.white, semanticsLabel: 'Check-in code for ${widget.title}'),
                ),
              ),
              if (q['is_published'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Your temple is not published yet: devotees can collect its stamp once it is.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              const Text(
                'Display this at the gate or the counter. Devotees scan it with the Darshan Saathi app to collect your temple\'s stamp in their passport. '
                'It is signed for your temple: a copy for any other temple does not verify.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('${q['print_url']}'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print the A4 poster'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) showMessage(context, 'Link copied.');
                },
                icon: const Icon(Icons.link),
                label: const Text('Copy the link'),
              ),
              const SizedBox(height: 8),
              const Text('The poster opens in your browser; sign in with the same email and password if it asks.', textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}
