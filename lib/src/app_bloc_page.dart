import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdict/verdict.dart';

import 'app_bloc_consumer.dart';
import 'app_bloc_feedback.dart';
import 'app_bloc_state.dart';

/// Base class for a screen driven by a single bloc.
///
/// Subclasses implement two methods:
///
/// - [createBloc] — build the bloc, usually from your service locator plus an
///   initial event.
/// - [buildBody] — build the screen from the always-available ready data.
///
/// Transient states are handled for you: they go to the installed
/// [AppBlocFeedbackDelegate] while the UI keeps rendering the last ready
/// snapshot, so reporting an error never blanks the screen.
///
/// ```dart
/// class ProfilePage extends AppBlocPage<ProfileBloc, ProfileState, ProfileReady> {
///   const ProfilePage({super.key});
///
///   @override
///   ProfileBloc createBloc(BuildContext context) =>
///       sl<ProfileBloc>()..add(const AppInit());
///
///   @override
///   Widget buildBody(BuildContext context, ProfileReady ready) =>
///       ready.isLoading ? const LoadingView() : ProfileView(ready.user);
/// }
/// ```
///
/// For reactions beyond the four report kinds — navigating on a phase change,
/// say — put a `BlocListener` inside [buildBody]; it survives rebuilds and
/// will not re-subscribe.
abstract class AppBlocPage<B extends BlocBase<S>, S extends AppBlocState<R>, R>
    extends StatelessWidget {
  /// Creates the page.
  const AppBlocPage({super.key});

  /// Creates the bloc that drives this page.
  B createBloc(BuildContext context);

  /// Builds the screen from the always-available ready data.
  Widget buildBody(BuildContext context, R ready);

  /// Whether this page owns the bloc and should close it when disposed.
  ///
  /// Leave `true` for a bloc created per screen. Set `false` when
  /// [createBloc] returns a shared or singleton bloc that must outlive this
  /// page — the page then provides it by value and does not close it.
  bool get manageBloc => true;

  /// Reports [failure].
  ///
  /// Defaults to the installed [AppBlocFeedbackDelegate]. Override to handle
  /// errors differently on this screen, and call `super.onError(…)` if you
  /// also want the app-wide reporting.
  void onError(BuildContext context, Failure failure) =>
      AppBlocFeedback.maybeOf(context)?.onError(context, failure);

  /// Reports a success carrying [message]. Defaults to the delegate.
  void onSuccess(BuildContext context, String message) =>
      AppBlocFeedback.maybeOf(context)?.onSuccess(context, message);

  /// Reports a caution carrying [message]. Defaults to the delegate.
  void onWarning(BuildContext context, String message) =>
      AppBlocFeedback.maybeOf(context)?.onWarning(context, message);

  /// Reports information carrying [message]. Defaults to the delegate.
  void onInfo(BuildContext context, String message) =>
      AppBlocFeedback.maybeOf(context)?.onInfo(context, message);

  @override
  Widget build(BuildContext context) {
    final consumer = AppBlocConsumer<B, S, R>(
      builder: buildBody,
      onError: onError,
      onSuccess: onSuccess,
      onWarning: onWarning,
      onInfo: onInfo,
    );

    return manageBloc
        ? BlocProvider<B>(create: createBloc, child: consumer)
        : BlocProvider<B>.value(value: createBloc(context), child: consumer);
  }
}
