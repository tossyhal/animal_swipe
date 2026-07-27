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
final apiServiceProvider = Provider<IApiService>((ref) => ApiService());

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
  static const Duration _requestTimeout = Duration(seconds: 12);

  /// 乱数生成器
  ///
  /// 呼び出しのたびに `Random()` を作らないようフィールドで保持する。
  /// テストではシードを固定した [Random] を渡して URL を決定的にできる。
  final Random _random;

  ApiService({Random? random}) : _random = random ?? Random();

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

    final response = await http
        .get(source.buildUri(_random))
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load ${type.id} images: HTTP ${response.statusCode}',
      );
    }

    return source.parseResponse(response.body);
  }
}
