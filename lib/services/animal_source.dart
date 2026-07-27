import 'dart:convert';
import 'dart:math';

import '../models/animal_model.dart';
import '../models/animal_type.dart';

/// 1 回のリクエストで取得する画像の件数
///
/// 山札の追加読み込み閾値（3 枚）に対して十分な余裕があり、かつ
/// 外部 API に負荷をかけない値として 10 件にしている。
const int kImagesPerRequest = 10;

/// 1 種類の動物に対する「URL の組み立て」と「レスポンスのパース」をまとめたもの
///
/// 以前は `ApiService._fetchImagesForType` の if / else-if と `_apiUrls` マップで
/// 二重管理していた。API を足すたびに 2 箇所を直す必要があり、片方だけ直す
/// 事故が起きやすかったため、動物ごとに 1 クラスへ閉じ込めている。
///
/// 実装は状態を持たず、`const` で生成できること。
abstract class AnimalSource {
  const AnimalSource();

  /// このソースが担当する動物の種類
  AnimalType get type;

  /// 取得先の URL を組み立てる
  ///
  /// [random] は毎回 `Random()` を作らずに済むよう呼び出し側から渡す。
  /// テストではシード付きの [Random] を渡して URL を固定できる。
  Uri buildUri(Random random);

  /// レスポンスボディを [AnimalImage] のリストへ変換する
  ///
  /// 契約違反（想定と違う JSON 構造、`status` が success でない等）は
  /// 例外を投げてよい。呼び出し側がソース単位で握る。
  List<AnimalImage> parseResponse(String body);

  /// [type] に対応するソースを返す。未登録なら `null`
  static AnimalSource? forType(AnimalType type) => _sources[type];

  /// 登録済みのソース一覧
  static const Map<AnimalType, AnimalSource> _sources =
      <AnimalType, AnimalSource>{
        AnimalType.cat: CatSource(),
        AnimalType.dog: DogSource(),
      };
}

/// Cat as a service (cataas.com) から猫画像を取得するソース
class CatSource extends AnimalSource {
  const CatSource();

  /// `skip` に与える乱数の上限。API 側の総件数に対して十分小さく、
  /// かつ毎回同じ先頭が返らない程度にはばらつく値。
  static const int _skipRange = 1000;

  static const String _endpoint = 'https://cataas.com/api/cats';

  @override
  AnimalType get type => AnimalType.cat;

  @override
  Uri buildUri(Random random) {
    // cataas はリスト形式で返すため、ランダムな skip を与えて
    // 毎回違う画像が返るようにする
    return Uri.parse(_endpoint).replace(
      queryParameters: <String, String>{
        'limit': '$kImagesPerRequest',
        'skip': '${random.nextInt(_skipRange)}',
      },
    );
  }

  @override
  List<AnimalImage> parseResponse(String body) {
    final decoded = json.decode(body);
    if (decoded is! List) {
      throw FormatException('cataas: 配列が返る想定だが ${decoded.runtimeType} だった');
    }

    final images = <AnimalImage>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      if (id is! String || id.isEmpty) continue;
      images.add(
        AnimalImage(
          id: id,
          url: 'https://cataas.com/cat/$id',
          type: AnimalType.cat,
          source: 'Cat as a service',
        ),
      );
    }
    return images;
  }
}

/// Dog CEO (dog.ceo) から犬画像を取得するソース
class DogSource extends AnimalSource {
  const DogSource();

  static const String _endpoint = 'https://dog.ceo/api/breeds/image/random';

  @override
  AnimalType get type => AnimalType.dog;

  @override
  Uri buildUri(Random random) {
    // 全犬種ランダム取得。件数はパスに含める仕様
    return Uri.parse('$_endpoint/$kImagesPerRequest');
  }

  @override
  List<AnimalImage> parseResponse(String body) {
    final decoded = json.decode(body);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Dog CEO: オブジェクトが返る想定だが ${decoded.runtimeType} だった',
      );
    }
    if (decoded['status'] != 'success') {
      throw FormatException(
        'Dog CEO: status が success ではない（${decoded['status']}）',
      );
    }

    final message = decoded['message'];
    if (message is! List) {
      throw FormatException(
        'Dog CEO: message は配列の想定だが ${message.runtimeType} だった',
      );
    }

    final images = <AnimalImage>[];
    for (final item in message) {
      if (item is! String || item.isEmpty) continue;
      images.add(
        AnimalImage(
          id: item,
          url: item,
          type: AnimalType.dog,
          source: 'Dog CEO',
        ),
      );
    }
    return images;
  }
}
