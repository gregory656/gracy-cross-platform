class LocalFirstData<T> {
  const LocalFirstData({
    required this.data,
    this.isFromCache = false,
  });

  final T data;
  final bool isFromCache;
}
