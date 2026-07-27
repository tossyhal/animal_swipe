import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/animal_model.dart';
import '../models/animal_type.dart';
import '../utils/logger.dart';

/// [PrefsService] を提供するプロバイダー
/// ※ProviderScopeで上書きする必要があります
final prefsServiceProvider = Provider<PrefsService>((ref) {
  throw UnimplementedError('Should be overridden in ProviderScope');
});

/// ローカルストレージ操作を担うサービスクラス
class PrefsService {
  final SharedPreferences _prefs;

  /// 選択された動物タイプを保存するためのキー
  static const String _selectedTypesKey = 'selected_animal_types';

  /// お気に入り（[AnimalImage] の JSON 配列）を保存するためのキー
  static const String _favoritesKey = 'favorite_animal_images';

  /// コンストラクタ
  PrefsService(this._prefs);

  /// 選択済みの動物タイプが存在するか確認するメソッド
  bool hasSelectedAnimalTypes() {
    final types = getSelectedAnimalTypes();
    return types.isNotEmpty;
  }

  /// ローカルストレージから選択済みの動物タイプリストを取得する
  ///
  /// 保存されているのは [AnimalType.id] の文字列。**未知の id は黙って捨てる。**
  /// 過去のバージョンで保存された、あるいは将来追加される予定の動物
  /// （例: `'bird'`）が残っていても起動に失敗させないため。
  List<AnimalType> getSelectedAnimalTypes() {
    final ids = _prefs.getStringList(_selectedTypesKey) ?? const <String>[];
    return AnimalType.fromIds(ids);
  }

  /// 指定された動物タイプリストをローカルストレージに保存する
  ///
  /// 列挙型になったため、空文字列や未知の値が入り込む余地はない。
  /// 重複だけ排除して順序は維持する。
  Future<void> saveSelectedAnimalTypes(List<AnimalType> types) async {
    final ids = <String>[];
    for (final type in types) {
      if (!ids.contains(type.id)) ids.add(type.id);
    }
    await _prefs.setStringList(_selectedTypesKey, ids);
  }

  /// テーマモードを保存するためのキー
  static const String _themeModeKey = 'theme_mode';

  /// ローカルストレージからテーマモードを取得する
  ///
  /// 保存されているのは [ThemeMode.name] の文字列。[AnimalType] と同じ方針で、
  /// 未知の値・欠損は例外にせず [ThemeMode.system] にフォールバックする。
  /// 将来 [ThemeMode] に列挙子が増減しても、保存済みデータが壊れて起動に
  /// 失敗することがないようにするため。
  ThemeMode getThemeMode() {
    final name = _prefs.getString(_themeModeKey);
    if (name == null) return ThemeMode.system;
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return ThemeMode.system;
  }

  /// 指定されたテーマモードをローカルストレージに保存する
  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeModeKey, mode.name);
  }

  /// ローカルストレージからお気に入りの動物画像リストを取得する
  ///
  /// 保存形式は [AnimalImage.toJson] の配列を JSON エンコードした文字列。
  /// **壊れたデータで起動に失敗させない。** 端末間コピーや手動編集、将来の
  /// スキーマ変更で JSON が壊れていても、読める分だけ返す。
  ///
  /// - JSON 全体が壊れている（デコードできない・配列でない）場合は空リスト。
  /// - 配列の一部の要素だけが壊れている（[AnimalImage.fromJson] が失敗する）
  ///   場合は、その要素だけを読み飛ばし、残りは復元する。
  List<AnimalImage> getFavorites() {
    final raw = _prefs.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) return const <AnimalImage>[];

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      AppLogger.warning('お気に入りの JSON が壊れています。空として扱います: $e');
      return const <AnimalImage>[];
    }

    if (decoded is! List) {
      AppLogger.warning('お気に入りのデータ形式が不正です（配列ではありません）。空として扱います');
      return const <AnimalImage>[];
    }

    final favorites = <AnimalImage>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        favorites.add(AnimalImage.fromJson(Map<String, dynamic>.from(entry)));
      } on FormatException catch (e) {
        // 1件の破損で全体を失わないよう、その要素だけ読み飛ばす
        AppLogger.warning('お気に入りの1件を読み飛ばしました: $e');
      }
    }
    return favorites;
  }

  /// お気に入りの動物画像リストをローカルストレージへ保存する
  ///
  /// 上限件数の判定・古いものの間引きは呼び出し側（[FavoritesNotifier]）の
  /// 責務とし、ここでは渡されたリストをそのまま永続化する。
  Future<void> saveFavorites(List<AnimalImage> favorites) async {
    final encoded = jsonEncode(
      favorites.map((image) => image.toJson()).toList(),
    );
    await _prefs.setString(_favoritesKey, encoded);
  }
}
