import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart';
import 'package:flutter_map_vector_tiles_mbtiles/flutter_map_vector_tiles_mbtiles.dart';

import '../services/offline_map_service.dart';

/// Offline base map rendered from the bundled `aklan.mbtiles` archive.
///
/// Sits above the default online tile layer: while the archive is being
/// prepared it shows a loading hint, and if anything goes wrong it shows a
/// friendly message instead of crashing — the tiles below remain visible.
class OfflineMapLayer extends StatefulWidget {
  const OfflineMapLayer({super.key});

  @override
  State<OfflineMapLayer> createState() => _OfflineMapLayerState();
}

class _OfflineMapLayerState extends State<OfflineMapLayer> {
  bool _loading = true;
  bool _failed = false;
  Style? _style;
  MbTilesVectorTileProvider? _provider;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final path = await OfflineMapService.instance.prepare();
      final provider = await MbTilesVectorTileProvider.open(path);
      final style = await StyleReader(
        uri: OfflineMapService.kStyleAssetUri,
        resolveProvider: (id) async =>
            id == OfflineMapService.kSourceId ? provider : null,
      ).read();
      if (!mounted) {
        style.dispose();
        return;
      }
      debugPrint(
        'OfflineMapLayer ready — rendering local MBTiles provider from: $path',
      );
      setState(() {
        _provider = provider;
        _style = style;
        _loading = false;
      });
    } catch (error) {
      debugPrint('OfflineMapLayer failed: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _style?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_style != null && _provider != null) {
      return VectorTileLayer(
        theme: _style!.theme,
        tileProviders: TileProviders({OfflineMapService.kSourceId: _provider!}),
        rasterSources: _style!.rasterSources,
        sprites: _style!.sprites,
      );
    }

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  _failed
                      ? 'Offline map unavailable. Online tiles are shown.'
                      : 'Preparing offline map...',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}