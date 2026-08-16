import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdict/verdict.dart';

import 'app_bloc_feedback.dart';
import 'app_bloc_state.dart';

/// Builds from the always-available ready data of [B], and routes transient
/// states to the installed [AppBlocFeedbackDelegate].
///
/// Use this when you have your own page structure; use [AppBlocPage] when you
/// want the bloc provided for you as well. It reads the bloc from the widget
/// tree, so a [BlocProvider] for [B] must be above it.
///
/// The rebuild scope is deliberately narrow: [builder] runs only for ready
/// states and [listener] only for transient ones, so showing an error never
/// rebuilds the screen underneath it.
class AppBlocConsumer<B extends BlocBase<S>, S extends AppBlocState<R>, R>
    extends StatelessWidget {
  /// Creates a consumer that builds [builder] from the ready data of [B].
  const AppBlocConsumer({
    required this.builder,
    this.onError,
    this.onSuccess,
    this.onWarning,
    this.onInfo,
    super.key,
  });

  /// Builds the content from the always-available ready data.
  final Widget Function(BuildContext context, R ready) builder;

  /// Overrides the delegate's error handling for this subtree.
  final void Function(BuildContext context, Failure failure)? onError;

  /// Overrides the delegate's success handling for this subtree.
  final void Function(BuildContext context, String message)? onSuccess;

  /// Overrides the delegate's warning handling for this subtree.
  final void Function(BuildContext context, String message)? onWarning;

  /// Overrides the delegate's info handling for this subtree.
  final void Function(BuildContext context, String message)? onInfo;

  @override
  Widget build(BuildContext context) => BlocConsumer<B, S>(
        listenWhen: (_, current) => current.kind != AppBlocStateKind.ready,
        // Build for every ready state, including the one a bloc settles back on
        // after reporting a message. That settle-back is not redundant: the
        // snapshot carried by the message routinely differs from what was last
        // built — a failed save clears `isSaving`, for instance — so skipping it
        // would strand the UI on a spinner.
        buildWhen: (_, current) => current.kind == AppBlocStateKind.ready,
        listener: _handleTransient,
        builder: (context, state) => builder(context, state.ready),
      );

  void _handleTransient(BuildContext context, S state) {
    final delegate = AppBlocFeedback.maybeOf(context);
    final message = state.feedbackMessage;

    switch (state.kind) {
      case AppBlocStateKind.error:
        final failure = state.errorFailure;
        if (failure == null) return;
        (onError ?? delegate?.onError)?.call(context, failure);
      case AppBlocStateKind.success:
        if (message == null || message.isEmpty) return;
        (onSuccess ?? delegate?.onSuccess)?.call(context, message);
      case AppBlocStateKind.warning:
        if (message == null || message.isEmpty) return;
        (onWarning ?? delegate?.onWarning)?.call(context, message);
      case AppBlocStateKind.info:
        if (message == null || message.isEmpty) return;
        (onInfo ?? delegate?.onInfo)?.call(context, message);
      case AppBlocStateKind.ready:
        break;
    }
  }
}
