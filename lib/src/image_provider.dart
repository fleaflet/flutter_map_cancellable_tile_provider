part of 'tile_provider.dart';

class _CNTPImageProvider extends ImageProvider<_CNTPImageProvider> {
  final String url;
  final String? fallbackUrl;
  final Map<String, String> headers;
  final Dio dioClient;
  final Future<void> cancelLoading;
  final bool silenceExceptions;
  final void Function() startedLoading;
  final void Function() finishedLoadingBytes;

  const _CNTPImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.headers,
    required this.dioClient,
    required this.cancelLoading,
    required this.silenceExceptions,
    required this.startedLoading,
    required this.finishedLoadingBytes,
  });

  @override
  ImageStreamCompleter loadImage(
    _CNTPImageProvider key,
    ImageDecoderCallback decode,
  ) {
    startedLoading();

    return MultiFrameImageStreamCompleter(
      codec: _loadBytes(key, decode)
          .whenComplete(finishedLoadingBytes)
          .then(ImmutableBuffer.fromUint8List)
          .then(decode),
      scale: 1,
      debugLabel: url,
      informationCollector: () => [
        DiagnosticsProperty('URL', url),
        DiagnosticsProperty('Fallback URL', fallbackUrl),
        DiagnosticsProperty('Current provider', key),
      ],
    );
  }

  Future<Uint8List> _loadBytes(
    _CNTPImageProvider key,
    ImageDecoderCallback decode, {
    bool useFallback = false,
  }) {
    final cancelToken = CancelToken();
    unawaited(cancelLoading.then((_) => cancelToken.cancel()));

    return dioClient
        .getUri<Uint8List>(
          Uri.parse(useFallback ? fallbackUrl ?? '' : url),
          cancelToken: cancelToken,
          options: Options(headers: headers, responseType: ResponseType.bytes),
        )
        .then((response) => response.data!)
        .catchError((Object err, StackTrace stack) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      if (err is DioException && CancelToken.isCancel(err)) {
        return TileProvider.transparentImage;
      }
      if (useFallback || fallbackUrl == null) {
        if (silenceExceptions) return TileProvider.transparentImage;
        return Future<Uint8List>.error(err, stack);
      }
      return _loadBytes(key, decode, useFallback: true);
    });
  }

  @override
  SynchronousFuture<_CNTPImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CNTPImageProvider && fallbackUrl == null && url == other.url);

  @override
  int get hashCode =>
      Object.hashAll([url, if (fallbackUrl != null) fallbackUrl]);
}
