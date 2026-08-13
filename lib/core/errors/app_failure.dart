/// A failure a notifier wants the UI to show.
///
/// The convention across the app:
///
/// * **Loading** into an `AsyncValue` state reports through `AsyncValue.error`,
///   so screens can render it with `.when(error: ...)`.
/// * **Mutations** throw an [AppFailure]. The message is already user-facing
///   Thai, so a screen can put `failure.message` straight into a SnackBar
///   without unwrapping anything.
///
/// [cause] keeps the original error for logging; it is never shown.
class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  /// Deliberately just the message — `Exception`'s default would prefix it
  /// with "Exception: " and leak into the UI.
  @override
  String toString() => message;
}
