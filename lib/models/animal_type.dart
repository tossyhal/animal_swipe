import '../constants/app_strings.dart';

/// アプリが扱う動物の種類
///
/// 以前は `'cat'` / `'dog'` の生文字列が API 層・モデル層・画面層に散在しており、
/// タイプミスをコンパイラが検出できなかった。列挙型にすることで、
/// 「存在しない動物タイプ」はコンパイルエラーになる。
///
/// 表示名・説明・絵文字もここに集約しているため、画面側は
/// [AnimalType.values] を並べるだけでよく、動物を増やしても画面の
/// 変更は不要になる。
///
/// ## 新しい動物を追加する手順
///
/// 1. この列挙型に 1 要素足す
/// 2. `lib/services/animal_source.dart` に [AnimalSource] の実装を 1 つ足し、
///    レジストリに登録する
///
/// 2 を忘れた場合は `test/animal_source_test.dart` の
/// 「全ての AnimalType にソースが登録されている」で検出される。
enum AnimalType {
  cat(
    id: 'cat',
    label: AppStrings.animalCat,
    description: AppStrings.animalCatDescription,
    emoji: AppStrings.animalCatEmoji,
  ),
  dog(
    id: 'dog',
    label: AppStrings.animalDog,
    description: AppStrings.animalDogDescription,
    emoji: AppStrings.animalDogEmoji,
  );

  const AnimalType({
    required this.id,
    required this.label,
    required this.description,
    required this.emoji,
  });

  /// 永続化・API 向けの安定した識別子
  ///
  /// [Enum.name] ではなくこの値を使う。列挙子の名前を変えても
  /// 保存済みデータが読めなくなることがないようにするため。
  final String id;

  /// 画面に出す表示名（例: 「ねこ」）
  final String label;

  /// 画面に出す短い説明
  final String description;

  /// 画面に出す絵文字
  final String emoji;

  /// [id] から [AnimalType] を引く。未知の文字列は `null`
  ///
  /// 保存済みデータに、かつて存在した／将来追加される動物の id が
  /// 混ざっていても落ちないよう、例外ではなく `null` を返す。
  static AnimalType? fromId(String id) {
    for (final type in AnimalType.values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// id のリストを [AnimalType] のリストへ変換する
  ///
  /// **未知の id は黙って捨てる。** 端末に残った古い選択（例: `'bird'`）で
  /// 起動時にクラッシュさせないことを優先する。
  static List<AnimalType> fromIds(Iterable<String> ids) {
    final result = <AnimalType>[];
    for (final id in ids) {
      final type = fromId(id);
      if (type != null && !result.contains(type)) result.add(type);
    }
    return result;
  }
}
