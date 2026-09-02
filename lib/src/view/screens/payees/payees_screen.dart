import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/payee/payee_models.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/payee_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

class PayeesScreen extends ConsumerStatefulWidget {
  const PayeesScreen({
    super.key,
    this.embedded = false,
    this.onAddPayee,
    this.onBack,
  });

  final bool embedded;
  final VoidCallback? onAddPayee;
  final VoidCallback? onBack;

  @override
  ConsumerState<PayeesScreen> createState() => _PayeesScreenState();
}

class _PayeesScreenState extends ConsumerState<PayeesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 3,
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(payeesProvider.notifier).ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddPayee() async {
    if (widget.embedded && widget.onAddPayee != null) {
      widget.onAddPayee!();
      return;
    }

    final created = await Navigator.of(context).pushNamed(
      RoutesConst.addBankAccountPayeeScreen,
    );

    if (created == true && mounted) {
      await ref.read(payeesProvider.notifier).refresh();
    }
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payeesProvider);
    final responsive = Responsive.of(context);

    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final brand = HomeColors.brand(context);
    final divider = HomeColors.divider(context);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = responsive.isPhone || constraints.maxWidth < 650;
        final hasBoundedHeight = constraints.hasBoundedHeight;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isPhone ? AppSpacing.lg : AppSpacing.xxxl,
            AppSpacing.lg,
            isPhone ? AppSpacing.lg : AppSpacing.xxxl,
            isPhone ? AppSpacing.lg : AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header.
              if (isPhone)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Manage your saved payees',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _openAddPayee,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Add Bank Account Payee'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    IconButton(
                      onPressed: _goBack,
                      tooltip: 'Back',
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Manage your saved payees',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _openAddPayee,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Add Bank Account Payee'),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.lg),

              // Main payee content.
              if (hasBoundedHeight)
                Expanded(
                  child: _PayeeContentCard(
                    isPhone: isPhone,
                    state: state,
                    tabController: _tabController,
                    searchController: _searchController,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    brand: brand,
                    divider: divider,
                    filteredPayees: _filteredPayees(state),
                    onSearchChanged: () => setState(() {}),
                    onRetry: () =>
                        ref.read(payeesProvider.notifier).refresh(),
                  ),
                )
              else
                SizedBox(
                  height: isPhone ? 520 : 600,
                  child: _PayeeContentCard(
                    isPhone: isPhone,
                    state: state,
                    tabController: _tabController,
                    searchController: _searchController,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    brand: brand,
                    divider: divider,
                    filteredPayees: _filteredPayees(state),
                    onSearchChanged: () => setState(() {}),
                    onRetry: () =>
                        ref.read(payeesProvider.notifier).refresh(),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return Material(
        color: HomeColors.bg(context),
        child: SafeArea(
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: content,
      ),
    );
  }

  List<PayeeSummary> _filteredPayees(PayeesState state) {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return state.payees;
    }

    return state.payees
        .where(
          (payee) => payee.nickname.toLowerCase().contains(query),
        )
        .toList();
  }
}

class _PayeeContentCard extends StatelessWidget {
  const _PayeeContentCard({
    required this.isPhone,
    required this.state,
    required this.tabController,
    required this.searchController,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.divider,
    required this.filteredPayees,
    required this.onSearchChanged,
    required this.onRetry,
  });

  final bool isPhone;
  final PayeesState state;
  final TabController tabController;
  final TextEditingController searchController;

  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color divider;

  final List<PayeeSummary> filteredPayees;
  final VoidCallback onSearchChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: divider),
      ),
      child: Column(
        children: [
          // Tabs.
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: brand,
            unselectedLabelColor: textSecondary,
            indicatorColor: brand,
            dividerColor: divider,
            tabs: const [
              Tab(text: 'Account'),
              Tab(text: 'Demand Drafts'),
              Tab(text: 'Peer To Peer'),
            ],
          ),

          // Search field.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: isPhone ? double.infinity : 300,
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: const InputDecoration(
                    labelText: 'Search By Nickname',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ),
          ),

          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: _ErrorBanner(
                message: state.errorMessage!,
                onRetry: onRetry,
              ),
            ),

          // IMPORTANT:
          // Do not put this TabBarView inside another SingleChildScrollView.
          // The parent card gives it the remaining bounded height, which fixes
          // the blank/broken mobile layout.
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _AccountPayeesTable(
                  payees: filteredPayees,
                  loading: state.isLoading,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  divider: divider,
                  brand: brand,
                ),
                const _ComingSoonPane(
                  title: 'Demand Draft Payees',
                  detail:
                      'The supplied API capture does not contain the Demand Draft payee flow.',
                ),
                const _ComingSoonPane(
                  title: 'Peer To Peer Payees',
                  detail:
                      'The supplied API capture does not contain the Peer To Peer payee flow.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPayeesTable extends StatelessWidget {
  const _AccountPayeesTable({
    required this.payees,
    required this.loading,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.brand,
  });

  final List<PayeeSummary> payees;
  final bool loading;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color brand;

  @override
  Widget build(BuildContext context) {
    if (loading && payees.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (payees.isEmpty) {
      return Center(
        child: Text(
          'No data to display.',
          style: TextStyle(
            color: textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 650) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: payees.length,
            separatorBuilder: (_, __) => Divider(color: divider),
            itemBuilder: (context, index) {
              final p = payees[index];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: brand.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: brand,
                  ),
                ),
                title: Text(
                  p.nickname,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${p.accountType}\n${p.accountDetails}',
                  style: TextStyle(
                    color: textSecondary,
                  ),
                ),
                isThreeLine: true,
              );
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Payee Nickname')),
              DataColumn(label: Text('Account Type')),
              DataColumn(label: Text('Account Details')),
            ],
            rows: payees
                .map(
                  (p) => DataRow(
                    cells: [
                      DataCell(Text(p.nickname)),
                      DataCell(Text(p.accountType)),
                      DataCell(Text(p.accountDetails)),
                    ],
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: colors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonPane extends StatelessWidget {
  const _ComingSoonPane({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textSecondary = HomeColors.textSecondary(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 40,
              color: HomeColors.brand(context),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
