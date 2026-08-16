import 'package:equatable/equatable.dart';

/// Base class for a bloc's events.
abstract class AppEvent extends Equatable {
  /// Creates an event.
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// First load — dispatch once, when the screen is created.
///
/// Handlers usually guard against re-entry so a rebuild cannot trigger a
/// second fetch.
final class AppInit extends AppEvent {
  /// Creates the initial-load event.
  const AppInit();
}

/// Reload the current data, keeping any active filters or selection.
final class AppRefresh extends AppEvent {
  /// Creates the refresh event.
  const AppRefresh();
}
