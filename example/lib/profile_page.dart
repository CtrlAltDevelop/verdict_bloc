import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdict_bloc/verdict_bloc.dart';

/// The pattern without `GenericListBloc` in the way: one hand-written bloc,
/// one ready state, and `AppBlocMessage` for everything transient.
///
/// The thing to watch: hit **Save** repeatedly. It fails every other time, and
/// the form keeps its contents either way — the error is reported over a
/// screen that never blanked.

// ─── Data ───────────────────────────────────────────────────────────────────

class Profile {
  const Profile({required this.name, required this.email});

  final String name;
  final String email;

  Profile copyWith({String? name, String? email}) =>
      Profile(name: name ?? this.name, email: email ?? this.email);
}

class ProfileApi {
  int _saves = 0;

  Future<Result<Profile>> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return const Ok(Profile(name: 'Ada Lovelace', email: 'ada@example.com'));
  }

  Future<Result<Unit>> save(Profile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Fail every other save so both paths are easy to see.
    _saves++;
    if (_saves.isEven) {
      return const Err(
        ApiFailure(
          title: 'ProfileApi.save',
          message: 'That email is already in use.',
          code: 409,
          referenceId: 'REQ-4821',
        ),
      );
    }
    return const Ok(unit);
  }
}

// ─── State ──────────────────────────────────────────────────────────────────

/// One ready state for the whole screen. Everything the UI needs to draw
/// lives here, and it is never thrown away.
final class ProfileReady extends AppBlocState<ProfileReady> {
  const ProfileReady(
      {this.profile, this.isLoading = false, this.isSaving = false});

  final Profile? profile;
  final bool isLoading;
  final bool isSaving;

  ProfileReady copyWith({
    Profile? profile,
    bool? isLoading,
    bool? isSaving,
  }) =>
      ProfileReady(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
      );

  @override
  ProfileReady get ready => this;

  // Listing every field matters: AppBlocConsumer skips the rebuild when the
  // ready data compares equal, and that comparison is these props.
  @override
  List<Object?> get props => [profile, isLoading, isSaving];
}

// ─── Events ─────────────────────────────────────────────────────────────────

final class ProfileEmailChanged extends AppEvent {
  const ProfileEmailChanged(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

final class ProfileSaved extends AppEvent {
  const ProfileSaved();
}

// ─── Bloc ───────────────────────────────────────────────────────────────────

class ProfileBloc extends Bloc<AppEvent, AppBlocState<ProfileReady>> {
  ProfileBloc(this._api) : super(const ProfileReady()) {
    on<AppInit>(_onInit);
    on<ProfileEmailChanged>(_onEmailChanged);
    on<ProfileSaved>(_onSaved);
  }

  final ProfileApi _api;

  Future<void> _onInit(
    AppInit event,
    Emitter<AppBlocState<ProfileReady>> emit,
  ) async {
    emit(state.ready.copyWith(isLoading: true));

    switch (await _api.load()) {
      case Ok(:final value):
        emit(ProfileReady(profile: value));
      case Err(:final failure):
        _report(emit, failure: failure, settled: const ProfileReady());
    }
  }

  void _onEmailChanged(
    ProfileEmailChanged event,
    Emitter<AppBlocState<ProfileReady>> emit,
  ) {
    final profile = state.ready.profile;
    if (profile == null) return;
    emit(state.ready.copyWith(profile: profile.copyWith(email: event.email)));
  }

  Future<void> _onSaved(
    ProfileSaved event,
    Emitter<AppBlocState<ProfileReady>> emit,
  ) async {
    final profile = state.ready.profile;
    if (profile == null) return;

    // Local validation reports the same way a server error does.
    if (!profile.email.contains('@')) {
      _report(
        emit,
        type: MessageType.warning,
        description: 'That does not look like an email address.',
        settled: state.ready,
      );
      return;
    }

    emit(state.ready.copyWith(isSaving: true));
    final result = await _api.save(profile);
    final settled = state.ready.copyWith(isSaving: false);

    switch (result) {
      case Ok():
        _report(
          emit,
          type: MessageType.success,
          description: 'Profile saved.',
          settled: settled,
        );
      case Err(:final failure):
        // The form still holds what the user typed: `settled` carries it.
        _report(emit, failure: failure, settled: settled);
    }
  }

  /// Emits a transient report, then settles back on [settled].
  ///
  /// The two-emit shape is the whole trick: the message carries [settled] as
  /// its snapshot, so the UI keeps rendering throughout.
  void _report(
    Emitter<AppBlocState<ProfileReady>> emit, {
    required ProfileReady settled,
    Failure? failure,
    MessageType type = MessageType.error,
    String? description,
  }) {
    emit(
      AppBlocMessage<ProfileReady>(
        previous: settled,
        type: failure != null ? MessageType.error : type,
        description: description,
        failure: failure,
      ),
    );
    emit(settled);
  }
}

// ─── UI ─────────────────────────────────────────────────────────────────────

class ProfilePage
    extends AppBlocPage<ProfileBloc, AppBlocState<ProfileReady>, ProfileReady> {
  const ProfilePage({super.key});

  @override
  ProfileBloc createBloc(BuildContext context) =>
      ProfileBloc(ProfileApi())..add(const AppInit());

  @override
  Widget buildBody(BuildContext context, ProfileReady ready) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: switch (ready) {
          ProfileReady(isLoading: true) => const Center(
              child: CircularProgressIndicator(),
            ),
          ProfileReady(profile: null) => const Center(
              child: Text("Couldn't load the profile."),
            ),
          ProfileReady(:final profile?) =>
            _Form(ready: ready, profile: profile),
        },
      );
}

class _Form extends StatelessWidget {
  const _Form({required this.ready, required this.profile});

  final ProfileReady ready;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileBloc>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(profile.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: profile.email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => bloc.add(ProfileEmailChanged(value)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                ready.isSaving ? null : () => bloc.add(const ProfileSaved()),
            child: ready.isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: 12),
          Text(
            'Saving fails every other attempt. The form keeps what you typed '
            'either way — that is the point of the pattern.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
