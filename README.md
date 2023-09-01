# flutter_map_cancellable_tile_provider

Plugin for [flutter_map](https://github.com/fleaflet/flutter_map) that provides a `TileProvider` with the capability to cancel unnecessary HTTP requests (where supported by the underlying platform)

If a large proportion of your users use the web platform, it is preferable to use this tile provider instead of the default `NetworkTileProvider`.
It could:

- Reduce tile loading durations
- Reduce costly tile requests to tile servers*
- Reduce (cellular) data consumption

This provider uses '[dio](https://pub.dev/packages/dio)' to support cancelling/aborting unnecessary HTTP requests in-flight. Tiles that are removed/pruned before they are fully loaded do not need to complete loading, and therefore do not need to complete the HTTP interaction. Closing the connection in this way frees it up for other tile requests, and avoids downloading unused data.

On platforms where HTTP request abortion isn't supported (ie. platforms other than the web), this acts equivalent to `NetworkTileProvider`, except using 'dio' instead of 'http'.

There's no reason not use this tile provider if you run on the web platform, unless you'd rather avoid having 'dio' as a dependency. Once HTTP request abortion is [added to Dart's 'native' 'http' package (requested and PR opened)](https://github.com/dart-lang/http/issues/424), `NetworkTileProvider` will be updated to take advantage of it, replacing this provider.
