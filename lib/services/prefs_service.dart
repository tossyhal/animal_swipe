import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/animal_type.dart';

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
}
