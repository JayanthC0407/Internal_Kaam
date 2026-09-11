import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'home_dashboard_screen.dart';

/// Placeholder dashboard shown when the authenticated `me` response resolves
/// `dashboardClassValue == corporateuser` (see API Flow & Implementation doc,
/// §6 "Dashboard Selection Logic" and §16 "Final Implementation Decision").
///
/// This is intentionally blank for now — a real corporate-specific UI
/// (accounts, approvals, invoices, etc. per §11 "Corporate Configuration/Data
/// Flow") will be built out in a follow-up pass. Routing/session behavior
/// (logout, idle timeout) matches the retail dashboard so this can be tested
/// end-to-end today.
class CorporateDashboardScreen extends ConsumerWidget {
  const CorporateDashboardScreen({super.key, required this.args});

  final HomeDashboardArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Corporate Dashboard',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 34,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Welcome, ${args.userName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are signed in as a corporate user.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(sessionManagerProvider).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      RoutesConst.loginScreen,
      (route) => false,
    );
  }
}
