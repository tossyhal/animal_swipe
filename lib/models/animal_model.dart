import 'package:flutter/foundation.dart';

/// 動物画像データを保持するモデルクラス
///
/// 値オブジェクトとして扱う。同じ内容なら同じものとみなせるよう
/// [==] / [hashCode] を実装し、`const` で生成できるようにしている。
///
/// ## codegen（freezed / json_serializable）を使わない理由
///
/// フィールドは 5 個・すべて [String] で、生成コードに任せるほどの
/// 複雑さがない。一方 `build_runner` を入れると、生成物のコミット有無、
/// CI での codegen ステップ、`part` ファイルの追従といった運用コストが
/// 恒常的に乗る（#27 の CI 品質ゲートにも codegen 実行の追加が必要になる）。
/// 手書きの方が総コストが低いと判断した。
/// モデルが増えて手書きが負担になった時点で再検討する。
@immutable
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

  const AnimalImage({
    required this.id,
    required this.url,
    required this.type,
    this.description,
    this.source,
  });

  /// [copyWith] で「引数が省略された」ことを表す番兵。
  ///
  /// `null` を「省略」と同じ意味にしてしまうと、[description] や [source] を
  /// 明示的に `null` へ戻せなくなるため、省略と `null` 指定を区別する。
  static const Object _unset = Object();

  /// 一部のフィールドだけを差し替えた複製を返す
  ///
  /// [description] / [source] は `null` を渡すと明示的に消去される。
  /// 引数自体を省略した場合は現在の値が維持される。
  AnimalImage copyWith({
    String? id,
    String? url,
    String? type,
    Object? description = _unset,
    Object? source = _unset,
  }) {
    return AnimalImage(
      id: id ?? this.id,
      url: url ?? this.url,
      type: type ?? this.type,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      source: identical(source, _unset) ? this.source : source as String?,
    );
  }

  /// 永続化用の JSON へ変換する（#8 のお気に入り保存で使う）
  ///
  /// [AnimalImage.fromJson] と往復できる形式であること。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'url': url,
      'type': type,
      'description': description,
      'source': source,
    };
  }

  /// [toJson] が出力した JSON から復元する
  ///
  /// API レスポンスのパースではなく、あくまで自前で保存した値の復元用。
  /// 外部 API ごとのパースは各動物ソース側の責務とする（#15）。
  ///
  /// 必須フィールドが欠けている・型が違う場合は [FormatException] を投げる。
  /// 保存データの破損を黙って空文字で埋めると、URL が空の画像が
  /// 一覧に紛れ込んで原因が追いにくくなるため。
  factory AnimalImage.fromJson(Map<String, dynamic> json) {
    return AnimalImage(
      id: _requireString(json, 'id'),
      url: _requireString(json, 'url'),
      type: _requireString(json, 'type'),
      description: _optionalString(json, 'description'),
      source: _optionalString(json, 'source'),
    );
  }

  static String _requireString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException(
      'AnimalImage.fromJson: "$key" は String である必要があります（実際: $value）',
    );
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException(
      'AnimalImage.fromJson: "$key" は String か null である必要があります（実際: $value）',
    );
  }

  /// APIレスポンスから[AnimalImage]オブジェクトを生成するファクトリコンストラクタ
  ///
  /// [json]：APIから取得したJSONデータ
  /// [type]：動物の種類（'cat'、'dog'）
  ///
  /// NOTE: この型別分岐は #15 で `AnimalSource` 側へ移し、ここからは削除する。
  factory AnimalImage.fromApiJson(Map<String, dynamic> json, String type) {
    if (type == 'cat') {
      // The Cat API のパースロジック
      return AnimalImage(
        id: json['id'] ?? '',
        url: 'https://cataas.com/cat/${json['id']}',
        type: 'cat',
        source: 'Cat as a service',
      );
    } else if (type == 'dog') {
      // The Dog API のパースロジック
      final url = json['url'] as String? ?? '';
      return AnimalImage(
        id: json['id'] as String? ?? url,
        url: url,
        type: 'dog',
        description: json['breeds']?.isNotEmpty == true
            ? json['breeds'][0]['name']
            : null,
        source: 'The Dog API',
      );
    } else {
      throw Exception('Unsupported animal type: $type');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimalImage &&
        other.id == id &&
        other.url == url &&
        other.type == type &&
        other.description == description &&
        other.source == source;
  }

  @override
  int get hashCode => Object.hash(id, url, type, description, source);

  @override
  String toString() {
    return 'AnimalImage(id: $id, url: $url, type: $type, '
        'description: $description, source: $source)';
  }
}
