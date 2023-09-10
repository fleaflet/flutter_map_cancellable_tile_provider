import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';

/// Specialized [TileProvider] that fetches tiles from the network, with
/// cancellation support
///
/// {@template tp-desc}
///
/// This could:
///
/// * Reduce tile loading durations
/// * Reduce costly tile requests to tile servers*
/// * Reduce (cellular) data consumption
///
/// This provider uses [Dio] to abort unnecessary HTTP requests in-flight. Tiles
/// that are removed/pruned before they are fully loaded do not need to complete
/// loading, and therefore do not need to complete the HTTP interaction. Closing
/// the connection in this way frees it up for other tile requests, and avoids
/// downloading unused data.
///
/// On platforms where HTTP request abortion isn't supported (ie. platforms other
/// than the web), this acts equivalent to `NetworkTileProvider`, except using
/// 'dio' instead of 'http'.
///
/// There's no reason not use this tile provider if you run on the web platform,
/// unless you'd rather avoid having 'dio' as a dependency. Once HTTP request
/// abortion is
/// [added to Dart's 'native' 'http' package (requested and PR opened)](https://github.com/dart-lang/http/issues/424),
/// [NetworkTileProvider] will be updated to take advantage of it, replacing this
/// provider.
///
/// ---
///
/// On the web, the 'User-Agent' header cannot be changed as specified in
/// [TileLayer.tileProvider]'s documentation, due to a Dart/browser limitation.
/// {@endtemplate}
class CancellableNetworkTileProvider extends TileProvider {
  /// Create a [CancellableNetworkTileProvider] to fetch tiles from the network,
  /// with cancellation support
  ///
  /// {@macro tp-desc}
  CancellableNetworkTileProvider({super.headers}) : _dio = Dio();

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

    try {
      final codec = decode(
        await ImmutableBuffer.fromUint8List(
          (await tileProvider._dio.get<Uint8List>(
            useFallback ? fallbackUrl! : url,
            cancelToken: cancelToken,
            options: Options(
              headers: tileProvider.headers,
              responseType: ResponseType.bytes,
            ),
          ))
              .data!,
        ),
      );

      cancelLoading.ignore();
      return codec;
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
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CNTPImageProvider && fallbackUrl == null && url == other.url);

  @override
  int get hashCode =>
      Object.hashAll([url, if (fallbackUrl != null) fallbackUrl]);
}
