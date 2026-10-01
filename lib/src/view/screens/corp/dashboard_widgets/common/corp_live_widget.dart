import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_widget_data_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';

/// A dashboard widget backed by a provider: loading, a failure with Retry,
/// nothing to show, or the design widget [builder] makes from the data —
/// in [currencyOf]'s currency.
///
/// A Retry shows loading again rather than leaving the failure up while
/// the request is in flight.
class CorpLiveWidget<T> extends StatelessWidget {
  const CorpLiveWidget({
    super.key,
    required this.title,
    required this.value,
    required this.onRetry,
    required this.isEmpty,
    required this.emptyMessage,
    required this.builder,
    this.currencyOf,
    this.emptyIcon = Icons.inbox_outlined,
  });

  /// The widget's own title, for the status cards.
  final String title;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final bool Function(T data) isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget Function(T data) builder;
  final String? Function(T data)? currencyOf;

  @override
  Widget build(BuildContext context) {
    if (value.hasError && !value.isLoading) {
      final error = value.error;
      return CorpWidgetStatusCard.error(
        title: title,
        message: error is CorpWidgetLoadError
            ? error.message
            : 'This information could not be loaded.',
        onRetry: onRetry,
      );
    }
    if (!value.hasValue || (value.isLoading && value.hasError)) {
      return CorpWidgetStatusCard.loading(title: title);
    }
    final data = value.requireValue;
    if (isEmpty(data)) {
      return CorpWidgetStatusCard.empty(
        title: title,
        message: emptyMessage,
        icon: emptyIcon,
      );
    }
    return CorpCurrency(
      symbol: CorpFigures.symbolFor(currencyOf?.call(data)),
      child: builder(data),
    );
  }
}
