import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/animal_model.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// APIサービスのインターフェース
abstract class IApiService {
  Future<List<AnimalImage>> fetchImages(List<String> types);
}

/// APIサービスクラス
/// 各種動物画像を取得するためのサービス
class ApiService implements IApiService {
  /// APIのURLマッピング
  /// 'cat' は cataas、'dog' は Dog API を使用
  final Map<String, String> _apiUrls = {
    'cat': 'https://cataas.com/api/cats', // パラメータは動的に付与
    'dog': 'https://dog.ceo/api/breeds/image/random/10',
  };

  /// 指定された動物タイプの画像を取得し、全画像リストを返す
  /// 各動物タイプごとに画像を取得し、取得した画像をシャッフルして返す
  @override
  Future<List<AnimalImage>> fetchImages(List<String> types) async {
    List<AnimalImage> allImages = [];

    // 各動物タイプごとに画像を取得
    for (final type in types) {
      try {
        final images = await _fetchImagesForType(type);
        allImages.addAll(images);
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching $type images: $e');
        }
      }
    }

    // 画像リストをシャッフル
    allImages.shuffle();
    return allImages;
  }

  /// 指定された動物タイプに対する画像を取得するプライベートメソッド
  /// 対応するURLが存在しない場合は空のリストを返します。
  Future<List<AnimalImage>> _fetchImagesForType(String type) async {
    final url = _apiUrls[type];
    if (url == null) {
      // 対応するURLが定義されていない場合、空のリストを返す
      return [];
    }

    if (type == 'dog') {
      // Dog API の場合：JSON構造が { "message": [ ... ], "status": "success" } になっているため、messageから取得
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        if (jsonData['status'] == 'success') {
          final List<dynamic> messages = jsonData['message'];
          return messages
              .map((item) => AnimalImage.fromJson({'url': item}, type))
              .toList();
        } else {
          throw Exception('Dog API returned error');
        }
      } else {
        throw Exception('Failed to load dog images');
      }
    } else if (type == 'cat') {
      // 猫の場合：cataas APIはリスト形式で返すが、ランダムな画像を取得するためにskipパラメータをランダムに設定
      // ここでは、適当に 0〜999 の間の値をskipに設定
      final randomSkip = Random().nextInt(1000);
      final catUrl = '$url?limit=10&skip=$randomSkip';
      final response = await http.get(Uri.parse(catUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body) as List<dynamic>;
        return data.map((item) => AnimalImage.fromJson(item, type)).toList();
      } else {
        throw Exception('Failed to load cat images');
      }
    } else {
      return [];
    }
  }
}
