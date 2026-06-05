// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the SSH connection state and drives [SshService].
///
/// Kept alive for the whole app session so the underlying socket isn't torn
/// down when no widget is listening.

@ProviderFor(SshConnection)
final sshConnectionProvider = SshConnectionProvider._();

/// Holds the SSH connection state and drives [SshService].
///
/// Kept alive for the whole app session so the underlying socket isn't torn
/// down when no widget is listening.
final class SshConnectionProvider
    extends $NotifierProvider<SshConnection, SshState> {
  /// Holds the SSH connection state and drives [SshService].
  ///
  /// Kept alive for the whole app session so the underlying socket isn't torn
  /// down when no widget is listening.
  SshConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sshConnectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sshConnectionHash();

  @$internal
  @override
  SshConnection create() => SshConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SshState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SshState>(value),
    );
  }
}

String _$sshConnectionHash() => r'939d951c02fca592411ac0403710e64fd86c97c1';

/// Holds the SSH connection state and drives [SshService].
///
/// Kept alive for the whole app session so the underlying socket isn't torn
/// down when no widget is listening.

abstract class _$SshConnection extends $Notifier<SshState> {
  SshState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SshState, SshState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SshState, SshState>,
              SshState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
