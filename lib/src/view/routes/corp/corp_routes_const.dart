/// Route names for the Corporate (`corporateuser`) surfaces.
///
/// Kept separate from the shared [RoutesConst] so corporate screens can be
/// added without growing the retail route table. Generation for these names
/// lives in `CorpRoutes.onGenerateRoute`, which the app's main
/// `Routes.onGenerateRoutes` delegates to.
class CorpRoutesConst {
  CorpRoutesConst._();

  static const String corpDashboardScreen = '/corp_dashboard_screen';

  /// Every corporate route name, used by `Routes` to decide whether to
  /// delegate a given settings name to [CorpRoutes].
  static const Set<String> all = {corpDashboardScreen};
}
