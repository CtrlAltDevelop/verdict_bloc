part of 'generic_list_bloc.dart';

/// Events accepted by [GenericListBloc], over items [T] and filter [F].
sealed class GenericListEvent<T, F> extends Equatable {
  /// Creates an event.
  const GenericListEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the first page using [GenericListBloc.defaultFilter].
///
/// Ignored after the first time, so dispatching it from a widget that
/// rebuilds is safe.
final class GenericListInit<T, F> extends GenericListEvent<T, F> {
  /// Creates the initial-load event.
  const GenericListInit();
}

/// Reloads the first page, keeping the active filter.
final class GenericListRefreshed<T, F> extends GenericListEvent<T, F> {
  /// Creates the refresh event.
  const GenericListRefreshed();
}

/// Appends the next page.
///
/// Ignored when a page is already in flight, when nothing has loaded yet, or
/// when the last page came back short.
final class GenericListLoadMore<T, F> extends GenericListEvent<T, F> {
  /// Creates the load-more event.
  const GenericListLoadMore();
}

/// Applies [filter] and reloads from the first page.
///
/// If the caller already fetched the results — a filter sheet that previews
/// its own count, say — pass them as [prefetchedItems] with the matching
/// [prefetchedHasMore] and [prefetchedTotalCount] and the bloc adopts them
/// instead of refetching.
final class GenericListFilterApplied<T, F> extends GenericListEvent<T, F> {
  /// Creates the filter-applied event.
  const GenericListFilterApplied(
    this.filter, {
    this.prefetchedItems,
    this.prefetchedHasMore = false,
    this.prefetchedTotalCount,
  });

  /// The filter to apply.
  final F filter;

  /// Results the caller already fetched for [filter], if any.
  final List<T>? prefetchedItems;

  /// Whether [prefetchedItems] is a full page with more behind it.
  final bool prefetchedHasMore;

  /// Server-reported total for [filter], if the caller has it.
  final int? prefetchedTotalCount;

  @override
  List<Object?> get props => [
        filter,
        prefetchedItems,
        prefetchedHasMore,
        prefetchedTotalCount,
      ];
}
