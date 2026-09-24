import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_pickup_point.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_cash_management_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `pickup-point-collections` — cash-management pickup and delivery
/// points with their collection schedules.
///
/// The first dashboard widget that owns its data: it loads
/// [corpPickupPointsProvider] on mount rather than riding the dashboard's
/// primary accounts load, so switching this widget off in the personalize
/// screen will also stop it costing a request.
///
/// The companion cheque aggregator returns no data for the captured party,
/// so collected amounts are deliberately not shown — the widget presents
/// the points and their schedules, which is what the host actually has.
class CorpPickupPointsWidget extends ConsumerStatefulWidget {
  const CorpPickupPointsWidget({super.key});

  @override
  ConsumerState<CorpPickupPointsWidget> createState() =>
      _CorpPickupPointsWidgetState();
}

class _CorpPickupPointsWidgetState
    extends ConsumerState<CorpPickupPointsWidget> {
  @override
  void initState() {
    super.initState();
    // Post-frame: ensureLoaded mutates a provider, which Riverpod forbids
    // during the widget life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpPickupPointsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpPickupPointsProvider);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: 'Pickup Points',
            trailing: state.points.isEmpty
                ? null
                : Text(
                    '${state.points.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _buildBody(context, state),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, CorpPickupPointsState state) {
    if (state.isLoading && state.points.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && state.points.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () =>
                    ref.read(corpPickupPointsProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.points.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No pickup points configured.',
            style: TextStyle(
              fontSize: 13,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < state.points.length; i++) ...[
          if (i > 0) Divider(height: 18, color: CorpColors.divider(context)),
          _PickupPointRow(point: state.points[i]),
        ],
      ],
    );
  }
}

class _PickupPointRow extends StatelessWidget {
  const _PickupPointRow({required this.point});

  final CorpPickupPoint point;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final schedule = point.scheduleSummary;
    final address = point.addressSummary;
    final collection = point.collectionType;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.local_shipping_outlined, size: 18, color: brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      point.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                  ),
                  if (collection != null && collection.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        collection,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: brand,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (address != null) ...[
                const SizedBox(height: 3),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
              if (schedule != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: CorpColors.navInactive(context),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        schedule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: CorpColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
