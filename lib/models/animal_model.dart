/// 動物画像データを保持するモデルクラス
class AnimalImage {
  /// 画像の一意な識別子
  final String id;

  /// 画像のURL
  final String url;

  /// 動物の種類
  final String type;

  /// 画像の説明（任意）
  final String? description;

  /// 画像の提供元（任意）
  final String? source;

  AnimalImage({
    required this.id,
    required this.url,
    required this.type,
    this.description,
    this.source,
  });

  /// JSONデータから[AnimalImage]オブジェクトを生成するファクトリコンストラクタ
  ///
  /// [json]：APIから取得したJSONデータ
  /// [type]：動物の種類（'cat'、'dog'）
  factory AnimalImage.fromJson(Map<String, dynamic> json, String type) {
    if (type == 'cat') {
      // The Cat API のパースロジック
      return AnimalImage(
        id: json['id'] ?? '',
        url: json['url'] ?? '',
        type: 'cat',
        description:
            json['breeds']?.isNotEmpty == true
                ? json['breeds'][0]['name']
                : null,
        source: 'The Cat API',
      );
    } else if (type == 'dog') {
      // The Dog API のパースロジック
      return AnimalImage(
        id: json['id'] ?? '',
        url: json['url'] ?? '',
        type: 'dog',
        description:
            json['breeds']?.isNotEmpty == true
                ? json['breeds'][0]['name']
                : null,
        source: 'The Dog API',
      );
    } else {
      throw Exception('Unsupported animal type: $type');
    }
  }
}
