import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Back-button behavior that survives `context.go` navigation: pops when
/// there's a page underneath, otherwise goes to [fallback]. `go` replaces the
/// whole stack, so a bare `context.pop()` on such a screen throws "nothing to
/// pop" and the arrow becomes a dead tap — this keeps it working from any
/// entry path (deep link, dev stepper, go vs push).
void backOr(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Wraps a screen to automatically:
/// 1. Dismiss/unfocus the keyboard when tapping anywhere outside an input.
/// 2. Intercept Android system back gestures/buttons: unfocus keyboard first
///    if open; otherwise call [backOr(context, fallback)] to avoid exiting app.
class AppBackScope extends StatelessWidget {
  const AppBackScope({
    super.key,
    required this.child,
    this.fallback = '/intro',
    this.onBack,
  });

  final Widget child;
  final String fallback;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null && primaryFocus.hasFocus) {
          primaryFocus.unfocus();
          return;
        }
        if (onBack != null) {
          onBack!();
        } else {
          backOr(context, fallback);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
    );
  }
}
