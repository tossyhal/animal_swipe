import 'dart:convert';
import 'dart:math';

import '../constants/app_strings.dart';
import '../models/animal_model.dart';
import '../models/animal_type.dart';
import '../models/dog_breed.dart';

/// 1 回のリクエストで取得する画像の件数
///
/// 山札の追加読み込み閾値（3 枚）に対して十分な余裕があり、かつ
/// 外部 API に負荷をかけない値として 10 件にしている。
const int kImagesPerRequest = 10;

/// Cataas に要求する画像の縦幅（px）
///
/// カード画像は `BoxFit.cover` のポートレートなペイン（縦長）に表示される。
/// cover はペインを覆うまで拡大してからクロップするため、横長の画像では
/// 「幅」ではなく「高さ」が拡大率を決める側になる。横幅だけを指定すると、
/// 横長画像で高さが足りずアップスケールされ画質が劣化する（#7 で判明）。
///
/// 800（論理 px、ペインの縦幅の目安）× DPR 2 = 1600 とし、DPR 2 の端末
/// までは十分な余裕を持たせている。DPR 3 以上の端末では多少
/// アップスケールされることになるが、原寸（数千 px）を毎回転送するのに
/// 比べれば転送量を大きく削減できるため、許容するトレードオフとしている
/// （実端末での計測は #7 の残課題）。
///
/// 逆にペインより「幅が狭い」= 非常に縦長な画像では高さ基準でも
/// アップスケールされ得るが、そのような極端な縦長画像は稀であり、
/// 従来の横長画像より遥かに影響が小さいため許容する。
const int kCatImageHeight = 1600;

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
          // height 指定でサーバー側リサイズさせ、表示に不要な原寸画像の
          // 転送を避ける（#7）。BoxFit.cover のポートレートペインなので
          // 拡大率を決めるのは高さ側（kCatImageHeight のコメント参照）。
          url: 'https://cataas.com/cat/$id?height=$kCatImageHeight',
          type: AnimalType.cat,
          source: 'Cat as a service',
        ),
      );
    }
    return images;
  }
}

/// Dog CEO (dog.ceo) から犬画像を取得するソース
///
/// ## 犬種名について
///
/// 全犬種ランダム API のレスポンスは `{"message": [URL...], "status": "success"}`
/// だけで、**犬種を表すフィールドは存在しない**。したがって犬種名は
/// 画像 URL から [DogBreed.fromImageUrl] で復元する。
/// 復元できない URL は例外にせず「いぬ」へフォールバックする。
///
/// ## 画像サイズについて（#7）
///
/// Cataas とは異なり、Dog CEO は `images.dog.ceo` 上の静的ファイルを
/// そのまま返すだけで、width/height によるリサイズ指定には対応していない。
/// 存在しないクエリパラメータを付けても API 側で無視されるだけで実害は
/// 少ないが、「対応していないパラメータを憶測で足す」実装を避けるため、
/// 犬の画像 URL には手を加えない。
class DogSource extends AnimalSource {
  /// 明示的に選択された犬種（#32 用）
  ///
  /// 指定されている場合は、**URL を再解析せずこの値をそのまま使う**。
  /// 選択済みの情報の方が URL からの推測より確実だからである。
  /// 併せて取得先も犬種別エンドポイントへ切り替える。
  final DogBreed? breed;

  const DogSource({this.breed});

  static const String _randomEndpoint =
      'https://dog.ceo/api/breeds/image/random';
  static const String _breedEndpoint = 'https://dog.ceo/api/breed';

  @override
  AnimalType get type => AnimalType.dog;

  @override
  Uri buildUri(Random random) {
    final selected = breed;
    if (selected == null) {
      // 全犬種ランダム取得。件数はパスに含める仕様
      return Uri.parse('$_randomEndpoint/$kImagesPerRequest');
    }

    // 犬種指定の取得。サブ犬種はパスをもう 1 段掘る仕様
    final sub = selected.subBreed;
    final path = sub == null
        ? '${selected.breed}/images/random/$kImagesPerRequest'
        : '${selected.breed}/$sub/images/random/$kImagesPerRequest';
    return Uri.parse('$_breedEndpoint/$path');
  }

  /// この URL の画像に付ける犬種名
  ///
  /// 明示選択があればそれを、なければ URL から復元する。
  /// どちらも得られなければ「いぬ」を返す（`null` にはしない）。
  String _breedLabelFor(String url) {
    final resolved = breed ?? DogBreed.fromImageUrl(url);
    return resolved?.displayName ?? AppStrings.animalDog;
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
      // PWA は HTTPS で配信しているため、http:// の画像は混在コンテンツとして
      // ブラウザにブロックされ、カードが空白になる。API 側の異常（CDN 設定
      // 変更等）で紛れ込んだ場合に静かに空白カードを出すより、その1件だけ
      // 読み飛ばして他の画像は表示できる状態を保つ。
      if (!item.startsWith('https://')) continue;
      images.add(
        AnimalImage(
          id: item,
          url: item,
          type: AnimalType.dog,
          description: _breedLabelFor(item),
          source: 'Dog CEO',
        ),
      );
    }
    return images;
  }
}
