/// BLoC state where transient error and success states carry the last known
/// good data — so reporting a failure never blanks the screen behind it.
///
/// Start with [AppBlocState] for your states, [AppBlocPage] or
/// [AppBlocConsumer] for your screens, and one [AppBlocFeedbackDelegate] to
/// decide how reports are rendered. [GenericListBloc] covers paginated lists.
///
/// This package is self-contained: it carries its own [Result] and [Failure]
/// and depends on no other package for them. The sibling package
/// [verdict](https://pub.dev/packages/verdict) offers the same two types on
/// their own, for pure-Dart code that wants them without Flutter. The types
/// are independent — a `Failure` from one package is not a `Failure` from the
/// other — so pick one per layer rather than mixing them.
library;

export 'src/app_bloc_consumer.dart';
export 'src/app_bloc_event.dart';
export 'src/app_bloc_feedback.dart';
export 'src/app_bloc_page.dart';
export 'src/app_bloc_state.dart';
export 'src/failure.dart';
export 'src/failure_mapper.dart';
export 'src/generic_list_bloc.dart';
export 'src/paged_data.dart';
export 'src/result.dart';
