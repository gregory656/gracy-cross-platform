class StoredAccount {
  const StoredAccount({
    required this.key,
    required this.sessionJson,
    this.userId,
    this.email,
    this.username,
    this.fullName,
    this.avatarUrl,
    this.savedAt,
  });

  final String key;
  final String sessionJson;
  final String? userId;
  final String? email;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? savedAt;

  String get displayName {
    final String? preferredName = fullName?.trim();
    if (preferredName != null && preferredName.isNotEmpty) {
      return preferredName;
    }

    final String? handle = username?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle.startsWith('@') ? handle : '@$handle';
    }

    final String? mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }

    return 'Gracy account';
  }

  String get subtitle {
    final String? handle = username?.trim();
    if (handle != null && handle.isNotEmpty) {
      return handle.startsWith('@') ? handle : '@$handle';
    }

    final String? mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail;
    }

    final String? id = userId?.trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }

    return 'Saved account';
  }

  String get initials {
    final String source = (fullName?.trim().isNotEmpty == true
            ? fullName!.trim()
            : username?.trim().isNotEmpty == true
                ? username!.replaceFirst('@', '').trim()
                : email?.trim().isNotEmpty == true
                    ? email!.trim().split('@').first
                    : 'G')
        .trim();
    final List<String> parts = source.split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return 'G';
    }

    final String first = parts.first.isNotEmpty ? parts.first[0] : 'G';
    final String last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last[0]
        : '';
    return (first + last).toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'key': key,
      'sessionJson': sessionJson,
      'userId': userId,
      'email': email,
      'username': username,
      'fullName': fullName,
      'avatarUrl': avatarUrl,
      'savedAt': savedAt?.toIso8601String(),
    };
  }

  factory StoredAccount.fromMap(Map<String, dynamic> map) {
    return StoredAccount(
      key: map['key']?.toString() ?? '',
      sessionJson: map['sessionJson']?.toString() ?? '',
      userId: map['userId']?.toString(),
      email: map['email']?.toString(),
      username: map['username']?.toString(),
      fullName: map['fullName']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      savedAt: map['savedAt'] == null
          ? null
          : DateTime.tryParse(map['savedAt'].toString()),
    );
  }

  StoredAccount copyWith({
    String? key,
    String? sessionJson,
    String? userId,
    String? email,
    String? username,
    String? fullName,
    String? avatarUrl,
    DateTime? savedAt,
  }) {
    return StoredAccount(
      key: key ?? this.key,
      sessionJson: sessionJson ?? this.sessionJson,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}
