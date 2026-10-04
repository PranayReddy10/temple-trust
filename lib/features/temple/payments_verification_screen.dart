import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/widgets.dart';
import 'finance_screen.dart';

typedef Json = Map<String, dynamic>;

Json _map(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};

List<Option> _proofKinds(S s) => [
      Option('trust_registration', s('mn_proof_trust')),
      Option('endowments_letter', s('mn_proof_endowments')),
      Option('committee_letter', s('mn_proof_committee')),
      Option('property_document', s('mn_proof_property')),
      Option('other', s('mn_proof_other')),
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
  State<PaymentsVerificationScreen> createState() =>
      _PaymentsVerificationScreenState();
}

class _PaymentsVerificationScreenState
    extends State<PaymentsVerificationScreen> {
  late Future<Json> _future = _load();
  final _name = TextEditingController();
  final _aadhaar = TextEditingController();
  String? _proofKind;
  final Map<String, XFile> _files = {};
  ApiException? _error;
  bool _busy = false;
  bool _filled = false;

  Future<Json> _load() async => _map((await context
      .read<Session>()
      .api
      .get('temples/${widget.templeId}/finance'))['data']);

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  void dispose() {
    _name.dispose();
    _aadhaar.dispose();
    super.dispose();
  }

  Future<void> _pick(String field, {bool selfie = false}) async {
    final s = S.of(context);
    final source = selfie
        ? ImageSource.camera
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (c) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(s('mn_take_photo')),
                    onTap: () => Navigator.pop(c, ImageSource.camera)),
                ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(s('mn_choose_photo')),
                    onTap: () => Navigator.pop(c, ImageSource.gallery)),
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
        for (final e in _files.entries)
          UploadFile(
              field: e.key,
              filename: e.value.name,
              bytes: await e.value.readAsBytes()),
      ];
      await api.multipart('temples/${widget.templeId}/payout-account/kyc',
          fields: {
            if (_name.text.trim().isNotEmpty) 'kyc_name': _name.text.trim(),
            if (_aadhaar.text.trim().isNotEmpty)
              'aadhaar_number': _aadhaar.text.trim(),
            if (_proofKind != null) 'temple_proof_kind': _proofKind,
          },
          files: files);
      if (!mounted) return;
      _files.clear();
      _aadhaar.clear();
      showMessage(context, S.of(context)('mn_kyc_sent'));
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
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('mn_payments_title'))),
      body: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final f = snap.data!;
          final account =
              f['payout_account'] == null ? null : _map(f['payout_account']);
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
            'approved' => (
                Colors.green.shade700,
                Icons.verified,
                s('mn_approved'),
                s('mn_kyc_approved_body')
              ),
            'pending' => (
                theme.colorScheme.tertiary,
                Icons.hourglass_top,
                s('mn_being_checked'),
                s('mn_kyc_pending_body')
              ),
            'rejected' => (
                theme.colorScheme.error,
                Icons.error_outline,
                s('not_approved'),
                '${kyc['rejection_reason'] ?? s('mn_kyc_rejected_body')}'
              ),
            _ => (
                theme.colorScheme.primary,
                Icons.lock_outline,
                s('mn_not_set_up'),
                s('mn_kyc_missing_body')
              ),
          };

          Widget doc(String field, String label, String hint,
              {bool selfie = false}) {
            final picked = _files[field];
            final onFile = docs[field] == true;
            return Card(
              child: ListTile(
                leading: Icon(
                    picked != null || onFile
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: picked != null || onFile
                        ? Colors.green.shade700
                        : theme.colorScheme.primary),
                title: Text(label),
                subtitle: Text(picked != null
                    ? s('mn_ready_to_send', {'name': picked.name})
                    : (onFile ? s('mn_sent_tap_replace') : hint)),
                trailing: Icon(selfie
                    ? Icons.camera_front_outlined
                    : Icons.add_a_photo_outlined),
                onTap: canEdit && !_busy
                    ? () => _pick(field, selfie: selfie)
                    : null,
              ),
            );
          }

          final fieldError = _error?.field('aadhaar_front') ??
              _error?.field('aadhaar_back') ??
              _error?.field('temple_proof') ??
              _error?.field('person_photo');

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
                    rejectedAt:
                        DateTime.tryParse('${kyc['rejected_at']}')?.toLocal(),
                    canFix: canEdit,
                  )
                else
                  Card(
                    color: color.withValues(alpha: 0.08),
                    child: ListTile(
                      leading: Icon(icon, color: color, size: 32),
                      title: Text(title,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.w700)),
                      subtitle: Text(body),
                    ),
                  ),
                if (!canEdit)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s('mn_owner_only_bank')),
                  ),
                SectionTitle(s('mn_step_bank')),
                Card(
                  child: ListTile(
                    leading: Icon(
                        bankDone
                            ? Icons.check_circle
                            : Icons.account_balance_outlined,
                        color: bankDone
                            ? Colors.green.shade700
                            : theme.colorScheme.primary),
                    title: Text(bankDone
                        ? '${account!['account_name'] ?? 'UPI'}'
                        : s('mn_add_bank')),
                    subtitle: Text(bankDone
                        ? [
                            if (account!['account_number_masked'] != null)
                              '${account['account_number_masked']}',
                            if (account['ifsc'] != null) '${account['ifsc']}',
                            if (account['upi_id'] != null)
                              'UPI ${account['upi_id']}',
                          ].join(' · ')
                        : s('mn_where_money_goes')),
                    trailing: canEdit ? const Icon(Icons.chevron_right) : null,
                    onTap: canEdit
                        ? () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PayoutAccountScreen(
                                        templeId: widget.templeId,
                                        account: account)));
                            _reload();
                          }
                        : null,
                  ),
                ),
                SectionTitle(s('mn_step_who')),
                ApiTextField(
                    controller: _name,
                    label: s('mn_aadhaar_name'),
                    field: 'kyc_name',
                    error: _error),
                ApiTextField(
                  controller: _aadhaar,
                  label: s('mn_aadhaar_number'),
                  field: 'aadhaar_number',
                  error: _error,
                  keyboardType: TextInputType.number,
                  hint: kyc['aadhaar_masked'] != null
                      ? s('mn_aadhaar_on_file',
                          {'masked': kyc['aadhaar_masked']})
                      : s('mn_12_digits'),
                ),
                doc('aadhaar_front', s('mn_aadhaar_front'),
                    s('mn_aadhaar_front_hint')),
                doc('aadhaar_back', s('mn_aadhaar_back'),
                    s('mn_aadhaar_back_hint')),
                doc('person_photo', s('mn_your_photo'), s('mn_selfie_hint'),
                    selfie: true),
                SectionTitle(s('mn_step_proof')),
                OptionField(
                  label: s('mn_proof_kind'),
                  options: _proofKinds(s),
                  value: _proofKind,
                  onChanged: (v) => setState(() => _proofKind = v as String?),
                ),
                if (_error?.field('temple_proof_kind') != null)
                  Text(_error!.field('temple_proof_kind')!,
                      style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                doc('temple_proof', s('mn_temple_proof'),
                    s('mn_temple_proof_hint')),
                if (fieldError != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(fieldError,
                          style: TextStyle(color: theme.colorScheme.error))),
                const SizedBox(height: 16),
                Text(
                  s('mn_docs_private', {'brand': Brand.name}),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (canEdit)
                  FilledButton.icon(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(_busy
                        ? s('mn_sending')
                        : (status == 'missing'
                            ? s('mn_send_approval')
                            : s('mn_send_again'))),
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
  const RejectionNotice(
      {super.key,
      required this.reason,
      this.rejectedAt,
      this.canFix = true,
      this.onTap});

  final String? reason;
  final DateTime? rejectedAt;
  final bool canFix;

  /// When set (on the home screen), the whole notice opens the fix.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final red = theme.colorScheme.error;
    return Card(
      color: red.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: red.withValues(alpha: 0.6), width: 1.5)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.cancel, color: red, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s('mn_payments_not_approved'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: red, fontWeight: FontWeight.w800)),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: red),
            ]),
            if (rejectedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 36),
                child: Text(
                    s('mn_rejected_by', {
                      'brand': Brand.name,
                      'date':
                          DateFormat('d MMM yyyy, h:mm a').format(rejectedAt!)
                    }),
                    style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text(s('reason').toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                    color: red,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800)),
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
                (reason ?? '').trim().isEmpty
                    ? s('mn_no_reason')
                    : reason!.trim(),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              canFix ? s('mn_fix_hint') : s('mn_owner_fix_hint'),
              style: theme.textTheme.bodyMedium,
            ),
          ]),
        ),
      ),
    );
  }
}
