import 'package:assistant_actions/assistant_actions.dart';
import 'package:flutter/widgets.dart';

/// Lets the assistant SDK open this app's own screens by their named routes.
///
/// The SDK has already checked every location against the tenant's screen map
/// (its allowlist) before calling this, and sensitive screens only reach here
/// after the user tapped the button.
class NamedRouteNavigator implements AssistantNavigator {
  NamedRouteNavigator(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  void open(String location) {
    // The app's routes take no query parameters; anything after `?` is dropped.
    navigatorKey.currentState?.pushNamed(Uri.parse(location).path);
  }

  /// Transfer drafts are tier 4. This bank is configured at tier 3, so the
  /// SDK never sends one; if it ever did, the transfer screen opens empty and
  /// the user fills it in as usual.
  @override
  void openTransferDraft(String location, TransferDraft draft) => open(location);
}
