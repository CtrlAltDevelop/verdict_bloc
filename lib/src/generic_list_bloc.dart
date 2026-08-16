import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdict/verdict.dart';

import 'app_bloc_state.dart';
import 'paged_data.dart';

part 'generic_list_event.dart';
part 'generic_list_state.dart';

/// A paginated, filterable, refreshable list, over items [T] and filter [F].
///
/// Subclasses supply three things and get first load, pull-to-refresh,
/// infinite scroll, filtering and error reporting for free:
///
/// - [fetchPage] — call your API and adapt the response to [PagedData].
/// - [defaultFilter] — the filter used for the first load.
/// - [withPaging] — return a copy of a filter with paging applied.
///
/// ```dart
/// class TicketsBloc extends GenericListBloc<Ticket, TicketFilter> {
///   TicketsBloc(this._getTickets);
///
///   final GetTickets _getTickets;
///
///   @override
///   TicketFilter get defaultFilter => const TicketFilter();
///
///   @override
///   TicketFilter withPaging(
///     TicketFilter filter, {
///     required int skip,
///     required int take,
///   }) => filter.copyWith(skip: skip, take: take);
///
///   @override
///   Future<Result<PagedData<Ticket>>> fetchPage(TicketFilter filter) async =>
///       (await _getTickets(filter)).map(
///         (page) => PagedData(data: page.items, totalCount: page.total),
///       );
/// }
/// ```
///
/// Out-of-order responses are discarded: every fetch takes a sequence number
/// and a result whose number is stale — because a refresh or a filter change
/// overtook it — is dropped rather than applied over newer data.
abstract class GenericListBloc<T, F>
    extends Bloc<GenericListEvent<T, F>, AppBlocState<GenericListReady<T, F>>> {
  /// Creates the bloc in an empty ready state.
  GenericListBloc() : super(GenericListReady<T, F>()) {
    on<GenericListInit<T, F>>(_onInit);
    on<GenericListRefreshed<T, F>>(_onRefreshed);
    on<GenericListLoadMore<T, F>>(_onLoadMore);
    on<GenericListFilterApplied<T, F>>(_onFilterApplied);
  }

  /// How many items to request per page. Override to change it.
  int get pageSize => 20;

  bool _initialized = false;
  List<T>? _items;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  F? _activeFilter;
  int? _totalCount;
  int _requestId = 0;

  /// Fetches one page for [filter], with paging already applied.
  Future<Result<PagedData<T>>> fetchPage(F filter);

  /// The filter used for the first load and for a plain refresh.
  F get defaultFilter;

  /// Returns a copy of [filter] carrying [skip] and [take].
  F withPaging(F filter, {required int skip, required int take});

  GenericListReady<T, F> _buildReady({
    Object? items = _absent,
    bool? hasMore,
    F? activeFilter,
    bool initialLoadFailed = false,
    bool isLoading = false,
    Object? totalCount = _absent,
  }) {
    if (!identical(items, _absent)) _items = items as List<T>?;
    if (hasMore != null) _hasMore = hasMore;
    if (activeFilter != null) _activeFilter = activeFilter;
    if (!identical(totalCount, _absent)) _totalCount = totalCount as int?;

    return GenericListReady<T, F>(
      items: _items,
      hasMore: _hasMore,
      activeFilter: _activeFilter,
      initialLoadFailed: initialLoadFailed,
      isLoading: isLoading,
      totalCount: _totalCount,
    );
  }

  /// Reports [failure], then settles back on [settled].
  ///
  /// The message carries [settled] as its snapshot so the UI keeps rendering
  /// while the error is shown.
  void _emitFailure(
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
    Failure failure,
    GenericListReady<T, F> settled,
  ) {
    emit(
      AppBlocMessage<GenericListReady<T, F>>(
        previous: settled,
        type: MessageType.error,
        failure: failure,
      ),
    );
    emit(settled);
  }

  Future<void> _onInit(
    GenericListInit<T, F> event,
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
  ) async {
    if (_initialized) return;
    _initialized = true;
    emit(_buildReady(items: null, isLoading: true));
    await _fetch(emit, defaultFilter, skip: 0);
  }

  Future<void> _onRefreshed(
    GenericListRefreshed<T, F> event,
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
  ) async {
    final filter = _activeFilter ?? defaultFilter;
    _isLoadingMore = false;
    emit(_buildReady(isLoading: true));
    await _fetch(emit, filter, skip: 0, activeFilter: filter);
  }

  Future<void> _onFilterApplied(
    GenericListFilterApplied<T, F> event,
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
  ) async {
    if (event.prefetchedItems != null) {
      // Adopt the caller's results, and bump the sequence so any fetch still
      // in flight cannot land on top of them.
      _requestId++;
      _isLoadingMore = false;
      emit(
        _buildReady(
          items: event.prefetchedItems,
          hasMore: event.prefetchedHasMore,
          activeFilter: event.filter,
          totalCount: event.prefetchedTotalCount,
        ),
      );
      return;
    }

    _isLoadingMore = false;
    emit(_buildReady(items: null, isLoading: true));
    await _fetch(emit, event.filter, skip: 0, activeFilter: event.filter);
  }

  Future<void> _onLoadMore(
    GenericListLoadMore<T, F> event,
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
  ) async {
    final loaded = _items;
    if (loaded == null || !_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    final requestId = ++_requestId;
    final result = await fetchPage(
      withPaging(
        _activeFilter ?? defaultFilter,
        skip: loaded.length,
        take: pageSize,
      ),
    );
    if (isClosed || requestId != _requestId) return;
    _isLoadingMore = false;

    switch (result) {
      case Ok(:final value):
        final page = value.data ?? const [];
        emit(
          _buildReady(
            items: [...loaded, ...page],
            hasMore: page.length >= pageSize,
            // Keep the total the first page reported when a later page omits
            // it — plenty of APIs send the count only on the first response.
            totalCount: value.totalCount ?? _totalCount,
          ),
        );
      case Err(:final failure):
        _emitFailure(emit, failure, _buildReady());
    }
  }

  Future<void> _fetch(
    Emitter<AppBlocState<GenericListReady<T, F>>> emit,
    F filter, {
    required int skip,
    F? activeFilter,
  }) async {
    final requestId = ++_requestId;
    final result = await fetchPage(
      withPaging(filter, skip: skip, take: pageSize),
    );
    if (isClosed || requestId != _requestId) return;

    switch (result) {
      case Ok(:final value):
        final page = value.data ?? const [];
        emit(
          _buildReady(
            items: page,
            hasMore: page.length >= pageSize,
            activeFilter: activeFilter,
            totalCount: value.totalCount,
          ),
        );
      case Err(:final failure):
        // A failed first load leaves nothing to show, so the UI needs to
        // offer a retry rather than an empty state.
        _emitFailure(
          emit,
          failure,
          _buildReady(initialLoadFailed: _items == null),
        );
    }
  }
}
