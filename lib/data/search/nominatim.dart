// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Один результат геокодирования Nominatim (OSM).
class NominatimResult {
  /// Человекочитаемое название места (display_name).
  final String displayName;

  /// Широта, десятичные градусы.
  final double lat;

  /// Долгота, десятичные градусы.
  final double lon;

  /// Тип объекта OSM (например `city`, `peak`), если указан.
  final String? type;

  const NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.type,
  });
}

/// Обязательная атрибуция при использовании поиска и карт OSM (ТЗ FR-12, §13.2).
const kOsmAttribution = '© OpenStreetMap contributors';

/// Исключение «сеть недоступна / сервис не ответил» — поиск отключается,
/// остальное приложение продолжает работать офлайн (ТЗ FR-12, §20.3).
class NominatimUnavailableException implements Exception {
  final String reason;
  const NominatimUnavailableException(this.reason);
  @override
  String toString() => 'NominatimUnavailableException: $reason';
}

/// Ограничитель частоты запросов: публичный Nominatim допускает
/// не более 1 запроса в секунду (ТЗ FR-12, политика использования сервиса).
class RateLimiter {
  final Duration minInterval;

  /// Инъекция часов — для тестов.
  final DateTime Function() _now;

  DateTime? _lastAt;

  RateLimiter({
    this.minInterval = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Сколько нужно ждать до следующего разрешённого запроса.
  Duration timeUntilAllowed() {
    final last = _lastAt;
    if (last == null) return Duration.zero;
    final next = last.add(minInterval);
    final now = _now();
    if (!now.isBefore(next)) return Duration.zero;
    return next.difference(now);
  }

  /// Ждёт, пока запрос станет разрешён, и фиксирует момент обращения.
  Future<void> acquire() async {
    final wait = timeUntilAllowed();
    if (wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    _lastAt = _now();
  }

  /// Фиксирует момент запроса без ожидания — для тестов.
  void markUsed() => _lastAt = _now();
}

/// Клиент публичного геокодера Nominatim (только открытые данные, ТЗ FR-12).
///
/// - HTTPS (ТЗ §19.3), корректный User-Agent (требование Nominatim);
/// - не чаще 1 запроса в секунду — [RateLimiter];
/// - при сетевой ошибке бросает [NominatimUnavailableException]
///   (поиск «отключается», приложение работает дальше).
class NominatimClient {
  static const _kUserAgent = 'Solntsemer/0.1 (dev.atom42.solntsemer; GPLv3+)';

  /// Функция HTTP GET — инъекция для тестов.
  final Future<String> Function(Uri url, String userAgent) _httpGet;

  final RateLimiter _rateLimiter;

  NominatimClient({
    RateLimiter? rateLimiter,
    Future<String> Function(Uri url, String userAgent)? httpGet,
  })  : _rateLimiter = rateLimiter ?? RateLimiter(),
        _httpGet = httpGet ?? _defaultHttpGet;

  /// Ищет места по названию, возвращает не более [limit] результатов.
  Future<List<NominatimResult>> search(
    String query, {
    int limit = 6,
    String language = 'ru',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    await _rateLimiter.acquire();
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$limit',
      'accept-language': language,
    });
    final body = await _httpGet(url, _kUserAgent);
    return parseNominatimResponse(body);
  }

  /// Разбор ответа Nominatim (format=jsonv2) — отдельно для тестов.
  static List<NominatimResult> parseNominatimResponse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const NominatimUnavailableException('некорректный ответ сервиса');
    }
    if (decoded is! List) {
      throw const NominatimUnavailableException('неожиданный формат ответа');
    }
    final results = <NominatimResult>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final lat = double.tryParse('${item['lat']}');
      final lon = double.tryParse('${item['lon']}');
      final name = '${item['display_name'] ?? ''}'.trim();
      if (lat == null || lon == null || name.isEmpty) continue;
      if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
      results.add(NominatimResult(
        displayName: name,
        lat: lat,
        lon: lon,
        type: item['type'] is String ? item['type'] as String? : null,
      ));
    }
    return results;
  }

  static Future<String> _defaultHttpGet(Uri url, String userAgent) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(url);
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode != 200) {
        throw NominatimUnavailableException('HTTP ${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 512 * 1024) {
          throw const NominatimUnavailableException('ответ слишком большой');
        }
      }
      return utf8.decode(bytes);
    } on NominatimUnavailableException {
      rethrow;
    } on Exception catch (e) {
      // SocketException, TimeoutException и пр. — нет сети или сервис молчит.
      throw NominatimUnavailableException('нет соединения: $e');
    } finally {
      client.close();
    }
  }
}
