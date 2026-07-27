import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_model.dart';
import '../models/animal_type.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../utils/logger.dart';

/// 選択された動物タイプを管理するプロバイダー
final selectedAnimalTypesProvider =
    NotifierProvider<SelectedAnimalTypesNotifier, List<AnimalType>>(
      SelectedAnimalTypesNotifier.new,
    );

/// 選択された動物タイプの [Notifier]
class SelectedAnimalTypesNotifier extends Notifier<List<AnimalType>> {
  // build() は依存の変化で再実行され、その都度この場で再代入される。
  // final にすると 2 回目の代入で LateInitializationError になるため late のみ。
  late PrefsService _prefsService;

  @override
  List<AnimalType> build() {
    _prefsService = ref.watch(prefsServiceProvider);
    return _prefsService.getSelectedAnimalTypes();
  }

  /// 動物タイプの選択状態を更新し、ローカルに保存する
  ///
  /// [AnimalType] になったため、空文字列や未知のタイプを弾く必要はない。
  /// 存在しない動物を渡すことはコンパイル時に不可能になった。
  void selectType(AnimalType type, bool isSelected) {
    if (isSelected && !state.contains(type)) {
      state = [...state, type];
    } else if (!isSelected && state.contains(type)) {
      state = state.where((t) => t != type).toList();
    }
    _prefsService.saveSelectedAnimalTypes(state);
  }

  /// 現在の選択状態をローカルに保存する（再保存）
  void saveSelectedTypes() {
    _prefsService.saveSelectedAnimalTypes(state);
  }
}

/// 画像リストを管理するプロバイダー
///
/// 読み込み中・エラー・データの 3 状態を [AsyncValue] 1 つで表現する。
/// 以前は loading / error を別々の `StateProvider` に手動同期していたが、
/// 状態が分散して整合性が壊れやすいため廃止した。
///
/// ## 選択タイプが変わったときの挙動: **意図的にリセットして取り直す**
///
/// [build] が [selectedAnimalTypesProvider] を watch しているため、
/// 選択が変わると山札は破棄され、新しい選択で取得し直される。
/// これは意図した仕様であり、副作用ではない。
///
/// 「いぬ」の選択を外したのに、既に取得済みのいぬの画像が残り続けるのは
/// ユーザーの意図に反する。フィルタを外した瞬間に反映されるべきなので、
/// 維持ではなくリセットを選んでいる。
///
/// スワイプ画面に種類フィルタを足す場合も、この挙動でそのまま動く。
/// なお現状の StartScreen でのトグルは、スワイプ画面が居らず
/// このプロバイダーが autoDispose されているため取得を発生させない。
final animalImagesProvider =
    AsyncNotifierProvider<AnimalImagesNotifier, List<AnimalImage>>(
      AnimalImagesNotifier.new,
      // スワイプ画面を離れたら破棄し、次に入った時に必ず取り直す。
      // 保持したままだと、山札が尽きた状態でホームへ戻り同じ選択で再開した際に
      // build() が再実行されず、ローディング表示のまま進めなくなる。
      isAutoDispose: true,
      // Riverpod 3 は失敗した provider を既定で自動リトライするが、
      // ここでは無効化して「エラー画面 + 手動リトライ」を UI の責務に保つ。
      // リトライ方針（対象・回数・バックオフ）は #17 で明示的に実装する。
      retry: (retryCount, error) => null,
    );

/// 動物画像のリストを管理する [AsyncNotifier]
class AnimalImagesNotifier extends AsyncNotifier<List<AnimalImage>> {
  /// 画像追加読み込みの閾値
  static const int _loadMoreThreshold = 3;

  /// 追加読み込みが進行中かどうか。
  /// 初回読み込みの進行状況は [state] の [AsyncValue.isLoading] が表すため、
  /// このフラグは loadMoreImages の多重実行防止だけに使う。
  bool _isLoadingMore = false;

  /// 発行した追加読み込みの通し番号。最後に発行したものだけが「現行」。
  int _loadMoreRequestId = 0;

  /// 山札の世代。取得し直して**別の山札に入れ替わる**たびに増える。
  /// 追加読み込みで末尾に継ぎ足す場合は同じ山札なので増やさない。
  ///
  /// カード操作は表示時点の世代を持ち回り、通知が遅れて届いた時に
  /// 「その操作は今の山札に対するものか」を判定する。
  /// ランダム画像 API は同じ画像を返し得るため、URL の一致では
  /// 山札の同一性を保証できない（Codex レビューの指摘）。
  ///
  /// トークンは [_nextDeckToken] から採番する。invalidate で Notifier ごと
  /// 作り直されるとインスタンス変数は 0 に戻るため、インスタンス内の
  /// カウンタだと新旧で同じ値が再利用され、古い操作が新しい山札を
  /// 通過してしまう。プロセス全体で単調増加する採番元を使って避ける。
  int _deckGeneration = 0;

  /// 山札トークンの採番元（プロセス全体で一意）
  static int _nextDeckToken = 0;

  int get deckGeneration => _deckGeneration;

  /// Undo 用に保持する「直前に取り除いた 1 枚」（#9）。
  ///
  /// 深さ 1（スタックにしない）でよいと判断した。issue の要求は
  /// 「直前の1枚」を戻せることであり、複数手前まで遡る Undo は
  /// 求められていない。スタックにすると、山札の世代管理やお気に入り
  /// 取消判定（[_lastRemovedShouldUnfavorite]）を要素数分やり取りする
  /// 必要が出るが、それに見合うだけの要求がないため、単一の直前カードを
  /// 保持するだけに留めている。
  AnimalImage? _lastRemoved;

  /// [_lastRemoved] を取り除いた時点の [_deckGeneration]。
  ///
  /// build() で山札が入れ替わると世代が変わる。Undo 時にここが現在の
  /// [_deckGeneration] と一致しなければ、そのカードは「もう存在しない
  /// 山札」の要素であり、今の山札の先頭に戻すことはできない
  /// （removeTopImage の deckToken 照合と同じ理由）。
  int? _lastRemovedDeckToken;

  /// この除去が「好き」によるもので、かつそのスワイプが実際に
  /// お気に入りを新規追加したか。
  ///
  /// 既にお気に入り登録済みの画像を再度「好き」した場合、
  /// favoritesProvider.add は何もしない（重複追加しない）ため、
  /// その場合に Undo でお気に入りを消すと、このスワイプより前からの
  /// お気に入りを誤って消してしまう。呼び出し側（SwipeScreen）が
  /// スワイプ直前に isFavorite を見て判定し、ここへ渡す。
  bool _lastRemovedShouldUnfavorite = false;

  /// 直前の 1 枚を Undo で戻せる状態か。
  ///
  /// 再取得中は戻す先の山札自体が確定していないため false。
  bool get canUndo =>
      !state.isLoading &&
      _lastRemoved != null &&
      _lastRemovedDeckToken == _deckGeneration;

  @override
  Future<List<AnimalImage>> build() async {
    final apiService = ref.watch(apiServiceProvider);
    // watch なので選択が変われば山札を破棄して取り直す（意図した仕様）。
    // 詳細は animalImagesProvider のドキュメントコメントを参照。
    final selectedTypes = ref.watch(selectedAnimalTypesProvider);

    // 選択が変わって build() が再実行されたら、進行中の追加読み込みは
    // 古い選択に紐づくものなので無効化する
    _loadMoreRequestId++;
    _isLoadingMore = false;
    // ここから作られるのは新しい山札。古い山札に紐づく Undo 履歴は
    // 戻す先を失うので破棄する（[canUndo] は世代不一致でも false になるが、
    // ぶら下がった参照とお気に入り取消フラグを残さないよう明示的に消す）。
    _lastRemoved = null;
    _lastRemovedDeckToken = null;
    _lastRemovedShouldUnfavorite = false;
    _deckGeneration = ++_nextDeckToken;

    if (selectedTypes.isEmpty) return const [];

    final images = await apiService.fetchImages(selectedTypes);
    if (images.isEmpty) {
      // 「取得はできたが 0 件」もエラーとして UI に出す。
      // エラー種別の細分化は #17 で行う。
      throw const EmptyResultException();
    }
    return images;
  }

  /// 画像を取得し直す（エラー画面の「もう一度試す」から呼ばれる）
  Future<void> reload() async {
    final requestedTypes = List<AnimalType>.of(
      ref.read(selectedAnimalTypesProvider),
    );
    // 追加読み込みと同じ通し番号を共有し、どちらか新しい方だけが state を書く
    final requestId = ++_loadMoreRequestId;

    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      if (requestedTypes.isEmpty) return const <AnimalImage>[];

      final apiService = ref.read(apiServiceProvider);
      final images = await apiService.fetchImages(requestedTypes);
      if (images.isEmpty) throw const EmptyResultException();
      return images;
    });

    // リトライ中に「選び直す」で選択が変わっていたら、この結果は現在の選択と
    // 無関係なので破棄する（build() が新しい選択で走り直しているため）
    if (!ref.mounted) return;
    if (requestId != _loadMoreRequestId) return;
    if (!_sameTypes(requestedTypes)) return;

    // 取り直した結果は別の山札。build() と同じ理由で Undo 履歴も破棄する
    // （世代不一致で canUndo は自然に false になるが、ぶら下がった参照と
    // お気に入り取消フラグを残さないために明示的に消す）。
    _lastRemoved = null;
    _lastRemovedDeckToken = null;
    _lastRemovedShouldUnfavorite = false;
    _deckGeneration = ++_nextDeckToken;
    state = result;
  }

  /// 追加画像を読み込む処理
  Future<void> loadMoreImages() async {
    final selectedTypes = ref.read(selectedAnimalTypesProvider);
    if (selectedTypes.isEmpty) return;
    if (_isLoadingMore) return;

    final requestedTypes = List<AnimalType>.of(selectedTypes);
    final requestId = ++_loadMoreRequestId;
    _isLoadingMore = true;

    try {
      final apiService = ref.read(apiServiceProvider);
      final moreImages = await apiService.fetchImages(requestedTypes);

      // 待っている間に選択が変わっていたら、この結果は現在の選択と無関係
      if (!ref.mounted) return;
      if (requestId != _loadMoreRequestId) return;
      if (!_sameTypes(requestedTypes)) return;
      if (moreImages.isEmpty) return;

      final current = state.value ?? const <AnimalImage>[];
      // 重複排除は「同じ画像を 2 回見せない」ためのもの。#18 で AnimalImage に
      // == を実装したが、ここは URL の Set のままにしている。
      // 全フィールド一致の == で判定すると、同じ画像でも description や source
      // といった付随情報が違うだけで別物と見なされ、重複がすり抜ける。
      // 「同じ画像か」の同一性は URL が担うため、判定軸としては URL の方が強い。
      final existingUrls = current.map((image) => image.url).toSet();
      state = AsyncValue.data([
        ...current,
        ...moreImages.where((image) => !existingUrls.contains(image.url)),
      ]);
    } catch (e, stackTrace) {
      // 追加読み込みの失敗は既に表示中の画像を壊さない。
      // 画面全体をエラーにせず、ログだけ残す。
      AppLogger.error('Error in loadMoreImages', e, stackTrace);
    } finally {
      if (requestId == _loadMoreRequestId) _isLoadingMore = false;
    }
  }

  /// リクエスト時点の選択が現在も維持されているか
  bool _sameTypes(List<AnimalType> requestedTypes) {
    final current = ref.read(selectedAnimalTypesProvider);
    if (current.length != requestedTypes.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != requestedTypes[i]) return false;
    }
    return true;
  }

  /// 一番上の画像を削除し、必要に応じて追加読み込みを実行
  ///
  /// [deckToken] にはカードを表示した時点の [deckGeneration] を渡す。
  /// スワイプアニメーション完了は 250ms 遅れて通知されるため、その間に
  /// 再取得が完了して別の山札に入れ替わっていることがある。世代が変わって
  /// いれば、その操作はもう存在しない山札に対するものなので無視する。
  ///
  /// [expectedTop] にはスワイプされたカードそのものを渡す。
  ///
  /// [deckToken] だけでは足りない。山札を 1 枚進めるだけの通常の除去では
  /// [deckGeneration] は変わらないため、アニメーション中に別の操作で
  /// 山札が進んでいても古いトークンが通ってしまい、**スワイプしていない
  /// 次のカードを黙って捨ててしまう**。先頭が期待どおりかを
  /// ここで照合することで、判定と除去を不可分にする。
  ///
  /// [undoRemovesFavorite] には、この除去が「好き」によるもので、かつ
  /// そのスワイプが実際にお気に入りを新規追加した場合に true を渡す
  /// （判定は呼び出し側の責務。理由は [_lastRemovedShouldUnfavorite] 参照）。
  ///
  /// 実際に取り除いた場合のみ true を返す。
  bool removeTopImage({
    int? deckToken,
    AnimalImage? expectedTop,
    bool undoRemovesFavorite = false,
  }) {
    // 再取得中は前回の山札が state に残っているが、それはもう表示対象ではない
    if (state.isLoading) return false;
    // 表示時と別の山札に入れ替わっているなら、この操作は古い
    if (deckToken != null && deckToken != _deckGeneration) return false;

    final current = state.value;
    if (current == null || current.isEmpty) return false;

    // identical で比較する。AnimalImage は値等価なので、API が同じ画像を
    // 返した場合に == だと別のカードを取り違える。
    if (expectedTop != null && !identical(current.first, expectedTop)) {
      return false;
    }

    final removed = current.first;
    final rest = current.sublist(1);

    // Undo 用に直前の 1 枚として記録する（同一インスタンスを保持）
    _lastRemoved = removed;
    _lastRemovedDeckToken = _deckGeneration;
    _lastRemovedShouldUnfavorite = undoRemovesFavorite;

    state = AsyncValue.data(rest);

    // 画像の残りが閾値未満の場合、追加画像を読み込む
    if (rest.length < _loadMoreThreshold) {
      loadMoreImages();
    }
    return true;
  }

  /// 直前の 1 枚を山札の先頭へ戻す（Undo, #9）。
  ///
  /// 戻すのは新しいインスタンスではなく [_lastRemoved] そのもの。
  /// `_CardStack`（swipe_screen.dart）は [ObjectKey]（identical 比較）で
  /// カードを識別しているため、値が同じでも別インスタンスのコピーを
  /// 戻すと「別のカード」として扱われ、SwipeCard 側のドラッグ状態などが
  /// 意図せずリセットされてしまう。
  ///
  /// 戻す先の山札が既に入れ替わっている場合（[canUndo] が false）は
  /// 何もせず null を返す。
  ///
  /// 成功時、その除去が「好き」由来でお気に入りの取消が必要だったかを
  /// [UndoResult] で呼び出し元に返す。favoritesProvider の更新自体は
  /// このメソッドの責務にしない（Notifier 間の直接依存を避けるため、
  /// 呼び出し元の SwipeScreen が favoritesProvider を操作する）。
  UndoResult? undo() {
    if (!canUndo) return null;

    final restored = _lastRemoved!;
    final shouldUnfavorite = _lastRemovedShouldUnfavorite;
    final current = state.value ?? const <AnimalImage>[];
    state = AsyncValue.data([restored, ...current]);

    _lastRemoved = null;
    _lastRemovedDeckToken = null;
    _lastRemovedShouldUnfavorite = false;

    return UndoResult(image: restored, shouldUnfavorite: shouldUnfavorite);
  }
}

/// [AnimalImagesNotifier.undo] が成功した際に返す結果。
///
/// お気に入りの取消は favoritesProvider の責務なので、ここでは
/// 「取り消すべきかどうか」の情報だけを運ぶ。
class UndoResult {
  final AnimalImage image;
  final bool shouldUnfavorite;

  const UndoResult({required this.image, required this.shouldUnfavorite});
}

/// 取得には成功したが 1 件も画像が得られなかったことを表す例外
class EmptyResultException implements Exception {
  const EmptyResultException();

  @override
  String toString() => 'EmptyResultException: 画像を取得できませんでした';
}
