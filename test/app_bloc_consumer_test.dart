import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdict_bloc/verdict_bloc.dart';

final class _Ready extends AppBlocState<_Ready> {
  const _Ready(this.value);

  final String value;

  @override
  _Ready get ready => this;

  @override
  List<Object?> get props => [value];
}

class _Cubit extends Cubit<AppBlocState<_Ready>> {
  _Cubit() : super(const _Ready('first'));

  void setReady(String value) => emit(_Ready(value));

  void report(MessageType type, {String? description, Failure? failure}) {
    final previous = state.ready;
    emit(
      AppBlocMessage<_Ready>(
        previous: previous,
        type: type,
        description: description,
        failure: failure,
      ),
    );
    emit(previous);
  }

  /// Reports [failure] but settles on [next] rather than the current state,
  /// the way a bloc does when an operation both fails and changes the screen.
  void reportAndSettleOn(_Ready next, {required Failure failure}) {
    emit(
      AppBlocMessage<_Ready>(
        previous: next,
        type: MessageType.error,
        failure: failure,
      ),
    );
    emit(next);
  }
}

class _RecordingDelegate implements AppBlocFeedbackDelegate {
  final List<String> calls = [];

  @override
  void onError(BuildContext context, Failure failure) =>
      calls.add('error:${failure.message}');

  @override
  void onSuccess(BuildContext context, String message) =>
      calls.add('success:$message');

  @override
  void onWarning(BuildContext context, String message) =>
      calls.add('warning:$message');

  @override
  void onInfo(BuildContext context, String message) =>
      calls.add('info:$message');
}

void main() {
  late _Cubit cubit;
  late _RecordingDelegate delegate;
  late int builds;

  setUp(() {
    cubit = _Cubit();
    delegate = _RecordingDelegate();
    builds = 0;
  });

  tearDown(() => cubit.close());

  Widget harness({AppBlocFeedbackDelegate? feedback}) {
    final Widget consumer = BlocProvider<_Cubit>.value(
      value: cubit,
      child: AppBlocConsumer<_Cubit, AppBlocState<_Ready>, _Ready>(
        builder: (context, ready) {
          builds++;
          return Text(ready.value, textDirection: TextDirection.ltr);
        },
      ),
    );
    return feedback == null
        ? consumer
        : AppBlocFeedback(delegate: feedback, child: consumer);
  }

  testWidgets('builds from the ready data', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));

    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('routes each transient state to the delegate', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));

    cubit.report(
      MessageType.error,
      failure: const NetworkFailure(title: 't', message: 'offline'),
    );
    cubit.report(MessageType.success, description: 'saved');
    cubit.report(MessageType.warning, description: 'careful');
    cubit.report(MessageType.info, description: 'fyi');
    await tester.pumpAndSettle();

    expect(delegate.calls, [
      'error:offline',
      'success:saved',
      'warning:careful',
      'info:fyi',
    ]);
  });

  testWidgets('keeps rendering the last ready data during a report', (
    tester,
  ) async {
    await tester.pumpWidget(harness(feedback: delegate));
    cubit.setReady('loaded');
    await tester.pumpAndSettle();

    cubit.report(
      MessageType.error,
      failure: const NetworkFailure(title: 't', message: 'offline'),
    );
    await tester.pumpAndSettle();

    expect(find.text('loaded'), findsOneWidget);
  });

  testWidgets('a report itself never rebuilds the body', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));
    final before = builds;

    // The message state is not a ready state, so it is not built. The bloc
    // settling back afterwards is what rebuilds — exactly once.
    cubit.report(MessageType.info, description: 'fyi');
    await tester.pumpAndSettle();

    expect(builds, before + 1);
  });

  testWidgets('settling back after a report renders the new snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(harness(feedback: delegate));

    // Mirrors a failed save: the report carries a snapshot that differs from
    // what is on screen, so the settle-back must reach the builder.
    cubit.reportAndSettleOn(
      const _Ready('after-failure'),
      failure: const NetworkFailure(title: 't', message: 'offline'),
    );
    await tester.pumpAndSettle();

    expect(find.text('after-failure'), findsOneWidget);
    expect(delegate.calls, ['error:offline']);
  });

  testWidgets('a ready change does rebuild the body', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));
    final before = builds;

    cubit.setReady('second');
    await tester.pumpAndSettle();

    expect(builds, greaterThan(before));
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('stays silent when no delegate is installed', (tester) async {
    await tester.pumpWidget(harness());

    cubit.report(MessageType.success, description: 'saved');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('drops an empty message instead of reporting it', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));

    cubit.report(MessageType.success, description: '');
    await tester.pumpAndSettle();

    expect(delegate.calls, isEmpty);
  });

  testWidgets('drops an error carrying no failure', (tester) async {
    await tester.pumpWidget(harness(feedback: delegate));

    cubit.report(MessageType.error);
    await tester.pumpAndSettle();

    expect(delegate.calls, isEmpty);
  });
}
