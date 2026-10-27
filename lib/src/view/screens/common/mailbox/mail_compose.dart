import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/mailbox/mailbox_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/mailbox_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// Mailbox Phase 2: Compose Mail and Reply, with attachments
/// (docs/obdx/features/mailbox.md §6).

/// Runs one mailbox write through the shared OTP loop ([runWithOtp]), with
/// the mailbox's own OTP texts.
Future<ResponseHandler<MailboxWriteOutcome>> runMailboxWrite(
  BuildContext context,
  Future<ResponseHandler<MailboxWriteOutcome>> Function(ObdxChallenge? challenge, String? otp) call,
) {
  final l10n = AppLocalizations.of(context);
  return runWithOtp(context, call, title: l10n.mailboxOtpTitle, invalidOtp: l10n.mailboxOtpInvalid);
}

/// Done: not failed and no OTP still waiting.
bool mailboxWriteDone(ResponseHandler<MailboxWriteOutcome> r) => obdxWriteDone(r);

/// An attached file: its name and the `contentId` object OBDX returned.
class _Attached {
  const _Attached(this.name, this.contentId, {this.preAttached = false});

  final String name;
  final Map<String, dynamic> contentId;

  /// Reply from Sent Mails starts with the original attachments; taking one
  /// off does not delete it on the server (message-detail/hooks.js:282-287).
  final bool preAttached;
}

/// Attachment handling shared by Compose and Reply.
mixin _Attachments<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final attached = <_Attached>[];

  /// Files still uploading; OBDX blocks Send until they finish.
  int uploading = 0;

  /// Compose sends `?fileName=<index>` and its own header with each upload.
  bool get uploadsFromCompose;

  List<Map<String, dynamic>> get contents => [for (final a in attached) a.contentId];

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> pickAndUpload() async {
    final l10n = AppLocalizations.of(context);
    FilePickerResult? result;
    try {
      try {
        result = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: MailUploadRules.pickerExtensions,
          withData: true,
        );
      } on PlatformException {
        // Some pickers refuse a type filter; the rules below still check.
        result = await FilePicker.pickFiles(allowMultiple: true, withData: true);
      }
    } catch (_) {
      if (mounted) _snack(l10n.mailboxPickFailed);
      return;
    }
    if (result == null || !mounted) return;
    final files = [
      for (final f in result.files)
        if (f.bytes != null) (f.name, f.bytes!),
    ];
    if (files.isEmpty) return;

    final problem = MailUploadRules.check(
      [for (final f in files) (f.$1, f.$2.length)],
      attached.map((a) => a.name),
    );
    if (problem != null) {
      return _snack(switch (problem) {
        MailUploadProblem.duplicate => l10n.mailboxDuplicateFile,
        MailUploadProblem.tooLarge => l10n.mailboxFileTooLarge,
        MailUploadProblem.badType => l10n.mailboxFileBadType,
      });
    }

    final repo = ref.read(mailboxRepositoryProvider);
    setState(() => uploading += files.length);
    var failed = false;
    // One after another so a 417 can ask for its OTP (OBDX sends them
    // together). [APP]
    for (final (i, (name, bytes)) in files.indexed) {
      final r = await runMailboxWrite(
        context,
        (c, otp) => repo.uploadAttachment(name, bytes, composeIndex: uploadsFromCompose ? i : null, challenge: c, otp: otp),
      );
      if (!mounted) return;
      setState(() {
        uploading--;
        final id = r is Success<MailboxWriteOutcome> ? r.data?.contentId : null;
        if (mailboxWriteDone(r) && id != null) {
          attached.add(_Attached(name, id));
        } else {
          failed = true;
        }
      });
    }
    if (failed) _snack(l10n.mailboxUploadFailed);
  }

  Future<void> removeAttached(_Attached a) async {
    setState(() => attached.remove(a));
    if (a.preAttached) return;
    final id = a.contentId['value']?.toString();
    if (id == null) return;
    final repo = ref.read(mailboxRepositoryProvider);
    // OBDX ignores the answer; so does the app.
    await runMailboxWrite(context, (c, otp) => repo.removeAttachment(id, challenge: c, otp: otp));
  }

  Widget attachmentsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: pickAndUpload,
              icon: const Icon(Icons.attach_file_rounded, size: 18),
              label: Text(l10n.mailboxAttachFile),
            ),
            for (final a in attached)
              InputChip(
                label: Text(a.name),
                onDeleted: () => removeAttached(a),
                deleteButtonTooltipMessage: l10n.mailboxRemoveFile,
              ),
            if (uploading > 0) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(l10n.mailboxFileRules, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
      ],
    );
  }
}

/// The message box with OBDX's "{number} Characters Left" (1000 at most).
class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller, required this.error, required this.onChanged, this.label});

  final TextEditingController controller;
  final String? error;
  final VoidCallback onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayTextField(
          label: label ?? l10n.mailboxMessage,
          controller: controller,
          required: true,
          maxLines: 8,
          error: error,
          inputFormatters: [LengthLimitingTextInputFormatter(MailUploadRules.maxMessageLength)],
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            l10n.mailboxCharactersLeft(MailUploadRules.maxMessageLength - controller.text.length),
            style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
          ),
        ),
      ],
    );
  }
}

/// Compose Mail: Party (with related parties only), Category, Other Remark
/// (for OTHERS), Message, attachments; Send → `POST mailbox/mails`.
class MailComposeView extends ConsumerStatefulWidget {
  const MailComposeView({super.key, required this.onClose, required this.onSent});

  final VoidCallback onClose;

  /// After a send; true when it went for approval.
  final ValueChanged<bool> onSent;

  @override
  ConsumerState<MailComposeView> createState() => _MailComposeViewState();
}

class _MailComposeViewState extends ConsumerState<MailComposeView> with _Attachments<MailComposeView> {
  final _remark = TextEditingController();
  final _text = TextEditingController();
  MailSubject? _subject;
  String? _party;
  bool _tried = false;
  bool _sending = false;

  @override
  bool get uploadsFromCompose => true;

  @override
  void dispose() {
    _remark.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickSubject(List<MailSubject> subjects) async {
    final picked = await showPayPicker<MailSubject>(
      context,
      title: AppLocalizations.of(context).mailboxCategory,
      selected: _subject,
      options: [for (final s in subjects) PayOption(value: s, title: s.label, subtitle: s.category)],
    );
    if (picked != null && mounted) setState(() => _subject = picked);
  }

  Future<void> _pickParty(List<MailParty> parties) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).mailboxParty,
      selected: _party ?? parties.first.id,
      options: [for (final p in parties) PayOption(value: p.id, title: p.name, subtitle: p.id)],
    );
    if (picked != null && mounted) setState(() => _party = picked);
  }

  Future<void> _send(ComposeSetup setup) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    final subject = _subject;
    if (subject == null || _text.text.trim().isEmpty || uploading > 0) return;
    setState(() => _sending = true);
    final body = composeMailBody(
      subject: subject,
      otherRemark: _remark.text.trim(),
      text: _text.text,
      contents: contents,
      // The chosen party, else the own one (OBDX's Party is not required). [APP]
      party: setup.parties.where((p) => p.id == _party).firstOrNull ?? setup.parties.firstOrNull,
    );
    final repo = ref.read(mailboxRepositoryProvider);
    final r = await runMailboxWrite(context, (c, otp) => repo.sendMail(body, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _sending = false);
    if (mailboxWriteDone(r)) {
      HapticFeedback.mediumImpact();
      widget.onSent((r as Success<MailboxWriteOutcome>).data!.pendingApproval);
    } else if (r is! Success<MailboxWriteOutcome>) {
      _snack(r.resolveUserMessage(l10n: l10n, fallback: l10n.mailboxActionFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(composeSetupProvider).when(
          loading: () => const PayCard(
            child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          ),
          error: (e, _) => PayErrorRetry(
            message: e is MailboxLoadError && e.message != null ? e.message! : l10n.mailboxLoadFailed,
            onRetry: () => ref.invalidate(composeSetupProvider),
          ),
          data: (setup) {
            final party = setup.parties.where((p) => p.id == _party).firstOrNull ?? setup.parties.firstOrNull;
            return PayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.mailboxComposeMail,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.mailboxCancel,
                        onPressed: _sending ? null : widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (setup.showParty && party != null) ...[
                    PayFieldLabel(l10n.mailboxParty),
                    PayPickerField(
                      placeholder: l10n.mailboxSelect,
                      title: party.name,
                      subtitle: party.id,
                      icon: Icons.business_outlined,
                      onTap: () => _pickParty(setup.parties),
                    ),
                    const SizedBox(height: 14),
                  ],
                  PayFieldLabel(l10n.mailboxCategory, required: true),
                  PayPickerField(
                    placeholder: l10n.mailboxSelect,
                    title: _subject?.label,
                    subtitle: _subject?.category,
                    icon: Icons.label_outline_rounded,
                    error: _tried && _subject == null ? l10n.mailboxEmptySubject : null,
                    onTap: () => _pickSubject(setup.subjects),
                  ),
                  if (_subject?.isOthers ?? false) ...[
                    const SizedBox(height: 14),
                    PayTextField(label: l10n.mailboxOtherRemark, controller: _remark),
                  ],
                  const SizedBox(height: 14),
                  _MessageField(
                    controller: _text,
                    error: _tried && _text.text.trim().isEmpty ? l10n.mailboxEmptyMail : null,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  attachmentsSection(),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: PaySecondaryButton(label: l10n.mailboxCancel, onPressed: _sending ? null : widget.onClose)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PayPrimaryButton(
                          label: l10n.mailboxSend,
                          icon: Icons.send_rounded,
                          loading: _sending,
                          onPressed: uploading > 0 ? null : () => _send(setup),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
  }
}

/// Reply under an open mail: the message and attachments; Send →
/// `POST mailbox/mails/{id}/replyMail`. From Sent Mails the original
/// attachments come along (message-detail/hooks.js:222-236).
class MailReplyBox extends ConsumerStatefulWidget {
  const MailReplyBox({super.key, required this.mail, required this.fromSent, required this.onCancel, required this.onSent});

  final Mail mail;
  final bool fromSent;
  final VoidCallback onCancel;
  final ValueChanged<bool> onSent;

  @override
  ConsumerState<MailReplyBox> createState() => _MailReplyBoxState();
}

class _MailReplyBoxState extends ConsumerState<MailReplyBox> with _Attachments<MailReplyBox> {
  final _text = TextEditingController();
  bool _tried = false;
  bool _sending = false;

  @override
  bool get uploadsFromCompose => false;

  @override
  void initState() {
    super.initState();
    if (widget.fromSent) {
      attached.addAll([
        for (final a in widget.mail.attachments)
          _Attached(a.name, {'value': a.contentId, 'displayValue': a.displayValue}, preAttached: true),
      ]);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _tried = true);
    if (_text.text.trim().isEmpty || uploading > 0) return;
    setState(() => _sending = true);
    final repo = ref.read(mailboxRepositoryProvider);
    final r = await runMailboxWrite(
      context,
      (c, otp) => repo.replyMail(widget.mail, _text.text, contents, challenge: c, otp: otp),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (mailboxWriteDone(r)) {
      HapticFeedback.mediumImpact();
      widget.onSent((r as Success<MailboxWriteOutcome>).data!.pendingApproval);
    } else if (r is! Success<MailboxWriteOutcome>) {
      _snack(r.resolveUserMessage(l10n: l10n, fallback: l10n.mailboxActionFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 28, color: HomeColors.divider(context)),
        _MessageField(
          label: l10n.mailboxReply,
          controller: _text,
          error: _tried && _text.text.trim().isEmpty ? l10n.mailboxEmptyMail : null,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 12),
        attachmentsSection(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PaySecondaryButton(label: l10n.mailboxCancel, onPressed: _sending ? null : widget.onCancel)),
            const SizedBox(width: 12),
            Expanded(
              child: PayPrimaryButton(
                label: l10n.mailboxSend,
                icon: Icons.send_rounded,
                loading: _sending,
                onPressed: uploading > 0 ? null : _send,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
