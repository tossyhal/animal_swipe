import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal_model.dart';
import '../services/api_service.dart';
import '../services/prefs_service.dart';

/// 選択された動物タイプを管理するプロバイダー
final selectedAnimalTypesProvider =
    StateNotifierProvider<SelectedAnimalTypesNotifier, List<String>>((ref) {
      final prefsService = ref.watch(prefsServiceProvider);
      return SelectedAnimalTypesNotifier(prefsService);
    });

/// 選択された動物タイプのStateNotifier
class SelectedAnimalTypesNotifier extends StateNotifier<List<String>> {
  final PrefsService _prefsService;

  SelectedAnimalTypesNotifier(this._prefsService)
    : super(_prefsService.getSelectedAnimalTypes());

  /// 動物タイプの選択状態を更新し、ローカルに保存する
  void selectType(String type, bool isSelected) {
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
    StateNotifierProvider<AnimalImagesNotifier, List<AnimalImage>>((ref) {
      final apiService = ref.watch(apiServiceProvider);
      final selectedTypes = ref.watch(selectedAnimalTypesProvider);
      return AnimalImagesNotifier(apiService, selectedTypes);
    });

/// 動物画像のリストを管理するStateNotifier
class AnimalImagesNotifier extends StateNotifier<List<AnimalImage>> {
  final ApiService _apiService;
  final List<String> _selectedTypes;

  /// 画像追加読み込みの閾値
  static const int _loadMoreThreshold = 3;

  AnimalImagesNotifier(this._apiService, this._selectedTypes) : super([]) {
    loadInitialImages();
  }

  /// 初期画像を読み込む処理
  Future<void> loadInitialImages() async {
    if (_selectedTypes.isEmpty) return;
    final imagesList = await _apiService.fetchImages(_selectedTypes);
    state = imagesList;
  }

  /// 追加画像を読み込む処理
  Future<void> loadMoreImages() async {
    if (_selectedTypes.isEmpty) return;
    final moreImages = await _apiService.fetchImages(_selectedTypes);
    state = [...state, ...moreImages];
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
