/// The floating bottom nav geometry, shared by the shell (which positions the
/// bar) and the tab content (which must reserve space so nothing hides behind
/// it). All values are the merchant app's own — see `main_screen.dart`.
///
/// * gap       — the bar's distance from the bottom edge (before system inset)
/// * barHeight — the pill's height
/// * margin    — a little breathing room below the last content
const double kFloatingNavGap = 30;
const double kFloatingNavBarHeight = 64;
const double kFloatingNavMargin = 16;

/// Vertical space the floating nav occupies from the bottom edge. Tab content
/// reserves this **plus `MediaQuery.viewPadding.bottom`** at the bottom so the
/// last row / logout button clears the bar on every device.
const double kFloatingNavReserve =
    kFloatingNavGap + kFloatingNavBarHeight + kFloatingNavMargin; // 110
