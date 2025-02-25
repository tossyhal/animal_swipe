import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<String> getSelectedAnimalTypes() {
    return _prefs.getStringList(_selectedTypesKey) ?? [];
  }

  /// 指定された動物タイプリストをローカルストレージに保存する
  Future<void> saveSelectedAnimalTypes(List<String> types) async {
    await _prefs.setStringList(_selectedTypesKey, types);
  }
}
