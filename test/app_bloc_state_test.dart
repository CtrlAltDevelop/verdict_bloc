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

void main() {
  const ready = _Ready('data');

  group('a ready state', () {
    test('is of kind ready and carries no report', () {
      expect(ready.kind, AppBlocStateKind.ready);
      expect(ready.errorFailure, isNull);
      expect(ready.feedbackMessage, isNull);
      expect(ready.ready, ready);
    });
  });

  group('AppBlocMessage', () {
    test('keeps the previous ready snapshot available', () {
      const message = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.error,
      );

      expect(message.ready, ready);
      expect(message.ready.value, 'data');
    });

    test('maps each message type to its state kind', () {
      AppBlocStateKind kindOf(MessageType type) =>
          AppBlocMessage<_Ready>(previous: ready, type: type).kind;

      expect(kindOf(MessageType.error), AppBlocStateKind.error);
      expect(kindOf(MessageType.success), AppBlocStateKind.success);
      expect(kindOf(MessageType.warning), AppBlocStateKind.warning);
      expect(kindOf(MessageType.info), AppBlocStateKind.info);
    });

    test('surfaces the failure it was given', () {
      const failure = NetworkFailure(title: 'load', message: 'offline');
      const message = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.error,
        failure: failure,
      );

      expect(message.errorFailure, failure);
    });

    test('synthesises a failure for a message-only error', () {
      const message = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.error,
        title: 'Invalid',
        description: 'Enter an amount',
        referenceId: 'ref-9',
      );

      final failure = message.errorFailure;
      expect(failure, isA<ApiFailure>());
      expect(failure?.title, 'Invalid');
      expect(failure?.message, 'Enter an amount');
      expect(failure?.referenceId, 'ref-9');
    });

    test('an error with neither failure nor description has none', () {
      const message = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.error,
      );

      expect(message.errorFailure, isNull);
    });

    test('a non-error message never reports a failure', () {
      const message = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.success,
        description: 'Saved',
      );

      expect(message.errorFailure, isNull);
      expect(message.feedbackMessage, 'Saved');
    });

    test('compares by value so duplicate emits are dropped', () {
      const a = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.info,
        description: 'hi',
      );
      const b = AppBlocMessage<_Ready>(
        previous: ready,
        type: MessageType.info,
        description: 'hi',
      );

      expect(a, b);
    });
  });
}
