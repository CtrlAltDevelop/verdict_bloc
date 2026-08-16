## 0.1.0

Initial release.

- `AppBlocState<R>` — base state whose `ready` data is always available, so
  transient states never blank the screen.
- `AppBlocMessage<R>` — one transient state for error, success, warning and
  info reports, carrying the previous ready snapshot.
- `AppEvent`, `AppInit`, `AppRefresh` — common event bases.
- `AppBlocFeedbackDelegate` and `AppBlocFeedback` — install one implementation
  above your navigator to decide how reports are rendered; the package ships
  no error UI of its own.
- `AppBlocConsumer` — builds from ready data and routes transient states to
  the delegate, rebuilding only when the ready data actually changed.
- `AppBlocPage` — a screen base that also provides the bloc.
- `GenericListBloc<T, F>` with `PagedData<T>` and `GenericListReady<T, F>` —
  paginated, filterable, refreshable lists from three overrides, with
  out-of-order responses discarded.
