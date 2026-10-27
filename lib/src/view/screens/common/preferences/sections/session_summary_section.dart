import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/view/providers/common/account_settings_providers.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// `10/26/26, 12:34 PM` — the design's (and OBDX's `DATETIME`) format.
String sessionDateTime(DateTime? t) {
  if (t == null) return '–';
  final l = t.toLocal();
  final hour = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final minute = l.minute.toString().padLeft(2, '0');
  final year = (l.year % 100).toString().padLeft(2, '0');
  return '${l.month}/${l.day}/$year, $hour:$minute ${l.hour < 12 ? 'AM' : 'PM'}';
}

/// OBDX's `channelType` labels by `accessPointId`.
String sessionChannel(AppLocalizations l10n, String accessPointId) => switch (accessPointId) {
      'APINTERNET' => l10n.ssChannelInternet,
      'APMOBRESP' => l10n.ssChannelMobileResponsive,
      'APSIRICHATBOT' => l10n.ssChannelChatbot,
      'APWEARABLE' => l10n.ssChannelWearables,
      'APMOBAPP' || 'MOBILEAPP' => l10n.ssChannelMobileApp,
      'MOBILEBROW' => l10n.ssChannelMobileBrowser,
      'WEBBROW' => l10n.ssChannelDesktopBrowser,
      'APSOFTTOKEN' || 'SOFTTOKENAPP' => l10n.ssChannelSoftToken,
      '' || 'UNKNOWN' => l10n.ssChannelUnknown,
      _ => accessPointId,
    };

/// Preferences → Session Summary (OBDX `base-components/session-summary`):
/// every sign-in with Start / End Date & Time, Channel and IP Address; a
/// row expands to what was done in that session (Transaction Name, Status,
/// Transaction Date & Time). A table on wide layouts, cards on a phone.
class SessionSummarySection extends ConsumerStatefulWidget {
  const SessionSummarySection({super.key});

  @override
  ConsumerState<SessionSummarySection> createState() => _SessionSummarySectionState();
}

class _SessionSummarySectionState extends ConsumerState<SessionSummarySection> {
  final _open = <String>{};

  void _toggle(String id) => setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(userSessionsProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(userSessionsProvider)),
          data: (sessions) => LayoutBuilder(
            builder: (context, c) {
              final table = c.maxWidth >= 640;
              final divider = HomeColors.divider(context);
              return Container(
                decoration: BoxDecoration(
                  color: HomeColors.card(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (table) const _HeaderRow(),
                    if (sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.ssEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: HomeColors.textSecondary(context)),
                        ),
                      ),
                    for (final s in sessions)
                      _SessionRow(
                        session: s,
                        table: table,
                        open: _open.contains(s.sessionId),
                        onToggle: () => _toggle(s.sessionId),
                      ),
                  ],
                ),
              );
            },
          ),
        );
  }
}

TextStyle _headStyle(BuildContext context) =>
    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: HomeColors.textSecondary(context));

/// The grey column header of the design.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = _headStyle(context);
    return Container(
      color: HomeColors.bg(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          const SizedBox(width: 40),
          Expanded(flex: 4, child: Text(l10n.ssStartDateTime, style: style)),
          Expanded(flex: 4, child: Text(l10n.ssEndDateTime, style: style)),
          Expanded(flex: 3, child: Text(l10n.ssChannel, style: style)),
          Expanded(flex: 3, child: Text(l10n.ssIpAddress, style: style)),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.table, required this.open, required this.onToggle});

  final UserSession session;
  final bool table;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final strong = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context));
    final muted = TextStyle(fontSize: 13.5, color: HomeColors.textSecondary(context));
    final channel = sessionChannel(l10n, session.accessPointId);
    final chevron = Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: brand, size: 22);
    // Still signed in: no end yet.
    final end = session.end == null || session.end == session.start ? '–' : sessionDateTime(session.end);

    final head = InkWell(
      onTap: onToggle,
      child: Semantics(
        button: true,
        expanded: open,
        label: l10n.ssToggleDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: table
              ? Row(
                  children: [
                    SizedBox(width: 40, child: Align(alignment: AlignmentDirectional.centerStart, child: chevron)),
                    Expanded(flex: 4, child: Text(sessionDateTime(session.start), style: strong)),
                    Expanded(flex: 4, child: Text(end, style: muted)),
                    Expanded(flex: 3, child: Text(channel, style: strong)),
                    Expanded(flex: 3, child: Text(session.ipAddress ?? '–', style: muted)),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 1), child: chevron),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sessionDateTime(session.start), style: strong),
                          const SizedBox(height: 4),
                          Text('${l10n.ssEndDateTime}: $end', style: muted.copyWith(fontSize: 12.5)),
                          const SizedBox(height: 2),
                          Text('$channel · ${session.ipAddress ?? '–'}', style: muted.copyWith(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context), width: 1.5))),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            if (open) _Activity(sessionId: session.sessionId, table: table),
          ],
        ),
      ),
    );
  }
}

/// The expanded grey panel: what was done in the session.
class _Activity extends ConsumerWidget {
  const _Activity({required this.sessionId, required this.table});

  final String sessionId;
  final bool table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final head = _headStyle(context).copyWith(fontSize: 12);
    final text = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: HomeColors.textPrimary(context));

    Widget status(String code) {
      final (label, color) = switch (code) {
        'SUCCESS' => (l10n.ssSuccess, HomeColors.success(context)),
        'FAILURE' => (l10n.ssFailure, HomeColors.error(context)),
        _ => ('–', HomeColors.textSecondary(context)),
      };
      return Text(label, style: text.copyWith(color: color, fontWeight: code.isEmpty ? FontWeight.w500 : FontWeight.w600));
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: HomeColors.bg(context), borderRadius: BorderRadius.circular(8)),
      child: ref.watch(sessionActivityProvider(sessionId)).when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(sessionActivityProvider(sessionId))),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.ssNoActivity, style: _headStyle(context)),
                );
              }
              if (!table) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.activity, style: text),
                                  Text(sessionDateTime(a.time), style: head),
                                ],
                              ),
                            ),
                            status(a.status),
                          ],
                        ),
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 4, child: Text(l10n.ssTransactionName, style: head)),
                      Expanded(flex: 3, child: Text(l10n.ssStatus, style: head)),
                      Expanded(flex: 5, child: Text(l10n.ssTransactionDateTime, style: head)),
                    ],
                  ),
                  for (final a in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 4, child: Text(a.activity, style: text)),
                          Expanded(flex: 3, child: Align(alignment: AlignmentDirectional.centerStart, child: status(a.status))),
                          Expanded(flex: 5, child: Text(sessionDateTime(a.time), style: text.copyWith(fontWeight: FontWeight.w400))),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
