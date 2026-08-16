# verdict_bloc

BLoC state built on [`verdict`](https://pub.dev/packages/verdict), where
**transient states carry the last known good data**. Reporting an error or a
success never blanks the screen behind it.

Plus `GenericListBloc`, which turns a paginated endpoint into a list with
first-load, pull-to-refresh, infinite scroll and filtering in about twenty
lines.

```dart
final class ProfileReady extends AppBlocState<ProfileReady> {
  const ProfileReady({this.user, this.isLoading = false});

  final User? user;
  final bool isLoading;

  @override
  ProfileReady get ready => this;

  @override
  List<Object?> get props => [user, isLoading];
}
```

## The problem it solves

The usual sealed-state hierarchy looks like `Loading | Loaded | Error`. The
moment you emit `Error`, the data is gone from the state, so the screen has
nothing to render — a failed background refresh wipes the list the user was
reading, and you end up threading "but keep the old data" through every state
class by hand.

Here, `AppBlocState<R>.ready` is **always** available. Transient states are one
type, `AppBlocMessage`, which carries the previous ready snapshot along with
the thing to report. The UI keeps rendering; the report is delivered
separately.

```dart
void _onRefresh(Refresh event, Emitter<ProfileState> emit) async {
  switch (await _getProfile()) {
    case Ok(:final value):
      emit(ProfileReady(user: value));
    case Err(:final failure):
      // The screen keeps showing state.ready — only a toast appears.
      emit(AppBlocMessage(
        previous: state.ready,
        type: MessageType.error,
        failure: failure,
      ));
      emit(state.ready);
  }
}
```

## Install

```yaml
dependencies:
  verdict_bloc: ^0.1.0
```

`verdict` is re-exported, so one import gets you `Result`, `Failure` and
everything here.

## Reporting: bring your own UI

The package ships **no** error UI — a toast, a snackbar, a banner and a dialog
are all reasonable, and the copy is yours. Implement `AppBlocFeedbackDelegate`
once and install it above your navigator:

```dart
class SnackBarFeedback implements AppBlocFeedbackDelegate {
  const SnackBarFeedback();

  @override
  void onError(BuildContext context, Failure failure) {
    // Cancellation isn't an error; an expired session belongs on sign-in.
    if (failure is CancelledFailure || failure is AuthFailure) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(describe(failure))));
  }

  @override
  void onSuccess(BuildContext context, String message) { /* … */ }
  @override
  void onWarning(BuildContext context, String message) { /* … */ }
  @override
  void onInfo(BuildContext context, String message) { /* … */ }
}

AppBlocFeedback(
  delegate: const SnackBarFeedback(),
  child: MaterialApp.router(routerConfig: router),
);
```

With no delegate installed, reports are silently dropped rather than throwing —
which keeps widget tests and partially migrated apps working.

## Screens

`AppBlocPage` provides the bloc and wires everything up:

```dart
class ProfilePage extends AppBlocPage<ProfileBloc, ProfileState, ProfileReady> {
  const ProfilePage({super.key});

  @override
  ProfileBloc createBloc(BuildContext context) =>
      sl<ProfileBloc>()..add(const AppInit());

  @override
  Widget buildBody(BuildContext context, ProfileReady ready) =>
      ready.isLoading ? const LoadingView() : ProfileView(ready.user);
}
```

Override `manageBloc => false` when `createBloc` returns a shared or singleton
bloc that must outlive the page. Note that with `manageBloc: false`,
`createBloc` runs on every build of the page, so it must be a plain lookup —
put no `..add(SomeEvent())` on it, or the event fires again on each rebuild. Override any of `onError` / `onSuccess` /
`onWarning` / `onInfo` to handle reports differently on one screen; call
`super` if you also want the app-wide behaviour.

If you already have your own page structure, use `AppBlocConsumer` directly —
it takes a `builder` and expects a `BlocProvider` above it.

### Rebuild scope

`AppBlocConsumer` builds only for ready states and listens only for transient
ones, so the report and the render are cleanly separated: showing an error
does not itself rebuild the screen.

The ready state a bloc settles back on *after* a message does rebuild, and
should — that snapshot often differs from what is on screen. A failed save
clears `isSaving`, so skipping it would strand the button on a spinner.

`AppBlocState` extends `Equatable`, so list every field in `props`. Blocs drop
an emit that equals the current state, and that comparison is your `props`.

## Paginated lists

Subclass `GenericListBloc<T, F>` over your item type `T` and filter type `F`,
implement three members, and you have the whole list:

```dart
class TicketsBloc extends GenericListBloc<Ticket, TicketFilter> {
  TicketsBloc(this._getTickets);

  final GetTickets _getTickets;

  @override
  int get pageSize => 20; // optional; 20 is the default

  @override
  TicketFilter get defaultFilter => const TicketFilter();

  @override
  TicketFilter withPaging(
    TicketFilter filter, {
    required int skip,
    required int take,
  }) => filter.copyWith(skip: skip, take: take);

  @override
  Future<Result<PagedData<Ticket>>> fetchPage(TicketFilter filter) async =>
      (await _getTickets(filter))
          .map((page) => PagedData(data: page.items, totalCount: page.total));
}
```

Then drive it with four events:

| Event                       | Effect                                          |
| --------------------------- | ----------------------------------------------- |
| `GenericListInit`           | First load; ignored after the first time         |
| `GenericListRefreshed`      | Reload page one, keeping the active filter       |
| `GenericListLoadMore`       | Append the next page                             |
| `GenericListFilterApplied`  | Apply a filter and reload from page one          |

Because `GenericListInit` is ignored after the first time, a **retry** button
after a failed first load should dispatch `GenericListRefreshed`, not `Init`.

`GenericListReady` tells the three "empty" cases apart, so your UI can render
each properly instead of showing a spinner forever:

- `items == null`, `initialLoadFailed == false` → still loading.
- `items == null`, `initialLoadFailed == true` → first load failed; show retry.
- `items == []` → loaded, genuinely empty.

It also carries `hasMore`, `isLoading`, `activeFilter` and the server's
`totalCount` — the last one lets a filter sheet show a result count without a
fetch of its own.

Out-of-order responses are discarded: each fetch takes a sequence number, and
a response overtaken by a refresh or a filter change is dropped rather than
applied over newer data.

If a filter sheet already fetched its own preview results, hand them over
instead of refetching:

```dart
bloc.add(GenericListFilterApplied(
  filter,
  prefetchedItems: preview.items,
  prefetchedHasMore: preview.hasMore,
  prefetchedTotalCount: preview.total,
));
```

## Example

[`example/`](example) is a runnable app: a paginated list with pull-to-refresh,
infinite scroll, a filter, snackbar reporting, and an API that fails every
third request so you can watch the error path keep the list on screen.

## License

MIT — see [LICENSE](LICENSE).
