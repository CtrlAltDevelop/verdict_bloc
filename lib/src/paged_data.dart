/// One page of results, plus the server's total where it reports one.
///
/// Adapt whatever shape your API returns into this so [GenericListBloc] can
/// work with any endpoint:
///
/// ```dart
/// @override
/// Future<Result<PagedData<Ticket>>> fetchPage(TicketFilter filter) async {
///   final result = await _getTickets(filter);
///   return result.map(
///     (response) => PagedData(
///       data: response.items,
///       totalCount: response.total,
///     ),
///   );
/// }
/// ```
class PagedData<T> {
  /// Creates a page carrying [data] and an optional [totalCount].
  const PagedData({this.data, this.totalCount});

  /// The items in this page. `null` and empty are both treated as "no items".
  final List<T>? data;

  /// Total number of items matching the filter across all pages, when the
  /// server reports one.
  final int? totalCount;
}
