import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  /// APIキーのマッピング
  /// 'cat' と 'dog' はそれぞれ The Cat API と The Dog API 用
  late final Map<String, String> _apiKeys;

  ApiService() {
    try {
      _apiKeys = {
        'cat': dotenv.env['CAT_API_KEY'] ?? '',
        'dog': dotenv.env['DOG_API_KEY'] ?? '',
      };
    } catch (e) {
      // テスト環境など、.envファイルが存在しない場合は空文字を設定
      _apiKeys = {'cat': '', 'dog': ''};
    }
  }

  /// APIのURLマッピング
  /// 'cat' と 'dog' のURLを定義
  /// その他の動物タイプについては、別途URLの定義が必要
  final Map<String, String> _apiUrls = {
    'cat': 'https://api.thecatapi.com/v1/images/search?limit=10',
    'dog': 'https://api.thedogapi.com/v1/images/search?limit=10',
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

    // ヘッダー情報の準備
    Map<String, String> headers = {};

    // APIキーの設定
    if (type == 'cat') {
      headers['x-api-key'] = _apiKeys['cat']!;
    } else if (type == 'dog') {
      headers['x-api-key'] = _apiKeys['dog']!;
    }

    // APIリクエストの実行
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => AnimalImage.fromJson(item, type)).toList();
    } else {
      throw Exception('Failed to load $type images');
    }
  }
}
