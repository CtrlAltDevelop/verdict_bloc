part of 'generic_list_bloc.dart';

const Object _absent = Object();

/// The ready state of a [GenericListBloc].
///
/// [items] distinguishes three situations that a plain empty list cannot:
///
/// - `null` with [initialLoadFailed] `false` — still loading, nothing yet.
/// - `null` with [initialLoadFailed] `true` — the first load failed; show a
///   retry rather than an empty state.
/// - `[]` — loaded successfully and there is genuinely nothing to show.
final class GenericListReady<T, F>
    extends AppBlocState<GenericListReady<T, F>> {
  /// Creates a ready state.
  const GenericListReady({
    this.items,
    this.hasMore = false,
    this.activeFilter,
    this.initialLoadFailed = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.totalCount,
  });

  /// The items loaded so far, across every page fetched.
  final List<T>? items;

  /// Whether another page can still be fetched.
  ///
  /// When the server reports a [totalCount] that total decides; otherwise a
  /// full last page is taken to imply more. This says a page *exists*, not
  /// that one is being fetched — for a footer spinner use [isLoadingMore].
  final bool hasMore;

  /// The filter that produced [items].
  final F? activeFilter;

  /// Whether the first load failed, leaving [items] `null`.
  final bool initialLoadFailed;

  /// Whether a first page or a refresh is in flight.
  ///
  /// Appending a page sets [isLoadingMore] instead, so [items] stays rendered
  /// and the list shows its own footer spinner rather than a full-screen one.
  final bool isLoading;

  /// Whether another page is being appended right now.
  ///
  /// Drive the list's footer spinner from this rather than from [hasMore]:
  /// [hasMore] only says another page *exists*, so a footer keyed to it spins
  /// forever between fetches and keeps spinning after an append fails.
  final bool isLoadingMore;

  /// Server-reported total for [activeFilter], from the load that produced
  /// [items].
  ///
  /// Lets a filter sheet show a result count without a fetch of its own.
  final int? totalCount;

  @override
  GenericListReady<T, F> get ready => this;

  @override
  List<Object?> get props => [
        items,
        hasMore,
        activeFilter,
        initialLoadFailed,
        isLoading,
        isLoadingMore,
        totalCount,
      ];
}
