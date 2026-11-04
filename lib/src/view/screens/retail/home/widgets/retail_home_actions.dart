import 'package:flutter/widgets.dart';

/// The Retail Home's Activity Centre actions, for widgets built away from
/// the Home state — the personalised dashboard's `quick-links` widget comes
/// from a registry and cannot reach the Home's sections otherwise.
///
/// The same actions the fixed Home passes to its own Activity Centre.
class RetailHomeActions extends InheritedWidget {
  const RetailHomeActions({
    super.key,
    required super.child,
    this.onTermDeposit,
    this.onViewStatement,
    this.onChequeBook,
    this.onNewDebitCard,
    this.onCalculator,
  });

  final VoidCallback? onTermDeposit;
  final VoidCallback? onViewStatement;
  final VoidCallback? onChequeBook;
  final VoidCallback? onNewDebitCard;
  final VoidCallback? onCalculator;

  /// Null outside the Retail Home.
  static RetailHomeActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RetailHomeActions>();

  // The callbacks are rebuilt with the Home and always do the same thing.
  @override
  bool updateShouldNotify(RetailHomeActions oldWidget) => false;
}
