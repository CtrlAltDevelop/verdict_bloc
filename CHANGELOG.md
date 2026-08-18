## 1.0.1

Shortens the package description to pub.dev's 180-character limit and relaxes
the `verdict` dependency to `^1.0.0` so it no longer pins a single version.

## 1.0.0

Raises the minimum toolchain to Dart 3.13.0 and Flutter 3.47.0. Projects still
on an older SDK should stay on 0.1.0, which they continue to resolve to.

`Result`, `Failure`, `FailureMapper`, `guard` / `guardSync` and `failureOrigin`
are no longer vendored here — they now come from
[`verdict`](https://pub.dev/packages/verdict) 1.0.0, which this package
re-exports in full. No import changes are needed: the names are still reachable
from `package:verdict_bloc/verdict_bloc.dart`, and the types are unchanged.

The upside is that the types are now *shared* rather than merely identical. A
pure-Dart layer depending on `verdict` produces `Failure`s your blocs accept
directly — previously the two packages' types were deliberately independent and
could not be mixed.

## 0.1.0

Initial release.

The package is self-contained — it carries its own `Result` and `Failure` and
depends on no other package for them. The sibling package
[`verdict`](https://pub.dev/packages/verdict) offers the same two types
without Flutter, for pure-Dart code. They are deliberately independent: a
`Failure` from one is not a `Failure` from the other.

- `AppBlocState<R>` — base state whose `ready` data is always available, so
  transient states never blank the screen.
- `AppBlocMessage<R>` — one transient state for error, success, warning and
  info reports, carrying the previous ready snapshot.
- `AppEvent`, `AppInit`, `AppRefresh` — common event bases.
- `AppBlocFeedbackDelegate` and `AppBlocFeedback` — install one implementation
  above your navigator to decide how reports are rendered; the package ships
  no error UI of its own.
- `AppBlocConsumer` — builds from ready data and routes transient states to
  the delegate.
- `AppBlocPage` — a screen base that also provides the bloc.
- `GenericListBloc<T, F>` with `PagedData<T>` and `GenericListReady<T, F>` —
  paginated, filterable, refreshable lists from three overrides, with
  out-of-order responses discarded.
- `Result<T>` / `Ok` / `Err` / `Unit`, the sealed `Failure` hierarchy, the
  `FailureMapper` composition seam, `guard` / `guardSync` and `failureOrigin`.
