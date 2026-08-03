// Unit tests for the Google sign-in path of [AuthProvider].
//
// These exercise the three outcomes the repository can produce — success,
// user-cancellation (null), and a real failure — and assert the provider maps
// each to the correct [AuthStatus] without throwing to the UI. The repository
// is faked so no Firebase / GoogleSignIn platform code runs.

import 'package:ai_recipe_generator/core/error/failure.dart';
import 'package:ai_recipe_generator/models/user_model.dart';
import 'package:ai_recipe_generator/providers/auth_provider.dart';
import 'package:ai_recipe_generator/repositories/auth_repository.dart';
import 'package:ai_recipe_generator/repositories/user_repository.dart';
import 'package:ai_recipe_generator/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// An [AuthRepository] whose `signInWithGoogle` is scripted per test.
///
/// The base constructor's collaborators are never touched (Google sign-in is
/// fully overridden), so real lazy services are safe to pass.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._result, {this.error})
      : super(
          authService: AuthService(),
          userRepository: UserRepository(),
        );

  final UserModel? _result;
  final Object? error;

  @override
  Future<UserModel?> signInWithGoogle() async {
    if (error != null) throw error!;
    return _result;
  }
}

void main() {
  const user = UserModel(
    uid: 'u1',
    name: 'Ada',
    email: 'ada@example.com',
    provider: 'google',
  );

  test('successful Google sign-in authenticates the provider', () async {
    final provider = AuthProvider(_FakeAuthRepository(user));

    await provider.signInWithGoogle();

    expect(provider.status, AuthStatus.authenticated);
    expect(provider.user, user);
    expect(provider.errorMessage, isNull);
  });

  test('cancelled Google sign-in (null) returns to idle with no error',
      () async {
    final provider = AuthProvider(_FakeAuthRepository(null));

    await provider.signInWithGoogle();

    expect(provider.status, AuthStatus.idle);
    expect(provider.user, isNull);
    expect(provider.errorMessage, isNull);
  });

  test('failed Google sign-in surfaces the failure message as error state',
      () async {
    final provider = AuthProvider(
      _FakeAuthRepository(null, error: const AuthFailure('Google failed')),
    );

    await provider.signInWithGoogle();

    expect(provider.status, AuthStatus.error);
    expect(provider.errorMessage, 'Google failed');
  });
}
