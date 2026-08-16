import 'package:equatable/equatable.dart';
import 'failure.dart';

/// What a state represents, so listeners can react without `is` checks.
enum AppBlocStateKind {
  /// Normal state carrying current data.
  ready,

  /// Transient state reporting that something failed.
  error,

  /// Transient state reporting a caution.
  warning,

  /// Transient state carrying neutral information.
  info,

  /// Transient state reporting that something succeeded.
  success,
}

/// The flavour of an [AppBlocMessage].
enum MessageType {
  /// Something failed.
  error,

  /// Something succeeded.
  success,

  /// A caution worth surfacing.
  warning,

  /// Neutral information.
  info,
}

/// Base class for a bloc's state hierarchy, where [R] is the concrete
/// "ready" type holding the screen's data.
///
/// The point of this class is that **[ready] is always available**. Transient
/// states — an error toast, a success message — carry the last known ready
/// snapshot with them, so a failed refresh reports the error without blanking
/// the screen the user is looking at.
///
/// Define one ready state per feature and emit [AppBlocMessage] for transient
/// reports instead of adding per-feature error and success states:
///
/// ```dart
/// final class ProfileReady extends AppBlocState<ProfileReady> {
///   const ProfileReady({this.user, this.isLoading = false});
///
///   final User? user;
///   final bool isLoading;
///
///   @override
///   ProfileReady get ready => this;
///
///   @override
///   List<Object?> get props => [user, isLoading];
/// }
/// ```
abstract class AppBlocState<R> extends Equatable {
  /// Creates a state.
  const AppBlocState();

  /// The latest ready data, whatever this state's [kind] is.
  R get ready;

  /// What this state represents. Defaults to [AppBlocStateKind.ready].
  AppBlocStateKind get kind => AppBlocStateKind.ready;

  /// The failure, when [kind] is [AppBlocStateKind.error]; otherwise `null`.
  Failure? get errorFailure => null;

  /// Human-readable text for a transient state; otherwise `null`.
  String? get feedbackMessage => null;

  @override
  List<Object?> get props => [];
}

/// A transient state reporting something to the user while [previous] keeps
/// the UI rendered.
///
/// Emit it, then immediately emit the ready state again so the report fires
/// once and the bloc settles back:
///
/// ```dart
/// emit(AppBlocMessage(
///   previous: state.ready,
///   type: MessageType.error,
///   failure: failure,
/// ));
/// emit(state.ready);
/// ```
final class AppBlocMessage<R> extends AppBlocState<R> {
  /// Creates a transient message carrying the last ready snapshot.
  const AppBlocMessage({
    required this.previous,
    required this.type,
    this.title,
    this.description,
    this.referenceId,
    this.failure,
  });

  /// The last ready snapshot, so the UI stays intact while this is shown.
  final R previous;

  /// Whether this reports an error, success, warning or information.
  final MessageType type;

  /// Optional short heading for the report.
  final String? title;

  /// Optional body text for the report.
  final String? description;

  /// Optional server correlation id worth showing for support follow-up.
  final String? referenceId;

  /// The failure behind an error message.
  ///
  /// Kept as a [Failure] rather than flattened to a string so the UI can tell
  /// a server error from a local one and choose its copy accordingly.
  final Failure? failure;

  @override
  R get ready => previous;

  @override
  AppBlocStateKind get kind => switch (type) {
        MessageType.error => AppBlocStateKind.error,
        MessageType.success => AppBlocStateKind.success,
        MessageType.warning => AppBlocStateKind.warning,
        MessageType.info => AppBlocStateKind.info,
      };

  @override
  Failure? get errorFailure {
    if (failure != null) return failure;
    // A message-only error — local validation, say — has no underlying
    // Failure. Surface it as one anyway so error handling has a single shape.
    return type == MessageType.error && description != null
        ? ApiFailure(
            title: title ?? 'Error',
            message: description!,
            referenceId: referenceId,
          )
        : null;
  }

  @override
  String? get feedbackMessage => description;

  @override
  List<Object?> get props => [
        previous,
        type,
        title,
        description,
        referenceId,
        failure,
      ];
}
