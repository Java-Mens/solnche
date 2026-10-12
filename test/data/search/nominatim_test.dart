// Copyright (C) 2026 Atom42 and contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:solntsemer/data/search/nominatim.dart';

void main() {
  group('parseNominatimResponse', () {
    test('разбирает jsonv2-ответ с результатами', () {
      const body = '''
      [
        {"place_id": 123, "lat": "43.1155", "lon": "131.8855",
         "display_name": "Владивосток, Приморский край, Россия",
         "type": "city"},
        {"place_id": 124, "lat": "-33.8688", "lon": "151.2093",
         "display_name": "Sydney, Australia", "type": "administrative"}
      ]
      ''';
      final results = NominatimClient.parseNominatimResponse(body);
      expect(results, hasLength(2));
      expect(results[0].lat, closeTo(43.1155, 1e-9));
      expect(results[0].lon, closeTo(131.8855, 1e-9));
      expect(results[0].displayName, contains('Владивосток'));
      expect(results[0].type, 'city');
      expect(results[1].lat, closeTo(-33.8688, 1e-9));
    });

    test('пустой список — не ошибка', () {
      expect(NominatimClient.parseNominatimResponse('[]'), isEmpty);
    });

    test('пропускает записи без координат или названия', () {
      const body = '''
      [
        {"lat": "abc", "lon": "131.8855", "display_name": "битые координаты"},
        {"lat": "10.0", "lon": "20.0", "display_name": ""},
        {"lat": "10.0", "lon": "20.0", "display_name": "норм"}
      ]
      ''';
      final results = NominatimClient.parseNominatimResponse(body);
      expect(results, hasLength(1));
      expect(results[0].displayName, 'норм');
    });

    test('отбрасывает записи вне диапазона координат (FR-11)', () {
      const body = '''
      [
        {"lat": "91.0", "lon": "0.0", "display_name": "широта > 90"},
        {"lat": "10.0", "lon": "181.0", "display_name": "долгота > 180"}
      ]
      ''';
      expect(NominatimClient.parseNominatimResponse(body), isEmpty);
    });

    test('некорректный JSON — NominatimUnavailableException', () {
      expect(
        () => NominatimClient.parseNominatimResponse('<html>502</html>'),
        throwsA(isA<NominatimUnavailableException>()),
      );
    });

    test('не-список — NominatimUnavailableException', () {
      expect(
        () => NominatimClient.parseNominatimResponse('{"error": "x"}'),
        throwsA(isA<NominatimUnavailableException>()),
      );
    });
  });

  group('RateLimiter (ТЗ FR-12: не чаще 1 запроса в секунду)', () {
    test('первый запрос проходит сразу', () {
      var now = DateTime(2026, 10, 12, 12);
      final limiter = RateLimiter(clock: () => now);
      expect(limiter.timeUntilAllowed(), Duration.zero);
    });

    test('повторный запрос ждёт до конца интервала', () {
      var now = DateTime(2026, 10, 12, 12);
      final limiter = RateLimiter(clock: () => now);
      limiter.markUsed();
      now = now.add(const Duration(milliseconds: 300));
      expect(
        limiter.timeUntilAllowed(),
        const Duration(milliseconds: 700),
      );
    });

    test('после интервала запрос снова разрешён', () {
      var now = DateTime(2026, 10, 12, 12);
      final limiter = RateLimiter(clock: () => now);
      limiter.markUsed();
      now = now.add(const Duration(seconds: 1));
      expect(limiter.timeUntilAllowed(), Duration.zero);
    });
  });

  group('NominatimClient.search', () {
    test('пустой запрос не ходит в сеть', () async {
      var calls = 0;
      final client = NominatimClient(
        httpGet: (_, _) async {
          calls++;
          return '[]';
        },
      );
      expect(await client.search('   '), isEmpty);
      expect(calls, 0);
    });

    test('HTTPS-адрес Nominatim с параметрами jsonv2 и лимитом', () async {
      Uri? seen;
      String? ua;
      final client = NominatimClient(
        httpGet: (url, userAgent) async {
          seen = url;
          ua = userAgent;
          return '[]';
        },
      );
      await client.search('Владивосток', limit: 5);
      expect(seen!.scheme, 'https'); // ТЗ §19.3
      expect(seen!.host, 'nominatim.openstreetmap.org');
      expect(seen!.queryParameters['q'], 'Владивосток');
      expect(seen!.queryParameters['format'], 'jsonv2');
      expect(seen!.queryParameters['limit'], '5');
      expect(ua, contains('Solntsemer')); // корректный User-Agent (§19.3)
    });

    test('ошибка сети — NominatimUnavailableException, не падение', () async {
      final client = NominatimClient(
        httpGet: (_, _) async =>
            throw const NominatimUnavailableException('нет соединения'),
      );
      await expectLater(
        client.search('тест'),
        throwsA(isA<NominatimUnavailableException>()),
      );
    });

    test('результаты поиска парсятся из реального формата', () async {
      final client = NominatimClient(
        httpGet: (_, _) async => '''
        [{"place_id":1,"lat":"55.755866","lon":"37.617366",
          "display_name":"Москва, Россия","type":"city"}]
        ''',
      );
      final results = await client.search('Москва');
      expect(results, hasLength(1));
      expect(results.first.lat, closeTo(55.755866, 1e-9));
      expect(results.first.displayName, 'Москва, Россия');
    });
  });
}
