import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import 'finance_screen.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};

const _proofKinds = [
  Option('trust_registration', 'Trust / society registration certificate'),
  Option('endowments_letter', 'Endowments department order or letter'),
  Option('committee_letter', 'Temple committee resolution or letter'),
  Option('property_document', 'Temple land or property document'),
  Option('other', 'Other official document'),
];

/// Before devotees can pay the temple in the app — paid sevas, paid event
/// tickets, the online hundi — the owner gives the bank details and proves
/// who they are: Aadhaar, a document showing the temple is theirs to
/// represent, and a photo. The team checks and approves; until then nobody
/// can pay, so nobody can collect money in a temple's name falsely.
class PaymentsVerificationScreen extends StatefulWidget {
  const PaymentsVerificationScreen({super.key, required this.templeId});

  final int templeId;

  @override
  State<PaymentsVerificationScreen> createState() => _PaymentsVerificationScreenState();
}

class _PaymentsVerificationScreenState extends State<PaymentsVerificationScreen> {
  late Future<Json> _future = _load();
  final _name = TextEditingController();
  final _aadhaar = TextEditingController();
  String? _proofKind;
  final Map<String, XFile> _files = {};
  ApiException? _error;
  bool _busy = false;
  bool _filled = false;

  Future<Json> _load() async => _map((await context.read<Session>().api.get('temples/${widget.templeId}/finance'))['data']);

  void _reload() => setState(() => _future = _load());

  @override
  void dispose() {
    _name.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  Future<void> _pick(String field, {bool selfie = false}) async {
    final source = selfie
        ? ImageSource.camera
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (c) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
                ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from the phone'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
              ]),
            ),
          );
    if (source == null) return;
    final f = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2400,
      preferredCameraDevice: selfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (f != null && mounted) setState(() => _files[field] = f);
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<Session>().api;
    try {
      final files = <UploadFile>[
        for (final e in _files.entries) UploadFile(field: e.key, filename: e.value.name, bytes: await e.value.readAsBytes()),
      ];
      await api.multipart('temples/${widget.templeId}/payout-account/kyc', fields: {
        if (_name.text.trim().isNotEmpty) 'kyc_name': _name.text.trim(),
        if (_aadhaar.text.trim().isNotEmpty) 'aadhaar_number': _aadhaar.text.trim(),
        if (_proofKind != null) 'temple_proof_kind': _proofKind,
      }, files: files);
      if (!mounted) return;
      _files.clear();
      _aadhaar.clear();
      showMessage(context, 'Sent. Our team will check and let you know here.');
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments in the app')),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final f = snap.data!;
          final account = f['payout_account'] == null ? null : _map(f['payout_account']);
          final kyc = _map(account?['kyc']);
          final docs = _map(kyc['documents']);
          final canEdit = f['can_edit_payout_account'] == true;
          final status = '${kyc['status'] ?? 'missing'}';
          final bankDone = account?['is_complete'] == true;
          if (!_filled) {
            _filled = true;
            _name.text = '${kyc['name'] ?? ''}';
            _proofKind = kyc['temple_proof_kind'] as String?;
          }

          final (color, icon, title, body) = switch (status) {
            'approved' => (Colors.green.shade700, Icons.verified, 'Approved', 'Devotees can pay your temple in the app: paid sevas, paid event tickets and the online hundi.'),
            'pending' => (theme.colorScheme.tertiary, Icons.hourglass_top, 'Being checked', 'Our team is checking your details. Payments open once they are approved; we may call you.'),
            'rejected' => (theme.colorScheme.error, Icons.error_outline, 'Not approved', '${kyc['rejection_reason'] ?? 'Please check the details and send them again.'}'),
            _ => (theme.colorScheme.primary, Icons.lock_outline, 'Not set up', 'To take money in the app, add the bank account and the documents below. This keeps anyone from collecting money in a temple\'s name falsely.'),
          };

          Widget doc(String field, String label, String hint, {bool selfie = false}) {
            final picked = _files[field];
            final onFile = docs[field] == true;
            return Card(
              child: ListTile(
                leading: Icon(picked != null || onFile ? Icons.check_circle : Icons.upload_file, color: picked != null || onFile ? Colors.green.shade700 : theme.colorScheme.primary),
                title: Text(label),
                subtitle: Text(picked != null ? 'Ready to send: ${picked.name}' : (onFile ? 'Sent. Tap to replace.' : hint)),
                trailing: Icon(selfie ? Icons.camera_front_outlined : Icons.add_a_photo_outlined),
                onTap: canEdit && !_busy ? () => _pick(field, selfie: selfie) : null,
              ),
            );
          }

          final fieldError = _error?.field('aadhaar_front') ?? _error?.field('aadhaar_back') ?? _error?.field('temple_proof') ?? _error?.field('person_photo');

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              try {
                await _future;
              } catch (_) {}
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (status == 'rejected')
                  RejectionNotice(
                    reason: kyc['rejection_reason'] as String?,
                    rejectedAt: DateTime.tryParse('${kyc['rejected_at']}')?.toLocal(),
                    canFix: canEdit,
                  )
                else
                  Card(
                    color: color.withValues(alpha: 0.08),
                    child: ListTile(
                      leading: Icon(icon, color: color, size: 32),
                      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      subtitle: Text(body),
                    ),
                  ),
                if (!canEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Only the temple\'s owner can add the bank account and the documents.'),
                  ),
                const SectionTitle('1. Bank account'),
                Card(
                  child: ListTile(
                    leading: Icon(bankDone ? Icons.check_circle : Icons.account_balance_outlined, color: bankDone ? Colors.green.shade700 : theme.colorScheme.primary),
                    title: Text(bankDone ? '${account!['account_name'] ?? 'UPI'}' : 'Add the trust\'s bank account or UPI id'),
                    subtitle: Text(bankDone
                        ? [
                            if (account!['account_number_masked'] != null) '${account['account_number_masked']}',
                            if (account['ifsc'] != null) '${account['ifsc']}',
                            if (account['upi_id'] != null) 'UPI ${account['upi_id']}',
                          ].join(' · ')
                        : 'Where the platform sends the temple\'s money.'),
                    trailing: canEdit ? const Icon(Icons.chevron_right) : null,
                    onTap: canEdit
                        ? () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => PayoutAccountScreen(templeId: widget.templeId, account: account)));
                            _reload();
                          }
                        : null,
                  ),
                ),
                const SectionTitle('2. Who you are'),
                ApiTextField(controller: _name, label: 'Your name as on the Aadhaar card', field: 'kyc_name', error: _error),
                ApiTextField(
                  controller: _aadhaar,
                  label: 'Aadhaar number',
                  field: 'aadhaar_number',
                  error: _error,
                  keyboardType: TextInputType.number,
                  hint: kyc['aadhaar_masked'] != null ? 'On file: ${kyc['aadhaar_masked']}. Leave blank to keep it.' : '12 digits',
                ),
                doc('aadhaar_front', 'Aadhaar card — front', 'A clear photo of the front.'),
                doc('aadhaar_back', 'Aadhaar card — back', 'A clear photo of the back, with the address.'),
                doc('person_photo', 'Your photo', 'A selfie, taken now with the front camera.', selfie: true),
                const SectionTitle('3. Proof of the temple'),
                OptionField(
                  label: 'What the proof is',
                  options: _proofKinds,
                  value: _proofKind,
                  onChanged: (v) => setState(() => _proofKind = v as String?),
                ),
                if (_error?.field('temple_proof_kind') != null)
                  Text(_error!.field('temple_proof_kind')!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                doc('temple_proof', 'Temple proof document', 'A photo of the document that shows you represent this temple.'),
                if (fieldError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(fieldError, style: TextStyle(color: theme.colorScheme.error))),
                const SizedBox(height: 16),
                Text(
                  'Your documents are kept private and seen only by the ${Brand.name} team for this check. '
                  'Changing the bank account or a document sends it for checking again, and payments pause until then.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_busy ? 'Sending…' : (status == 'missing' ? 'Send for approval' : 'Send again for approval')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The team's "no", said plainly: that it was not approved, when, the reason
/// in the team's own words, and what to do next.
class RejectionNotice extends StatelessWidget {
  const RejectionNotice({super.key, required this.reason, this.rejectedAt, this.canFix = true, this.onTap});

  final String? reason;
  final DateTime? rejectedAt;
  final bool canFix;

  /// When set (on the home screen), the whole notice opens the fix.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.colorScheme.error;
    return Card(
      color: red.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: red.withValues(alpha: 0.6), width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.cancel, color: red, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Payments not approved', style: theme.textTheme.titleMedium?.copyWith(color: red, fontWeight: FontWeight.w800)),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: red),
            ]),
            if (rejectedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 36),
                child: Text('By the ${Brand.name} team on ${DateFormat('d MMM yyyy, h:mm a').format(rejectedAt!)}', style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text('REASON', style: theme.textTheme.labelSmall?.copyWith(color: red, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: red, width: 4)),
              ),
              child: Text(
                (reason ?? '').trim().isEmpty ? 'The team did not give a reason. Use Help & support to ask.' : reason!.trim(),
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              canFix
                  ? 'What to do: correct what the reason says (a clearer photo, the right document, matching names), then tap "Send again for approval" below. Paid sevas, tickets and the hundi stay off until then.'
                  : 'The temple\'s owner can correct this and send it again. Paid sevas, tickets and the hundi stay off until then.',
              style: theme.textTheme.bodyMedium,
            ),
          ]),
        ),
      ),
    );
  }
}
