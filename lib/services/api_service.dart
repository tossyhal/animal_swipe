import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/animal_model.dart';
import '../models/animal_type.dart';
import '../utils/logger.dart';
import 'animal_source.dart';

/// APIサービスを提供するプロバイダー
/// テストでは [IApiService] の Fake で override できるよう、
/// 具象型ではなくインターフェース型で公開する
///
/// `http.Client` はプロバイダー側で生成し、`ref.onDispose` で破棄する。
/// `ApiService` 自身はクライアントを所有しない（受け取って使うだけ）ため、
/// テストで注入した `MockClient` を誤って close してしまう心配がない。
final apiServiceProvider = Provider<IApiService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ApiService(client: client);
});

/// APIサービスのインターフェース
abstract class IApiService {
  Future<List<AnimalImage>> fetchImages(List<AnimalType> types);
}

/// APIサービスクラス
/// 各種動物画像を取得するためのサービス
///
/// 動物ごとの URL 構築とパースは [AnimalSource] が持つ。このクラスの責務は
/// 「複数ソースを並行に叩き、結果をまとめる」ことだけに絞っている。
class ApiService implements IApiService {
  static const Duration _defaultTimeout = Duration(seconds: 12);

  /// 通信に使う [http.Client]
  ///
  /// **必須**。既定値を持たせて内部で `http.Client()` を作ると、
  /// 呼び出し側が触れないクライアントを [ApiService] が抱え込むことになり、
  /// close する手段がないままソケットが残る。所有権は常に呼び出し側
  /// （通常は [apiServiceProvider]）に置き、このクラスは受け取って使うだけ。
  final http.Client _client;

  /// 乱数生成器
  ///
  /// 呼び出しのたびに `Random()` を作らないようフィールドで保持する。
  /// テストではシードを固定した [Random] を渡して URL を決定的にできる。
  final Random _random;

  /// リクエスト 1 回あたりのタイムアウト
  ///
  /// 既定は 12 秒。テストでは短い値を渡し、実時間を待たずに
  /// タイムアウト経路を再現できるようにする。
  final Duration _timeout;

  // 呼び出し側は `ApiService(client: ...)` と書く。
  //
  // Dart は私有フィールドの初期化仮引数（`this._client`）に対し、
  // 先頭の `_` を落とした公開名を呼び出し側の名前として自動で割り当てる。
  // 名前付き引数は `_` で始められないため、この変換は言語仕様で保証されている
  // （`_client:` と書くと "should use the corresponding public name 'client'"
  // というコンパイルエラーになる）。
  ApiService({required this._client, Random? random, Duration? timeout})
    : _random = random ?? Random(),
      _timeout = timeout ?? _defaultTimeout;

  /// 指定された動物タイプの画像を取得し、全画像リストを返す
  /// 各動物タイプごとに画像を取得し、取得した画像をシャッフルして返す
  @override
  Future<List<AnimalImage>> fetchImages(List<AnimalType> types) async {
    final uniqueTypes = types.toSet();
    final results = await Future.wait(
      uniqueTypes.map((type) async {
        try {
          return await _fetchImagesForType(type);
        } catch (e) {
          AppLogger.error('Error fetching ${type.id} images', e);
          return <AnimalImage>[];
        }
      }),
    );
    final allImages = results.expand((images) => images).toList();

    // 画像リストをシャッフル
    allImages.shuffle(_random);
    return allImages;
  }

  /// 指定された動物タイプに対する画像を取得する
  ///
  /// 対応する [AnimalSource] が登録されていない場合は空のリストを返す。
  Future<List<AnimalImage>> _fetchImagesForType(AnimalType type) async {
    final source = AnimalSource.forType(type);
    if (source == null) {
      // 列挙子を足したのにソースを登録し忘れた場合。
      // 画面を落とさず、他の動物だけで続行する。
      AppLogger.warning('AnimalSource が未登録です: ${type.id}');
      return const <AnimalImage>[];
    }

    final response = await _client
        .get(source.buildUri(_random))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load ${type.id} images: HTTP ${response.statusCode}',
      );
    }

    return source.parseResponse(response.body);
  }
}
