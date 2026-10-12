// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/geo/geo_point.dart';
import '../../data/search/nominatim.dart';
import '../providers.dart';

/// Экран карты (ТЗ §14.1 «Экран 2», FR-08..FR-10, FR-12).
///
/// - Открытые данные OpenStreetMap (тайлы raster, обязательная атрибуция);
/// - перемещение и масштаб, выбор точки долгим нажатием (FR-09);
/// - маркеры A и B, координаты выбранной точки;
/// - ручной ввод координат и «моё местоположение» (FR-10/FR-05);
/// - опциональный поиск по названию через Nominatim (FR-12): не чаще
///   1 запроса в секунду, отключается в настройках и без сети.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialTargetA = true});

  /// Какую точку выбираем по умолчанию (A с главного экрана / B из сравнения).
  final bool initialTargetA;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late bool _targetA = widget.initialTargetA;
  final MapController _mapController = MapController();
  static const _kInitialCenter = LatLng(43.1155, 131.885); // Владивосток
  bool? _networkAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnPoint(_currentPoint() ?? _fallbackPoint());
    });
    unawaited(_probeNetwork());
  }

  GeoPoint? _currentPoint() =>
      _targetA ? ref.read(pointAProvider) : ref.read(pointBProvider);

  GeoPoint _fallbackPoint() {
    final a = ref.read(pointAProvider);
    final b = ref.read(pointBProvider);
    if (a != null) return a;
    if (b != null) return b;
    return const GeoPoint(lat: 43.1155, lon: 131.885);
  }

  void _centerOnPoint(GeoPoint p, {double zoom = 11}) {
    _mapController.move(LatLng(p.lat, p.lon), zoom);
  }

  void _setTarget(bool targetA) {
    setState(() => _targetA = targetA);
    final p = _currentPoint();
    if (p != null) _centerOnPoint(p);
  }

  /// Присваивает точке A/B координаты долгого нажатия / результата поиска.
  void _assignPoint(GeoPoint p) {
    if (_targetA) {
      ref.read(pointAProvider.notifier).setPoint(p);
    } else {
      ref.read(pointBProvider.notifier).setPoint(p);
    }
  }

  /// Проверка сети для карты и поиска (ТЗ FR-10/FR-12): тайлы грузятся
  /// только онлайн; офлайн остаётся ручной ввод и поиск отключается.
  Future<void> _probeNetwork() async {
    final ok = await NominatimProbe.probe();
    if (mounted) setState(() => _networkAvailable = ok);
  }

  @override
  Widget build(BuildContext context) {
    final pointA = ref.watch(pointAProvider);
    final pointB = ref.watch(pointBProvider);
    final current = _targetA ? pointA : pointB;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Найти место (Nominatim)',
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Целевая точка для долгого нажатия / поиска (FR-09).
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Text('Долгое нажатие задаёт: ',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Точку A')),
                    ButtonSegment(value: false, label: Text('Точку B')),
                  ],
                  selected: {_targetA},
                  onSelectionChanged: (s) => _setTarget(s.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _kInitialCenter,
                    initialZoom: 10,
                    minZoom: 2,
                    maxZoom: 19,
                    onLongPress: (_, latLng) {
                      _assignPoint(GeoPoint(lat: latLng.latitude, lon: latLng.longitude));
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'dev.atom42.solntsemer',
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        if (pointA != null)
                          _marker(pointA, 'A', Colors.blue),
                        if (pointB != null)
                          _marker(pointB, 'B', Colors.deepOrange),
                      ],
                    ),
                    // Обязательная атрибуция OSM (ТЗ FR-08, §13.2).
                    const SimpleAttributionWidget(
                      source: Text(kOsmAttribution),
                    ),
                  ],
                ),
                if (_networkAvailable == false)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Нет сети: тайлы карты не загрузятся. '
                          'Введите координаты вручную — расчёты работают офлайн.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Панель координат выбранной точки + действия (FR-09, FR-10).
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _targetA ? Icons.location_on : Icons.location_on_outlined,
                        size: 18,
                        color: _targetA ? Colors.blue : Colors.deepOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          current == null
                              ? 'Точка ${_targetA ? 'A' : 'B'} не задана — '
                                  'нажмите долгим нажатием на карту'
                              : 'Точка ${_targetA ? 'A' : 'B'}: '
                                  '${current.lat.toStringAsFixed(5)}, '
                                  '${current.lon.toStringAsFixed(5)}',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  OverflowBar(
                    alignment: MainAxisAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Моё местоположение'),
                        onPressed: () {
                          ref.read(pointAProvider.notifier).startAutoLocation();
                          _setTarget(true);
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_location_alt, size: 18),
                        label: const Text('Ввести вручную'),
                        onPressed: () => _showManualInputDialog(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(GeoPoint p, String label, Color color) {
    return Marker(
      point: LatLng(p.lat, p.lon),
      width: 36,
      height: 36,
      child: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        radius: 16,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Ручной ввод координат (ТЗ FR-11) — доступен и офлайн (FR-10).
  Future<void> _showManualInputDialog(BuildContext context) async {
    final controller = TextEditingController();
    final current = _currentPoint();
    if (current != null) {
      controller.text = '${current.lat}, ${current.lon}';
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Координаты точки ${_targetA ? 'A' : 'B'}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '55.7558, 37.6173',
            labelText: 'Широта, Долгота',
          ),
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final p = GeoPoint.tryParse(controller.text);
              if (p == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Некорректные координаты')),
                );
                return;
              }
              _assignPoint(p);
              _centerOnPoint(p);
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  /// Панель поиска Nominatim (ТЗ FR-12).
  Future<void> _openSearch(BuildContext context) async {
    final searchEnabled =
        ref.read(settingsProvider).searchNetworkEnabled && _networkAvailable != false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SearchSheet(
        enabled: searchEnabled,
        onPicked: (result) {
          final p = GeoPoint(lat: result.lat, lon: result.lon);
          _assignPoint(p);
          _centerOnPoint(p, zoom: 13);
        },
        onRetryNetwork: () {
          unawaited(_probeNetwork());
        },
      ),
    );
  }
}

/// Поисковая панель: поле ввода, результаты, состояние «нет сети».
class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet({
    required this.enabled,
    required this.onPicked,
    this.onRetryNetwork,
  });

  final bool enabled;
  final void Function(NominatimResult result) onPicked;
  final VoidCallback? onRetryNetwork;

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _queryController = TextEditingController();
  List<NominatimResult>? _results;
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_searching) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final client = ref.read(nominatimClientProvider);
      final results =
          await client.search(_queryController.text).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        if (results.isEmpty) _error = 'Ничего не найдено';
      });
    } on NominatimUnavailableException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Нет сети — поиск недоступен (ТЗ FR-12)';
      });
      widget.onRetryNetwork?.call();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Сервис не ответил';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Поиск места', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Открытые данные OSM · Nominatim · $kOsmAttribution',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!widget.enabled)
            Text(
              ref.read(settingsProvider).searchNetworkEnabled
                  ? 'Нет сети — поиск отключён. Введите координаты вручную.'
                  : 'Сетевой поиск отключён в настройках.',
              style: const TextStyle(color: Colors.orange),
            )
          else ...[
            TextField(
              controller: _queryController,
              enabled: widget.enabled,
              decoration: InputDecoration(
                hintText: 'например: Владивосток',
                suffixIcon: IconButton(
                  icon: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _searching ? null : _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.orange)),
              ),
            if (_results != null && _results!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results!.length,
                  itemBuilder: (ctx, i) {
                    final r = _results![i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place, size: 20),
                      title: Text(
                        r.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        widget.onPicked(r);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Лёгкая проверка доступности сети для карты и поиска (ТЗ FR-10/FR-12):
/// HTTP HEAD к тайл-серверу OSM. Любой HTTP-ответ (даже 403/404) означает,
/// что сеть есть; соединение не удалось — офлайн.
class NominatimProbe {
  NominatimProbe._();

  static const _kUserAgent = 'Solntsemer/0.1 (dev.atom42.solntsemer; GPLv3+)';

  static Future<bool> probe() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .headUrl(Uri.parse('https://tile.openstreetmap.org/0/0/0.png'))
          .timeout(const Duration(seconds: 5));
      request.headers.set(HttpHeaders.userAgentHeader, _kUserAgent);
      final response = await request.close().timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }
}
