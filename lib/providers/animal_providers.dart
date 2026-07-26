import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/animal_model.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../utils/logger.dart';

/// 選択された動物タイプを管理するプロバイダー
final selectedAnimalTypesProvider =
    NotifierProvider<SelectedAnimalTypesNotifier, List<String>>(
      SelectedAnimalTypesNotifier.new,
    );

/// 選択された動物タイプの [Notifier]
class SelectedAnimalTypesNotifier extends Notifier<List<String>> {
  // build() は依存の変化で再実行され、その都度この場で再代入される。
  // final にすると 2 回目の代入で LateInitializationError になるため late のみ。
  late PrefsService _prefsService;

  @override
  List<String> build() {
    _prefsService = ref.watch(prefsServiceProvider);
    return _prefsService.getSelectedAnimalTypes();
  }

  /// 動物タイプの選択状態を更新し、ローカルに保存する
  void selectType(String type, bool isSelected) {
    // 空文字列や空白文字列は無視
    if (type.trim().isEmpty) return;

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
final animalImagesProvider =
    AsyncNotifierProvider<AnimalImagesNotifier, List<AnimalImage>>(
      AnimalImagesNotifier.new,
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

  @override
  Future<List<AnimalImage>> build() async {
    final apiService = ref.watch(apiServiceProvider);
    final selectedTypes = ref.watch(selectedAnimalTypesProvider);

    // 選択が変わって build() が再実行されたら、進行中の追加読み込みは
    // 古い選択に紐づくものなので無効化する
    _loadMoreRequestId++;
    _isLoadingMore = false;

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
    final requestedTypes = List<String>.of(
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

    state = result;
  }

  /// 追加画像を読み込む処理
  Future<void> loadMoreImages() async {
    final selectedTypes = ref.read(selectedAnimalTypesProvider);
    if (selectedTypes.isEmpty) return;
    if (_isLoadingMore) return;

    final requestedTypes = List<String>.of(selectedTypes);
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
  bool _sameTypes(List<String> requestedTypes) {
    final current = ref.read(selectedAnimalTypesProvider);
    if (current.length != requestedTypes.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != requestedTypes[i]) return false;
    }
    return true;
  }

  /// 一番上の画像を削除し、必要に応じて追加読み込みを実行
  void removeTopImage() {
    final current = state.value;
    if (current == null || current.isEmpty) return;

    final rest = current.sublist(1);
    state = AsyncValue.data(rest);

    // 画像の残りが閾値未満の場合、追加画像を読み込む
    if (rest.length < _loadMoreThreshold) {
      loadMoreImages();
    }
  }
}

/// 取得には成功したが 1 件も画像が得られなかったことを表す例外
class EmptyResultException implements Exception {
  const EmptyResultException();

  @override
  String toString() => 'EmptyResultException: 画像を取得できませんでした';
}
