import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';

/// [TileProvider] to fetch tiles from the network, with cancellation support
///
/// Unlike [NetworkTileProvider], this uses [Dio] and supports
/// cancelling/aborting unnecessary HTTP requests in-flight. Tiles that are
/// removed/pruned before they are fully loaded do not need to complete loading,
/// and therefore do not need to complete the request/download. This results in
/// the tiles currently in the map's camera/viewport being loaded faster, as the
/// tiles loaded whilst panning, zooming, or rotating are pruned, freeing up HTTP
/// connections. It may also result in a reduction of costs, as there are less
/// full tile requests to your tile server, but this will depend on their backend
/// configuration and how quickly the tile is pruned.
///
/// Note that these advantages only occur on the web, as only the web supports
/// the abortion of HTTP requests. On other platforms, this acts equivalent to
/// [NetworkTileProvider], except using 'package:dio' instead of 'package:http'.
///
/// On the web, the 'User-Agent' header cannot be changed as specified in
/// [TileLayer.tileProvider]'s documentation, due to a Dart/browser limitation.
class CancellableNetworkTileProvider extends TileProvider {
  /// Create a [TileProvider] to fetch tiles from the network, with cancellation
  /// support
  ///
  /// Unlike [NetworkTileProvider], this uses [Dio] and supports
  /// cancelling/aborting unnecessary HTTP requests in-flight. Tiles that are
  /// removed/pruned before they are fully loaded do not need to complete
  /// loading, and therefore do not need to complete the request/download. This
  /// results in the tiles currently in the map's camera/viewport being loaded
  /// faster, as the tiles loaded whilst panning, zooming, or rotating are
  /// pruned, freeing up HTTP connections. It may also result in a reduction of
  /// costs, as there are less full tile requests to your tile server, but this
  /// will depend on their backend configuration and how quickly the tile is
  /// pruned.
  ///
  /// Note that these advantages only occur on the web, as only the web supports
  /// the abortion of HTTP requests. On other platforms, this acts equivalent to
  /// [NetworkTileProvider], except using 'package:dio' instead of
  /// 'package:http'.
  ///
  /// On the web, the 'User-Agent' header cannot be changed as specified in
  /// [TileLayer.tileProvider]'s documentation, due to a Dart/browser limitation.
  CancellableNetworkTileProvider({
    super.headers,
  }) : _dio = Dio();

  final Dio _dio;
  // ignore: use_late_for_private_fields_and_variables
  ImmutableBuffer? _cancelledImage;

  @override
  bool get supportsCancelLoading => true;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) =>
      _CNTPImageProvider(
        url: getTileUrl(coordinates, options),
        fallbackUrl: getTileFallbackUrl(coordinates, options),
        tileProvider: this,
        cancelLoading: cancelLoading,
      );

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

class _CNTPImageProvider extends ImageProvider<_CNTPImageProvider> {
  final String url;
  final String? fallbackUrl;
  final CancellableNetworkTileProvider tileProvider;
  final Future<void> cancelLoading;

  const _CNTPImageProvider({
    required this.url,
    required this.fallbackUrl,
    required this.tileProvider,
    required this.cancelLoading,
  });

  @override
  ImageStreamCompleter loadImage(
    _CNTPImageProvider key,
    ImageDecoderCallback decode,
  ) {
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode),
      chunkEvents: chunkEvents.stream,
      scale: 1,
      debugLabel: url,
      informationCollector: () => [
        DiagnosticsProperty('URL', url),
        DiagnosticsProperty('Fallback URL', fallbackUrl),
        DiagnosticsProperty('Current provider', key),
      ],
    );
  }

  @override
  Future<_CNTPImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) =>
      SynchronousFuture<_CNTPImageProvider>(this);

  Future<Codec> _loadAsync(
    _CNTPImageProvider key,
    StreamController<ImageChunkEvent> chunkEvents,
    ImageDecoderCallback decode, {
    bool useFallback = false,
  }) async {
    final cancelToken = CancelToken();
    unawaited(cancelLoading.then((_) => cancelToken.cancel()));

    final Uint8List bytes;
    try {
      final response = await tileProvider._dio.get<Uint8List>(
        useFallback ? fallbackUrl! : url,
        cancelToken: cancelToken,
        options: Options(
          headers: tileProvider.headers,
          responseType: ResponseType.bytes,
        ),
      );
      bytes = response.data!;
    } on DioException catch (err) {
      if (CancelToken.isCancel(err)) {
        return decode(
          tileProvider._cancelledImage ??= await ImmutableBuffer.fromUint8List(
            TileProvider.transparentImage,
          ),
        );
      }
      if (useFallback || fallbackUrl == null) rethrow;
      return _loadAsync(key, chunkEvents, decode, useFallback: true);
    } catch (_) {
      if (useFallback || fallbackUrl == null) rethrow;
      return _loadAsync(key, chunkEvents, decode, useFallback: true);
    }

    cancelLoading.ignore();
    return decode(await ImmutableBuffer.fromUint8List(bytes));
  }
}
