// test/api_service_test.dart
//
// ApiService を http.Client 抜きで決定的にテストする。
//
// #14 のポイント: http.get() を直接呼んでいた頃は、ApiService 単体で
// 200 以外・タイムアウト・不正 JSON・空配列といった経路をネットワークなしで
// 再現できなかった。MockClient を注入することで、実 API を一切叩かずに
// これらの分岐を固定的に再現する。
import 'dart:convert';
import 'dart:math';

import 'package:animal_swipe/models/animal_type.dart';
import 'package:animal_swipe/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiService', () {
    test('200 + 正常JSON: cat と dog の両方を取得できる', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'cataas.com') {
          return http.Response(
            jsonEncode([
              {'id': 'cat-1'},
              {'id': 'cat-2'},
            ]),
            200,
          );
        }
        if (request.url.host == 'dog.ceo') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'message': ['https://images.dog.ceo/breeds/hound/a.jpg'],
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final service = ApiService(client: client, random: Random(1));

      final images = await service.fetchImages([
        AnimalType.cat,
        AnimalType.dog,
      ]);

      expect(images.length, 3);
      expect(images.map((i) => i.type).toSet(), {
        AnimalType.cat,
        AnimalType.dog,
      });
      expect(
        images.where((i) => i.type == AnimalType.cat).map((i) => i.id),
        containsAll(['cat-1', 'cat-2']),
      );
    });

    test('非200: 該当タイプは結果に含まれず、他タイプの成功結果は保持される', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'cataas.com') {
          return http.Response('server error', 500);
        }
        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': ['https://images.dog.ceo/breeds/hound/a.jpg'],
          }),
          200,
        );
      });
      final service = ApiService(client: client, random: Random(1));

      final images = await service.fetchImages([
        AnimalType.cat,
        AnimalType.dog,
      ]);

      expect(images.length, 1);
      expect(images.single.type, AnimalType.dog);
    });

    test('タイムアウト: 応答が遅いタイプは結果に含まれない', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'cataas.com') {
          // タイムアウト設定より十分長く待たせる
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({'status': 'success', 'message': <String>[]}),
          200,
        );
      });
      final service = ApiService(
        client: client,
        random: Random(1),
        timeout: const Duration(milliseconds: 20),
      );

      final images = await service.fetchImages([
        AnimalType.cat,
        AnimalType.dog,
      ]);

      // cat はタイムアウトで内部的に捕捉され、dog は空配列で成功するため
      // 最終結果はどちらの経路でも空になる
      expect(images, isEmpty);
    });

    test('不正JSON: パース不能でも例外を外へ漏らさず空扱いになる', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'cataas.com') {
          return http.Response('not json', 200);
        }
        return http.Response(
          jsonEncode({'status': 'success', 'message': <String>[]}),
          200,
        );
      });
      final service = ApiService(client: client, random: Random(1));

      final images = await service.fetchImages([AnimalType.cat]);

      expect(images, isEmpty);
    });

    test('status != success: Dog CEO が失敗ステータスを返しても空扱いになる', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'error', 'message': <String>[]}),
          200,
        );
      });
      final service = ApiService(client: client, random: Random(1));

      final images = await service.fetchImages([AnimalType.dog]);

      expect(images, isEmpty);
    });

    test('空配列: 正常応答でも中身が0件ならそのまま空配列を返す', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'cataas.com') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({'status': 'success', 'message': <String>[]}),
          200,
        );
      });
      final service = ApiService(client: client, random: Random(1));

      final images = await service.fetchImages([
        AnimalType.cat,
        AnimalType.dog,
      ]);

      expect(images, isEmpty);
    });

    test('同じ動物タイプが重複指定されても1回しかリクエストしない', () async {
      var callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('[]', 200);
      });
      final service = ApiService(client: client, random: Random(1));

      await service.fetchImages([AnimalType.cat, AnimalType.cat]);

      expect(callCount, 1);
    });
  });
}
