import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_model.dart';
import '../services/prefs_service.dart';

/// お気に入りの動物画像リストを管理するプロバイダー
final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<AnimalImage>>(
      FavoritesNotifier.new,
    );

/// お気に入りの動物画像リストを管理する [Notifier]
///
/// ## 保存件数の上限とあふれた際の挙動（#8）
///
/// [maxFavorites] 件を上限とする。SharedPreferences は大きな値の保存に
/// 向かないストレージであり、無制限に増やし続けると読み書きコストが
/// じわじわ増える。一方で明示的な上限のない「お気に入り」機能は珍しく、
/// ユーザーが際限なく好きを送れてしまうこの手のアプリの性質上、
/// どこかで頭打ちにする必要がある。
///
/// 上限に達した状態で新たに追加された場合は、**一番古いお気に入りを
/// 追い出して新しいものを追加する**（FIFO）。
/// 「上限に達したので追加を拒否する」という選択肢も検討したが、
/// スワイプして「好き」を押したのに何も起きない（保存されない）のは
/// このアプリの価値そのもの（#8 の課題意識）を裏切る体験になる。
/// 直近の「好き」を必ず反映し、代わりに一番古い・思い入れの薄いであろう
/// 1件を黙って手放す方が、ユーザーの体感として自然だと判断した。
class FavoritesNotifier extends Notifier<List<AnimalImage>> {
  /// お気に入りとして保持する最大件数
  static const int maxFavorites = 200;

  // build() は依存の変化で再実行され、その都度この場で再代入される。
  // final にすると 2 回目の代入で LateInitializationError になるため late のみ。
  late PrefsService _prefsService;

  @override
  List<AnimalImage> build() {
    _prefsService = ref.watch(prefsServiceProvider);
    return _prefsService.getFavorites();
  }

  /// 指定した画像がお気に入り済みか
  ///
  /// 全フィールド一致ではなく [AnimalImage.id] / [AnimalImage.type] で判定する。
  /// API から同じ画像を再取得した際に description 等の付随情報が
  /// 微妙に変わっていても、「同じ画像」として重複登録しないため。
  bool isFavorite(AnimalImage image) {
    return state.any((f) => f.id == image.id && f.type == image.type);
  }

  /// お気に入りに追加する
  ///
  /// 既に追加済みなら何もしない。上限を超える場合は一番古いものを追い出す
  /// （挙動の詳細はクラスコメント参照）。
  void add(AnimalImage image) {
    if (isFavorite(image)) return;

    var next = [...state, image];
    if (next.length > maxFavorites) {
      next = next.sublist(next.length - maxFavorites);
    }
    state = next;
    _prefsService.saveFavorites(state);
  }

  /// お気に入りから削除する
  ///
  /// 追加されていない画像を渡しても何もしない。
  void remove(AnimalImage image) {
    if (!isFavorite(image)) return;

    state = state
        .where((f) => !(f.id == image.id && f.type == image.type))
        .toList();
    _prefsService.saveFavorites(state);
  }

  /// お気に入り状態を反転させる
  void toggle(AnimalImage image) {
    if (isFavorite(image)) {
      remove(image);
    } else {
      add(image);
    }
  }
}
