/// BLoC state built on [verdict](https://pub.dev/packages/verdict), where
/// transient error and success states carry the last known good data — so
/// reporting a failure never blanks the screen behind it.
///
/// Start with [AppBlocState] for your states, [AppBlocPage] or
/// [AppBlocConsumer] for your screens, and one [AppBlocFeedbackDelegate] to
/// decide how reports are rendered. [GenericListBloc] covers paginated lists.
library;

// Re-exported in full so a single `verdict_bloc` import is enough: states and
// blocs here traffic in Result and Failure, and consumers need the Failure
// subtypes to switch over them.
export 'package:verdict/verdict.dart';

export 'src/app_bloc_consumer.dart';
export 'src/app_bloc_event.dart';
export 'src/app_bloc_feedback.dart';
export 'src/app_bloc_page.dart';
export 'src/app_bloc_state.dart';
export 'src/generic_list_bloc.dart';
export 'src/paged_data.dart';
