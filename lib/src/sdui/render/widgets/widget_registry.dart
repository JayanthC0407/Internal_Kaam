import '../node.dart';
import 'app_widgets.dart';
import 'banking_widgets.dart';
import 'content_widgets.dart';
import 'layout_widgets.dart';

/// Node `type` → builder: the widget half of the *pack* this app version
/// ships with (CONTRACT-OBDX §4, prototype CONTRACT §4).
///
/// Display widgets only for now. The input widgets (TextField, AmountField,
/// SelectList, OtpInput) come with the first journey; until then a screen
/// that uses one shows the "Unsupported" placeholder, as the contract
/// requires.
final Map<String, NodeBuilder> widgetRegistry = <String, NodeBuilder>{
  'Column': buildColumn,
  'Row': buildRow,
  'Grid': buildGrid,
  'Card': buildCard,
  'Text': buildText,
  'Button': buildButton,
  'Banner': buildBanner,
  'BalanceCard': buildBalanceCard,
  'AccountList': buildAccountList,
  'TxnList': buildTxnList,
  'QuickActions': buildQuickActions,
  'ReviewSummary': buildReviewSummary,
  'ResultPanel': buildResultPanel,
  'Divider': buildDivider,
  'Spacer': buildSpacer,
  // An existing app widget, by name (see DxpAppWidgets).
  'AppWidget': buildAppWidget,
};

/// What this build can draw, as sent in the session handshake
/// (`widgets`, CONTRACT-OBDX §1.1).
List<String> get supportedWidgets =>
    widgetRegistry.keys.map((type) => '$type@1').toList();
