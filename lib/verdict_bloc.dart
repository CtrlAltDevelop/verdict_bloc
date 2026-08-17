/// BLoC state where transient error and success states carry the last known
/// good data — so reporting a failure never blanks the screen behind it.
///
/// Start with [AppBlocState] for your states, [AppBlocPage] or
/// [AppBlocConsumer] for your screens, and one [AppBlocFeedbackDelegate] to
/// decide how reports are rendered. [GenericListBloc] covers paginated lists.
///
/// [Result] and [Failure] come from
/// [verdict](https://pub.dev/packages/verdict), which this package re-exports
/// in full — importing `verdict_bloc` is enough to get them. Pure-Dart layers
/// that want the same two types without Flutter can depend on `verdict`
/// directly, and both halves of the app then speak in one `Failure` type.
library;

export 'package:verdict/verdict.dart';

export 'src/app_bloc_consumer.dart';
export 'src/app_bloc_event.dart';
export 'src/app_bloc_feedback.dart';
export 'src/app_bloc_page.dart';
export 'src/app_bloc_state.dart';
export 'src/generic_list_bloc.dart';
export 'src/paged_data.dart';
