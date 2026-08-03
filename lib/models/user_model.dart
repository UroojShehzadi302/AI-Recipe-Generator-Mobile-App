// User data model for the AI Recipe Generator.
//
// Mirrors the `/users/{uid}` document described in the Backend Architecture
// doc §6.1 (client-relevant subset). Plain, null-safe Dart with no Firebase
// dependency — Firestore `Timestamp` fields (createdAt/updatedAt) and the
// nested `settings` map are handled in the repository layer, not here.

/// Reads a value as a [String], tolerating null / non-string. -> '' default.
String _asString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}

/// Reads a value as an [int], tolerating num / numeric string / null.
int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

/// Reads a value as a [bool], tolerating null / 'true'/'false' strings / nums.
bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return false;
}

/// An authenticated user profile plus denormalized counters.
///
/// [provider] is `'password'` or `'google'`. [photoUrl] is nullable
/// (avatar optional). [favoritesCount] / [generatedCount] are maintained
/// server-side by Cloud Functions (§7) and read-only from the client's view.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String provider;
  final bool emailVerified;
  final int favoritesCount;
  final int generatedCount;

  const UserModel({
    this.uid = '',
    this.name = '',
    this.email = '',
    this.photoUrl,
    this.provider = '',
    this.emailVerified = false,
    this.favoritesCount = 0,
    this.generatedCount = 0,
  });

  /// An empty fallback user.
  static const UserModel empty = UserModel();

  /// Tolerant parser: never throws on missing / wrong-typed fields.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final Object? rawPhoto = json['photoUrl'];
    final String? photoUrl = (rawPhoto == null)
        ? null
        : (_asString(rawPhoto).isEmpty ? null : _asString(rawPhoto));

    return UserModel(
      uid: _asString(json['uid']),
      name: _asString(json['name']),
      email: _asString(json['email']),
      photoUrl: photoUrl,
      provider: _asString(json['provider']),
      emailVerified: _asBool(json['emailVerified']),
      favoritesCount: _asInt(json['favoritesCount']),
      generatedCount: _asInt(json['generatedCount']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'provider': provider,
        'emailVerified': emailVerified,
        'favoritesCount': favoritesCount,
        'generatedCount': generatedCount,
      };

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? provider,
    bool? emailVerified,
    int? favoritesCount,
    int? generatedCount,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      provider: provider ?? this.provider,
      emailVerified: emailVerified ?? this.emailVerified,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      generatedCount: generatedCount ?? this.generatedCount,
    );
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, name: $name, email: $email, provider: $provider)';
}
