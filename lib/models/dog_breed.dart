import 'package:flutter/foundation.dart';

/// Dog CEO の犬種（親犬種とサブ犬種の組）
///
/// ## なぜ URL から復元するのか
///
/// Dog CEO の全犬種ランダム API（`/api/breeds/image/random/{n}`）が返すのは
/// 画像 URL の配列と `status` だけで、**犬種オブジェクトは返らない**。
/// 一方で画像 URL 自体が `.../breeds/{フォルダ名}/xxx.jpg` という構造を持ち、
/// そのフォルダ名が犬種を表している。よって URL から復元する。
///
/// フォルダ名の形式は 2 通り:
///
/// - `breeds/hound/...`        → 親犬種のみ
/// - `breeds/terrier-border/...` → `{親犬種}-{サブ犬種}`
///
/// API 上の親子関係（terrier の下に border がある）はそのまま [breed] /
/// [subBreed] に保持し、人間向けの並び（Border Terrier）は [displayName]
/// でのみ組み替える。表示の都合で構造を壊さないため。
@immutable
class DogBreed {
  /// 親犬種（例: `terrier`）。Dog CEO のフォルダ名そのまま
  final String breed;

  /// サブ犬種（例: `border`）。存在しない場合は `null`
  final String? subBreed;

  const DogBreed({required this.breed, this.subBreed});

  /// 人間向けの表示名（例: `Border Terrier` / `Hound`）
  ///
  /// Dog CEO のフォルダ名は「親-サブ」の順だが、英語の一般的な呼称は
  /// 「サブ 親」の順（border terrier）なので入れ替える。
  String get displayName {
    final parent = _capitalizeWords(breed);
    final sub = subBreed;
    if (sub == null) return parent;
    return '${_capitalizeWords(sub)} $parent';
  }

  /// 画像 URL から犬種を復元する。復元できなければ `null`
  ///
  /// **例外は投げない。** URL の形式が未知・不正な場合は `null` を返し、
  /// 呼び出し側でフォールバック表示に倒す。ランダム画像 API の URL 形式が
  /// 将来変わっても、画像そのものは表示できる状態を保つため。
  static DogBreed? fromImageUrl(String url) {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException {
      return null;
    }

    final segments = uri.pathSegments;
    final index = segments.indexOf('breeds');
    // 'breeds' が無い、または 'breeds' が最後（犬種フォルダが続かない）
    if (index < 0 || index + 1 >= segments.length) return null;

    return fromFolderName(segments[index + 1]);
  }

  /// Dog CEO のフォルダ名（`terrier-border` など）から復元する
  ///
  /// 想定外の形式は `null`。
  static DogBreed? fromFolderName(String folderName) {
    if (folderName.isEmpty) return null;

    final parts = folderName.split('-');
    // 空要素を含む（'-terrier' / 'terrier--border' など）なら不正とみなす
    if (parts.any((part) => !_isBreedWord(part))) return null;

    if (parts.length == 1) return DogBreed(breed: parts.first);

    // Dog CEO の実データは高々 2 要素だが、将来 3 要素以上が来ても
    // 落ちないよう、先頭を親犬種、残りをサブ犬種として扱う。
    return DogBreed(breed: parts.first, subBreed: parts.sublist(1).join(' '));
  }

  /// 犬種名として妥当な語か（英字のみ）
  ///
  /// Dog CEO のフォルダ名は英小文字のみで構成される。数字や記号が
  /// 混ざっている場合は犬種フォルダではないと判断する。
  static bool _isBreedWord(String value) {
    if (value.isEmpty) return false;
    for (final unit in value.codeUnits) {
      final isLower = unit >= 0x61 && unit <= 0x7a; // a-z
      final isUpper = unit >= 0x41 && unit <= 0x5a; // A-Z
      if (!isLower && !isUpper) return false;
    }
    return true;
  }

  /// 空白区切りの各語の先頭を大文字にする
  static String _capitalizeWords(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DogBreed &&
        other.breed == breed &&
        other.subBreed == subBreed;
  }

  @override
  int get hashCode => Object.hash(breed, subBreed);

  @override
  String toString() => 'DogBreed(breed: $breed, subBreed: $subBreed)';
}
