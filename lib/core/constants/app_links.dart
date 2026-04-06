class AppLinks {
  const AppLinks._();

  static const String scheme = 'https';
  static const String host = 'gracy.app';
  static const String androidApplicationId = 'com.example.gracy';

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidApplicationId';

  static String postPath(String postId) => '/post/$postId';

  static Uri postUri(String postId) =>
      Uri(scheme: scheme, host: host, path: postPath(postId));
}
