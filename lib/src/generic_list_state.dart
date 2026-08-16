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
    this.totalCount,
  });

  /// The items loaded so far, across every page fetched.
  final List<T>? items;

  /// Whether the last page came back full, implying there is more to fetch.
  final bool hasMore;

  /// The filter that produced [items].
  final F? activeFilter;

  /// Whether the first load failed, leaving [items] `null`.
  final bool initialLoadFailed;

  /// Whether a first page or a refresh is in flight.
  ///
  /// Appending a page does not set this — [items] stays rendered and the
  /// list shows its own footer spinner instead.
  final bool isLoading;

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
        totalCount,
      ];
}
