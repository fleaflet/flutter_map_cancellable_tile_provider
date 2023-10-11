import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';

/// [TileProvider] that fetches tiles from the network, with the capability to
/// cancel unnecessary HTTP tile requests
///
/// {@template tp-desc}
///
/// Tiles that are removed/pruned before they are fully loaded do not need to
/// complete (down)loading, and therefore do not need to complete the HTTP
/// interaction. Cancelling these unnecessary tile requests early could:
///
/// - Reduce tile loading durations (particularly on the web)
/// - Reduce users' (cellular) data and cache space consumption
/// - Reduce costly tile requests to tile servers*
/// - Improve performance by reducing CPU and IO work
///
/// This provider uses '[dio](https://pub.dev/packages/dio)', which supports
/// aborting unnecessary HTTP requests in-flight, after they have already been
/// sent.
///
/// Although HTTP request abortion is supported on all platforms, it is
/// especially useful on the web - and therefore recommended for web apps. This
/// is because the web platform has a limited number of simulatous HTTP requests,
/// and so closing the requests allows new requests to be made for new tiles.
/// On other platforms, the other benefits may still occur, but may not be as
/// visible as on the web.
///
/// Once HTTP request abortion is [added to Dart's 'native' 'http' package (which already has a PR opened)](https://github.com/dart-lang/http/issues/424), `NetworkTileProvider` will be updated to take advantage of it, replacing and deprecating this provider. This tile provider is currently a seperate package and not the default due to the reliance on the additional Dio dependency.
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
      ).catchError((e) {
        // ignore: only_throw_errors
        if (useFallback || fallbackUrl == null) throw e as Object;
        return _loadAsync(key, chunkEvents, decode, useFallback: true);
      });

      cancelLoading.ignore();
      return codec;
    } on DioException catch (err) {
      if (CancelToken.isCancel(err)) {
        return decode(
          tileProvider._cancelledImage ??
              await ImmutableBuffer.fromUint8List(
                TileProvider.transparentImage,
              ),
        );
      }
      if (useFallback || fallbackUrl == null) rethrow;
      return _loadAsync(key, chunkEvents, decode, useFallback: true);
    } catch (_) {
      // This redundancy necessary, do not remove
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
