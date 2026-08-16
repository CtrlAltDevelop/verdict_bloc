import 'package:flutter/widgets.dart';
import 'package:verdict/verdict.dart';

/// Renders the transient reports an [AppBlocState] emits.
///
/// This package deliberately ships no UI for errors and successes — a toast,
/// a snackbar, a banner and a dialog are all valid, and the copy is yours.
/// Implement this once for your app, install it with [AppBlocFeedback], and
/// every [AppBlocConsumer] and [AppBlocPage] below it reports the same way.
///
/// ```dart
/// class ToastFeedback implements AppBlocFeedbackDelegate {
///   const ToastFeedback();
///
///   @override
///   void onError(BuildContext context, Failure failure) {
///     if (failure is CancelledFailure || failure is AuthFailure) return;
///     showToast(context, describe(failure));
///   }
///
///   @override
///   void onSuccess(BuildContext context, String message) =>
///       showToast(context, message);
///   // …onWarning, onInfo…
/// }
/// ```
abstract interface class AppBlocFeedbackDelegate {
  /// Reports [failure] to the user.
  ///
  /// A good implementation filters here: [CancelledFailure] means the user
  /// backed out and is not worth reporting, and [AuthFailure] usually routes
  /// to sign-in rather than showing an error.
  void onError(BuildContext context, Failure failure);

  /// Reports a success carrying [message].
  void onSuccess(BuildContext context, String message);

  /// Reports a caution carrying [message].
  void onWarning(BuildContext context, String message);

  /// Reports neutral information carrying [message].
  void onInfo(BuildContext context, String message);
}

/// Installs an [AppBlocFeedbackDelegate] for the widgets below it.
///
/// Put one above your navigator so every screen reports the same way:
///
/// ```dart
/// AppBlocFeedback(
///   delegate: const ToastFeedback(),
///   child: MaterialApp.router(routerConfig: router),
/// )
/// ```
class AppBlocFeedback extends InheritedWidget {
  /// Installs [delegate] for [child] and its descendants.
  const AppBlocFeedback({
    required this.delegate,
    required super.child,
    super.key,
  });

  /// The delegate that renders transient reports.
  final AppBlocFeedbackDelegate delegate;

  /// The delegate installed above [context], or `null` if there is none.
  ///
  /// Returning `null` rather than throwing is deliberate: a screen with no
  /// delegate simply stays silent instead of crashing, which keeps this
  /// package usable in tests and in partially migrated apps.
  static AppBlocFeedbackDelegate? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppBlocFeedback>()?.delegate;

  @override
  bool updateShouldNotify(AppBlocFeedback oldWidget) =>
      oldWidget.delegate != delegate;
}
