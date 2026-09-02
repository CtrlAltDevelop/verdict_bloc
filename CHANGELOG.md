## 1.1.0

Lowers the minimum toolchain from Dart 3.13 / Flutter 3.47 to **Dart 3.0 /
Flutter 3.10**, and widens every dependency to a range instead of a caret pin:

| Dependency     | Was       | Now                |
| -------------- | --------- | ------------------ |
| `equatable`    | `^2.1.0`  | `>=2.0.5 <3.0.0`   |
| `flutter_bloc` | `^9.1.1`  | `>=8.1.0 <10.0.0`  |
| `verdict`      | `^1.0.0`  | `>=1.1.0 <2.0.0`   |

Dart 3.0 is the package's real floor — it uses sealed classes, class modifiers
and pattern matching, and nothing newer. `flutter_bloc` 8 is now supported
alongside 9. The whole suite is verified against the lowest allowed version of
every dependency as well as the highest, and CI runs both.

This requires `verdict` 1.1.0, which lowered its own floor to Dart 3.0; the API
is unchanged from 1.0.0.

Adds `GenericListReady.isLoadingMore`, which is `true` only while a page is
being appended. Previously nothing in the state distinguished "another page
exists" from "another page is loading", so a footer spinner had to be keyed to
`hasMore` — which spins between fetches and keeps spinning after an append
fails. `isLoading` is unchanged and still covers a first load or a refresh.

`hasMore` now honours the server's `totalCount` when one is reported: once the
loaded items cover the total, the list ends. A final page that came back
exactly full previously cost one extra round trip to discover it was the last.
With no reported total the behaviour is unchanged — a short page still ends the
list — and an empty page always ends it, whatever the total claims.

Both changes are additive: `GenericListReady`'s constructor gains an optional
named parameter, and existing UI keyed to `hasMore` keeps working.

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
