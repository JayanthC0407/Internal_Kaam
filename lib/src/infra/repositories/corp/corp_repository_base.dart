import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Base for the Corporate repositories.
///
/// The response handling itself lives in [ObdxRepositoryBase] so that
/// common repositories can share it without importing the Corporate tree;
/// this subclass is kept as the Corporate-side seam, so corp-only behaviour
/// has one place to go without touching every corp repository.
abstract class CorpRepositoryBase extends ObdxRepositoryBase {}
