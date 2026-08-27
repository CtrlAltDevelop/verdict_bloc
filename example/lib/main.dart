import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdict_bloc/verdict_bloc.dart';

import 'profile_page.dart';

void main() => runApp(const ExampleApp());

// ─── Data ───────────────────────────────────────────────────────────────────

/// Stands in for a real API. Fails every third page so the error path is
/// visible, and runs out of results after five pages.
class FakeApi {
  int _calls = 0;

  Future<Result<PagedData<String>>> fetch({
    required String query,
    required int skip,
    required int take,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (++_calls % 3 == 0) {
      return const Err(
        NetworkFailure(title: 'FakeApi.fetch', message: 'Connection lost'),
      );
    }

    if (skip >= 100) return const Ok(PagedData(data: [], totalCount: 100));

    return Ok(
      PagedData(
        data: List.generate(
          take,
          (i) => '${query.isEmpty ? 'Item' : query} ${skip + i + 1}',
        ),
        totalCount: 100,
      ),
    );
  }
}

/// A filter is any type you like — the bloc only needs [withPaging] to know
/// how to page it.
class ItemFilter {
  const ItemFilter({this.query = '', this.skip = 0, this.take = 20});

  final String query;
  final int skip;
  final int take;

  ItemFilter copyWith({String? query, int? skip, int? take}) => ItemFilter(
        query: query ?? this.query,
        skip: skip ?? this.skip,
        take: take ?? this.take,
      );
}

// ─── Bloc ───────────────────────────────────────────────────────────────────

class ItemsBloc extends GenericListBloc<String, ItemFilter> {
  ItemsBloc(this._api);

  final FakeApi _api;

  @override
  int get pageSize => 20;

  @override
  ItemFilter get defaultFilter => const ItemFilter();

  @override
  ItemFilter withPaging(
    ItemFilter filter, {
    required int skip,
    required int take,
  }) =>
      filter.copyWith(skip: skip, take: take);

  @override
  Future<Result<PagedData<String>>> fetchPage(ItemFilter filter) => _api.fetch(
        query: filter.query,
        skip: filter.skip,
        take: filter.take,
      );
}

// ─── Feedback ───────────────────────────────────────────────────────────────

/// Decides how transient reports are rendered. Swap SnackBars for your own
/// toasts, banners or dialogs — the package has no opinion.
class SnackBarFeedback implements AppBlocFeedbackDelegate {
  const SnackBarFeedback();

  @override
  void onError(BuildContext context, Failure failure) {
    // Cancellation is not an error, and an expired session belongs on the
    // sign-in screen rather than in a snackbar.
    if (failure is CancelledFailure || failure is AuthFailure) return;
    _show(context, _describe(failure), Colors.red.shade700);
  }

  @override
  void onSuccess(BuildContext context, String message) =>
      _show(context, message, Colors.green.shade700);

  @override
  void onWarning(BuildContext context, String message) =>
      _show(context, message, Colors.orange.shade800);

  @override
  void onInfo(BuildContext context, String message) =>
      _show(context, message, Colors.blueGrey.shade700);

  void _show(BuildContext context, String message, Color background) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: background,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Copy comes from the failure's *type*, never from `Failure.title` — that
  /// field holds a diagnostic origin, not display text.
  String _describe(Failure failure) => switch (failure) {
        ApiFailure(:final message) => message,
        NetworkFailure() => 'Check your connection and try again.',
        AuthFailure() => 'Please sign in again.',
        CancelledFailure() => 'Cancelled.',
        UnknownFailure() => 'Something went wrong.',
      };
}

// ─── UI ─────────────────────────────────────────────────────────────────────

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => AppBlocFeedback(
        // One delegate above the navigator, and every screen reports the same way.
        delegate: const SnackBarFeedback(),
        child: MaterialApp(
          title: 'verdict_bloc',
          theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
          home: const HomePage(),
        ),
      );
}

/// Two samples: the pattern by hand, and the same pattern wrapped up in
/// [GenericListBloc].
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('verdict_bloc')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile form'),
              subtitle: const Text(
                'A hand-written bloc. Saving fails every other time and the form '
                'never loses what you typed.',
              ),
              isThreeLine: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('Paginated list'),
              subtitle: const Text(
                'GenericListBloc: infinite scroll, pull-to-refresh and a filter, '
                'against an API that fails every third request.',
              ),
              isThreeLine: true,
              onTap: () => Navigator.of(
                context,
              ).push(
                  MaterialPageRoute<void>(builder: (_) => const ItemsPage())),
            ),
          ],
        ),
      );
}

class ItemsPage extends AppBlocPage<
    ItemsBloc,
    AppBlocState<GenericListReady<String, ItemFilter>>,
    GenericListReady<String, ItemFilter>> {
  const ItemsPage({super.key});

  @override
  ItemsBloc createBloc(BuildContext context) =>
      ItemsBloc(FakeApi())..add(const GenericListInit());

  @override
  Widget buildBody(
    BuildContext context,
    GenericListReady<String, ItemFilter> ready,
  ) {
    final bloc = context.read<ItemsBloc>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ready.totalCount == null ? 'Items' : 'Items (${ready.totalCount})',
        ),
        actions: [
          IconButton(
            tooltip: 'Filter',
            onPressed: () => bloc.add(
              const GenericListFilterApplied<String, ItemFilter>(
                ItemFilter(query: 'Filtered'),
              ),
            ),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ],
      ),
      body: _Body(ready: ready, bloc: bloc),
    );
  }
}

/// Every state the list can be in gets an explicit branch — loading, failed,
/// empty and loaded.
class _Body extends StatelessWidget {
  const _Body({required this.ready, required this.bloc});

  final GenericListReady<String, ItemFilter> ready;
  final ItemsBloc bloc;

  @override
  Widget build(BuildContext context) {
    final items = ready.items;

    if (ready.initialLoadFailed) {
      return _Centered(
        message: "Couldn't load items.",
        action: FilledButton(
          onPressed: () => bloc.add(const GenericListRefreshed()),
          child: const Text('Retry'),
        ),
      );
    }

    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const _Centered(message: 'Nothing here yet.');
    }

    return RefreshIndicator(
      onRefresh: () async => bloc.add(const GenericListRefreshed()),
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 200) {
            bloc.add(const GenericListLoadMore());
          }
          return false;
        },
        child: ListView.builder(
          // One extra row while a page is actually being appended. Keying this
          // to `hasMore` instead would spin between fetches and keep spinning
          // after an append failed.
          itemCount: items.length + (ready.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(items[index]),
            );
          },
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            if (action case final action?) ...[
              const SizedBox(height: 12),
              action
            ],
          ],
        ),
      );
}
