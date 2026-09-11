/// First-time Login Flow Wizard (LFW) feature flag.
///
/// LFW (terms acceptance, security questions, limits review before the
/// dashboard loads) is a distinct feature ported from the vendor branch,
/// documented separately in "First-Time Login (LFW) Flow — API Reference".
/// Per that doc §2 "Flow Trigger", it is meant to be *conditional*: the
/// dashboard-modules call returns 428 / `DIGX_CMN_0096` only for a user who
/// hasn't completed onboarding, and the wizard only ever runs off that
/// signal (see `LoginWizardRepository.checkGate`, fixed to check modules
/// first and only fetch wizard steps/progress after a confirmed 428).
///
/// For a login role whose backend never returns that 428 — e.g. the
/// Corporate flow in "Corporate & Retail Dashboard — API Flow &
/// Implementation" §2/§3, which goes straight from `login`/`me` to the
/// dashboard with no gating step — `checkGate()` now naturally allows
/// straight through without ever calling `steps?wizardType=LFW` or
/// `loginFlow`, so enabling this does not by itself put a wizard in front
/// of a flow that doesn't need one.
///
/// Kept as a flag (rather than removed) as an escape hatch: set to `false`,
/// or run with `--dart-define=LFW_WIZARD_ENABLED=false`, to bypass the gate
/// check entirely (no `dashboards/modules` probe either) if a given
/// environment should never run it regardless of what the backend reports.
class LfwConfig {
  LfwConfig._();

  static const bool isEnabled = bool.fromEnvironment(
    'LFW_WIZARD_ENABLED',
    defaultValue: true,
  );
}
