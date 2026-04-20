class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? userName;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.userName,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? userName,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }
}

