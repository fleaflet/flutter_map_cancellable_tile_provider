# flutter_map_cancellable_tile_provider

### This plugin is deprecated since flutter_map v8.2

This plugin was intended as a stopgap to support aborting in-flight HTTP requests of tiles which were no longer required for display.

Since 'package:http' v1.5.0-beta ([#1773](https://github.com/dart-lang/http/pull/1773)), the 3 core HTTP clients (`IOClient`, `BrowserClient`, and `RetryClient`) support this functionality natively (with other clients soon to follow).

flutter_map v8.2's `NetworkTileProvider` depends on this version of 'pkg:http', and supports aborting requests natively. Therefore, this package
is now redundant.

---

Plugin for [flutter_map](https://github.com/fleaflet/flutter_map) that provides a `TileProvider` that fetches tiles from the network, with the capability to cancel unnecessary HTTP tile requests

Tiles that are removed/pruned before they are fully loaded do not need to complete (down)loading, and therefore do not need to complete the HTTP interaction. Cancelling these unnecessary tile requests early could:

- Reduce tile loading durations (particularly on the web)
- Reduce users' (cellular) data and cache space consumption
- Reduce costly tile requests to tile servers*
- Improve performance by reducing CPU and IO work

This provider uses '[dio](https://pub.dev/packages/dio)', which supports aborting unnecessary HTTP requests in-flight, after they have already been sent.

Although HTTP request abortion is supported on all platforms, it is especially useful on the web - and therefore recommended for web apps. This is because the web platform has a limited number of simulatous HTTP requests, and so closing the requests allows new requests to be made for new tiles.  
On other platforms, the other benefits may still occur, but may not be as visible as on the web.

Once HTTP request abortion is [added to Dart's 'native' 'http' package (which already has a PR opened)](https://github.com/dart-lang/http/issues/424), `NetworkTileProvider` will be updated to take advantage of it, replacing and deprecating this provider. This tile provider is currently a separate package and not the default due to the reliance on the additional Dio dependency.
