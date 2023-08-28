# flutter_map_cancellable_tile_provider

Plugin for [flutter_map](https://github.com/fleaflet/flutter_map) that provides a `TileProvider` with the capability to cancel unnecessary HTTP requests (on the web)

- Reduce tile loading durations
- Reduce costly tile requests to tile servers*
- Reduce (cellular) data consumption

---

Unlike `NetworkTileProvider`, this uses '[dio](https://pub.dev/packages/dio)' to support cancelling/aborting unnecessary HTTP requests in-flight. Tiles that are removed/pruned before they are fully loaded do not need to complete loading, and therefore do not need to complete the request/download. This results in the tiles currently in the map's camera/viewport being loaded faster, as the tiles loaded whilst panning, zooming, or rotating are pruned, freeing up HTTP connections. It may also result in a reduction of costs, as there are less full tile requests to your tile server, but this will depend on their backend configuration and how quickly the tile is pruned.

Note that these advantages only occur on the web, as only the web supports the abortion of HTTP requests. On other platforms, this acts equivalent to `NetworkTileProvider`, except using 'dio' instead of 'http'.
