import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'l10n.dart';
import 'models.dart';
import 'widgets.dart';

/// Shares the temple's page on the website (timings, sevas, events and the
/// online hundi) through WhatsApp, SMS or any app on the phone. A temple not
/// yet published has no public page, so there is nothing to share yet.
Future<void> shareTemple(BuildContext context, TrustTemple temple) async {
  final s = S.of(context);
  final url = temple.publicUrl;
  if (url == null) {
    showMessage(context, s('share_unpublished'));
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    text: s('share_text', {'name': temple.name, 'url': url}),
    subject: temple.name,
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}
