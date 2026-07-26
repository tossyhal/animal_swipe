import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/animal_model.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';
import '../utils/logger.dart';

/// 画像取得中かどうかをUIへ通知するプロバイダー
final animalImagesLoadingProvider = StateProvider<bool>((ref) => false);

/// 初期画像の取得に失敗した場合のメッセージ
final animalImagesErrorProvider = StateProvider<String?>((ref) => null);

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
final animalImagesProvider =
    NotifierProvider<AnimalImagesNotifier, List<AnimalImage>>(
      AnimalImagesNotifier.new,
    );

/// 動物画像のリストを管理する [Notifier]
class AnimalImagesNotifier extends Notifier<List<AnimalImage>> {
  // build() は selectedAnimalTypesProvider の変化で再実行される。
  // final にすると 2 回目の代入で LateInitializationError になるため late のみ。
  late IApiService _apiService;
  late List<String> _selectedTypes;
  bool _isLoading = false;

  /// 発行したリクエストの通し番号。最後に発行したものだけが「現行」。
  /// 選択変更で build() が走ると古いリクエストが宙に浮くため、
  /// どの応答が現行かをこの番号で判定する。
  int _requestId = 0;

  /// 画像追加読み込みの閾値
  static const int _loadMoreThreshold = 3;

  @override
  List<AnimalImage> build() {
    _apiService = ref.watch(apiServiceProvider);
    _selectedTypes = ref.watch(selectedAnimalTypesProvider);

    // 依存が変わったので、進行中のリクエストがあっても新しい選択で
    // 読み込み直せるようフラグを倒す
    _isLoading = false;

    return const [];
  }

  /// [requestId] が最後に発行したリクエストか（かつ provider が生存しているか）。
  /// 古いリクエストが後から完了しても、新しいリクエストの
  /// ローディング状態を巻き戻さないために使う。
  bool _isLatestRequest(int requestId) =>
      ref.mounted && requestId == _requestId;

  /// [requestedTypes] に対する応答をいま state に反映してよいか。
  ///
  /// Riverpod は依存が変わっても次に読まれるまで build() を再実行しないため、
  /// build() 内の世代カウンタでは「選択変更後にまだ再 build されていない」区間を
  /// 検出できない。そこでリクエスト開始時の選択内容と現在の選択内容を直接比較する。
  bool _isStillRelevant(int requestId, List<String> requestedTypes) {
    if (!_isLatestRequest(requestId)) return false;
    return listEquals(requestedTypes, ref.read(selectedAnimalTypesProvider));
  }

  void _setLoading(bool value) {
    _isLoading = value;
    ref.read(animalImagesLoadingProvider.notifier).state = value;
  }

  void _setError(String? message) {
    ref.read(animalImagesErrorProvider.notifier).state = message;
  }

  /// 初期画像を読み込む処理
  Future<void> loadInitialImages() async {
    if (_selectedTypes.isEmpty) return;
    if (_isLoading) return;

    final requestedTypes = List<String>.of(_selectedTypes);
    final requestId = ++_requestId;
    try {
      _setLoading(true);
      _setError(null);
      final imagesList = await _apiService.fetchImages(requestedTypes);
      // 待っている間に選択が変わっていたら、この結果は現在の選択と無関係
      if (!_isStillRelevant(requestId, requestedTypes)) return;

      if (imagesList.isEmpty) {
        _setError('画像を取得できませんでした');
      } else if (state.isEmpty) {
        state = imagesList;
      }
    } catch (e) {
      AppLogger.error('Error in loadInitialImages', e);
      if (_isStillRelevant(requestId, requestedTypes)) {
        _setError('画像を取得できませんでした');
      }
    } finally {
      // 後発のリクエストが走っている場合、その読み込み中表示を消さない
      if (_isLatestRequest(requestId)) _setLoading(false);
    }
  }

  /// 追加画像を読み込む処理
  Future<void> loadMoreImages() async {
    if (_selectedTypes.isEmpty) return;
    if (_isLoading) return;

    final requestedTypes = List<String>.of(_selectedTypes);
    final requestId = ++_requestId;
    try {
      _setLoading(true);
      final moreImages = await _apiService.fetchImages(requestedTypes);
      if (!_isStillRelevant(requestId, requestedTypes)) return;

      if (moreImages.isNotEmpty) {
        final existingUrls = state.map((image) => image.url).toSet();
        state = [
          ...state,
          ...moreImages.where((image) => !existingUrls.contains(image.url)),
        ];
      }
    } catch (e) {
      AppLogger.error('Error in loadMoreImages', e);
    } finally {
      // 後発のリクエストが走っている場合、その読み込み中表示を消さない
      if (_isLatestRequest(requestId)) _setLoading(false);
    }
  }

  /// 一番上の画像を削除し、必要に応じて追加読み込みを実行
  void removeTopImage() {
    if (state.isNotEmpty) {
      state = state.sublist(1);
      // 画像の残りが閾値未満の場合、追加画像を読み込む
      if (state.length < _loadMoreThreshold) {
        loadMoreImages();
      }
    }
  }
}
