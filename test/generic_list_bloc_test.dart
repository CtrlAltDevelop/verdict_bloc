import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdict_bloc/verdict_bloc.dart';

class _Filter {
  const _Filter({this.query = '', this.skip = 0, this.take = 0});

  final String query;
  final int skip;
  final int take;

  _Filter copyWith({int? skip, int? take}) =>
      _Filter(query: query, skip: skip ?? this.skip, take: take ?? this.take);
}

const _failure = NetworkFailure(title: 'fetchPage', message: 'offline');

class _TestBloc extends GenericListBloc<int, _Filter> {
  _TestBloc(this.responses);

  /// Queued one per call, so a test can script several pages in order.
  final List<Result<PagedData<int>>> responses;
  final List<_Filter> requested = [];

  int _call = 0;

  @override
  int get pageSize => 2;

  @override
  _Filter get defaultFilter => const _Filter();

  @override
  _Filter withPaging(_Filter filter, {required int skip, required int take}) =>
      filter.copyWith(skip: skip, take: take);

  @override
  Future<Result<PagedData<int>>> fetchPage(_Filter filter) async {
    requested.add(filter);
    final index = _call < responses.length ? _call : responses.length - 1;
    _call++;
    return responses[index];
  }
}

/// A bloc whose first fetch resolves only after a delay, so a second event
/// can overtake it and prove the stale response is discarded.
class _SlowFirstBloc extends _TestBloc {
  _SlowFirstBloc(super.responses);

  int _calls = 0;

  @override
  Future<Result<PagedData<int>>> fetchPage(_Filter filter) async {
    requested.add(filter);
    if (_calls++ == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Ok(PagedData(data: [1, 1]));
    }
    return const Ok(PagedData(data: [9]));
  }
}

void main() {
  group('init', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'emits a loading state then the first page',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 5)),
      ]),
      act: (bloc) => bloc.add(const GenericListInit()),
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.items, 'items', isNull),
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [1, 2])
            .having((s) => s.hasMore, 'hasMore', isTrue)
            .having((s) => s.totalCount, 'totalCount', 5)
            .having((s) => s.isLoading, 'isLoading', isFalse),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'requests the first page with paging applied',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) => bloc.add(const GenericListInit()),
      verify: (bloc) {
        expect(bloc.requested.single.skip, 0);
        expect(bloc.requested.single.take, 2);
      },
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'ignores a second init',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListInit());
      },
      verify: (bloc) => expect(bloc.requested, hasLength(1)),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a short first page means there is no more to load',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) => bloc.add(const GenericListInit()),
      skip: 1,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.hasMore, 'hasMore', isFalse),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'an empty page loads as empty, not as still-loading',
      build: () => _TestBloc([const Ok(PagedData(data: []))]),
      act: (bloc) => bloc.add(const GenericListInit()),
      skip: 1,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', isEmpty)
            .having((s) => s.initialLoadFailed, 'initialLoadFailed', isFalse),
      ],
    );
  });

  group('a failed first load', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'reports the failure and then flags the retry state',
      build: () => _TestBloc([const Err(_failure)]),
      act: (bloc) => bloc.add(const GenericListInit()),
      skip: 1,
      expect: () => [
        isA<AppBlocMessage<GenericListReady<int, _Filter>>>()
            .having((s) => s.kind, 'kind', AppBlocStateKind.error)
            .having((s) => s.errorFailure, 'errorFailure', _failure)
            .having(
              (s) => s.ready.initialLoadFailed,
              'snapshot keeps the retry flag',
              isTrue,
            ),
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.initialLoadFailed, 'initialLoadFailed', isTrue)
            .having((s) => s.items, 'items', isNull)
            .having((s) => s.isLoading, 'isLoading', isFalse),
      ],
    );
  });

  group('load more', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'appends the next page to the existing items',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Ok(PagedData(data: [3, 4])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      skip: 2,
      expect: () => [
        // The append is announced before it lands, so the footer spinner is
        // visible for the whole fetch rather than only after it.
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [1, 2])
            .having((s) => s.isLoadingMore, 'isLoadingMore', isTrue)
            .having((s) => s.isLoading, 'isLoading', isFalse),
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [1, 2, 3, 4])
            .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'requests the next page with skip past the loaded items',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Ok(PagedData(data: [3, 4])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) => expect(bloc.requested.last.skip, 2),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'does nothing before anything has loaded',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) => bloc.add(const GenericListLoadMore()),
      expect: () => <Object>[],
      verify: (bloc) => expect(bloc.requested, isEmpty),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'does nothing when the last page was short',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) => expect(bloc.requested, hasLength(1)),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'keeps the first page total when a later page omits it',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 50)),
        const Ok(PagedData(data: [3, 4])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      skip: 3,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.totalCount, 'totalCount', 50),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'adopts a refreshed total when a later page reports one',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 50)),
        const Ok(PagedData(data: [3, 4], totalCount: 48)),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      skip: 3,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.totalCount, 'totalCount', 48),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'keeps the loaded items when appending fails',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Err(_failure),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      skip: 3,
      expect: () => [
        isA<AppBlocMessage<GenericListReady<int, _Filter>>>()
            .having((s) => s.errorFailure, 'errorFailure', _failure)
            .having((s) => s.ready.items, 'items survive', [1, 2]).having(
          (s) => s.ready.initialLoadFailed,
          'not a first-load failure',
          isFalse,
        ),
        // The footer spinner must clear on failure, or it spins forever.
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [1, 2])
            .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'can append again after a failed append',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Err(_failure),
        const Ok(PagedData(data: [3, 4])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) => expect(bloc.requested, hasLength(3)),
    );
  });

  group('refresh', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'reloads from the first page and replaces the items',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Ok(PagedData(data: [9])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListRefreshed());
      },
      skip: 2,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.items, 'keeps old items while loading', [1, 2]),
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [9]),
      ],
    );
  });

  group('filtering', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'refetches from the first page with the new filter',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
        const Ok(PagedData(data: [7])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListFilterApplied(_Filter(query: 'x')));
      },
      skip: 2,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.isLoading, 'isLoading', isTrue)
            .having((s) => s.items, 'clears while loading', isNull),
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [7]).having(
                (s) => s.activeFilter?.query, 'activeFilter', 'x'),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'adopts prefetched results without fetching',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1]))
      ]),
      act: (bloc) => bloc.add(
        const GenericListFilterApplied(
          _Filter(query: 'x'),
          prefetchedItems: [5, 6],
          prefetchedHasMore: true,
          prefetchedTotalCount: 12,
        ),
      ),
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [5, 6])
            .having((s) => s.hasMore, 'hasMore', isTrue)
            .having((s) => s.totalCount, 'totalCount', 12)
            .having((s) => s.activeFilter?.query, 'activeFilter', 'x'),
      ],
      verify: (bloc) => expect(bloc.requested, isEmpty),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'appends onto prefetched results using the new filter',
      build: () => _TestBloc([
        const Ok(PagedData(data: [7, 8]))
      ]),
      act: (bloc) async {
        bloc.add(
          const GenericListFilterApplied(
            _Filter(query: 'x'),
            prefetchedItems: [5, 6],
            prefetchedHasMore: true,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) {
        expect(bloc.requested.single.query, 'x');
        expect(bloc.requested.single.skip, 2);
      },
    );
  });

  group('out-of-order responses', () {
    blocTest<_SlowFirstBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a stale in-flight fetch never lands over newer data',
      build: () => _SlowFirstBloc(const []),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListRefreshed());
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.requested, hasLength(2));
        expect(
          bloc.state.ready.items,
          [9],
          reason: 'the slow first response must not overwrite the refresh',
        );
      },
    );
  });

  group('hasMore', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a full first page that already covers the total ends the list',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 2)),
      ]),
      act: (bloc) => bloc.add(const GenericListInit()),
      skip: 1,
      expect: () => [
        isA<GenericListReady<int, _Filter>>()
            .having((s) => s.items, 'items', [1, 2])
            .having((s) => s.hasMore, 'hasMore', isFalse),
      ],
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a known total stops paging without an extra empty round trip',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 4)),
        const Ok(PagedData(data: [3, 4], totalCount: 4)),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
        await Future<void>.delayed(Duration.zero);
        // Ignored: the total says everything is loaded.
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) {
        expect(bloc.state.ready.items, [1, 2, 3, 4]);
        expect(bloc.state.ready.hasMore, isFalse);
        expect(
          bloc.requested,
          hasLength(2),
          reason: 'the total is authoritative, so no third page is fetched',
        );
      },
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'an empty page ends the list even when the total disagrees',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2], totalCount: 99)),
        const Ok(PagedData(data: [], totalCount: 99)),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
      },
      verify: (bloc) => expect(
        bloc.state.ready.hasMore,
        isFalse,
        reason: 'trusting the total here would retry the empty page forever',
      ),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a full page with no reported total still implies more',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
      ]),
      act: (bloc) => bloc.add(const GenericListInit()),
      verify: (bloc) => expect(bloc.state.ready.hasMore, isTrue),
    );
  });

  group('isLoadingMore', () {
    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'a refresh overtaking an append clears the footer spinner',
      build: () => _SlowLoadMoreBloc(const []),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListLoadMore());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListRefreshed());
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) => expect(
        bloc.state.ready.isLoadingMore,
        isFalse,
        reason: 'the discarded append must not leave the spinner stuck on',
      ),
    );

    blocTest<_TestBloc, AppBlocState<GenericListReady<int, _Filter>>>(
      'is never set by a first load or a refresh',
      build: () => _TestBloc([
        const Ok(PagedData(data: [1, 2])),
      ]),
      act: (bloc) async {
        bloc.add(const GenericListInit());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GenericListRefreshed());
      },
      verify: (bloc) => expect(bloc.state.ready.isLoadingMore, isFalse),
    );
  });
}

/// A bloc whose *append* is slow, so a refresh can overtake it.
class _SlowLoadMoreBloc extends _TestBloc {
  _SlowLoadMoreBloc(super.responses);

  int _calls = 0;

  @override
  Future<Result<PagedData<int>>> fetchPage(_Filter filter) async {
    requested.add(filter);
    if (_calls++ == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Ok(PagedData(data: [7, 8]));
    }
    return const Ok(PagedData(data: [1, 2]));
  }
}
