/// アプリ全体で使用する寸法・時間・不透明度の定数。
///
/// ここに定義するのは **実際にコードから参照されている値だけ** とする。
/// 「使うかもしれない」値を先回りして並べると、旧 `AppConstants` のように
/// 大半がデッドコードになるため。追加するときは必ず参照箇所とセットで。
library;

/// 余白（padding / gap）
///
/// 名前を値そのものにしている。このアプリにはまだ確立したスペーシング
/// スケールが無く（実際に 2〜52 の 16 種類が使われている）、
/// ここで `sm` / `md` のような t シャツ名を付けると
/// 「md が何 px か」を覚えられず誤用を招くため。
/// スケールを整理する段階になったら、この一覧がそのまま棚卸し表になる。
class AppSpacing {
  AppSpacing._();

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s36 = 36;
  static const double s44 = 44;
  static const double s52 = 52;
}

/// 角丸
///
/// こちらは値ではなく「どの部品の角丸か」で命名する。
/// 同じ値でも部品ごとに独立して変わりうるため。
class AppRadius {
  AppRadius._();

  /// カード下部の種別チップ
  static const double chip = 12;

  /// SnackBar
  static const double snackBar = 16;

  /// `ElevatedButtonTheme` の既定
  static const double elevatedButton = 16;

  /// 「はじめる」ボタン
  static const double startButton = 18;

  /// 動物の選択カード
  static const double choice = 20;

  /// `CardTheme` の既定
  static const double card = 20;

  /// 円形のアクションボタン
  static const double actionButton = 25;

  /// 読み込みエラーのパネル
  static const double loadError = 24;

  /// 開始画面の選択パネル
  static const double panel = 28;

  /// スワイプカード本体
  static const double swipeCard = 28;
}

/// アニメーション時間
class AppDuration {
  AppDuration._();

  /// 選択カードの選択状態の切り替え
  static const Duration choiceSelection = Duration(milliseconds: 220);

  /// カードの入れ替え（`AnimatedSwitcher`）
  static const Duration cardTransition = Duration(milliseconds: 250);

  /// スワイプでカードが画面外へ出る／中央へ戻る
  static const Duration cardSwipe = Duration(milliseconds: 300);

  /// 「好き」を送った通知の表示時間
  static const Duration likedSnackBar = Duration(milliseconds: 1300);
}

/// 不透明度（`withValues(alpha:)` に渡す値）
class AppOpacity {
  AppOpacity._();

  /// M3 の disabled トークン（コンテナ）
  static const double disabledContainer = 0.12;

  /// 開始画面パネルの影
  static const double panelShadow = 0.14;

  /// ブランドロゴを囲む円
  static const double brandBadge = 0.24;

  /// アクションボタンの `shadowColor`
  static const double actionButtonShadowColor = 0.3;

  /// M3 の disabled トークン（前景）
  static const double disabledContent = 0.38;

  /// 画像の上下に敷くスクリム
  static const double imageScrim = 0.4;

  /// アクションボタンの落ち影
  static const double actionButtonShadow = 0.4;

  /// スワイプ方向バッジの外周グロー
  static const double swipeBadgeGlow = 0.5;

  /// グラデーション背景の上に置く控えめな文字
  static const double onGradientMuted = 0.7;

  /// スワイプ方向バッジの塗り
  static const double swipeBadge = 0.9;

  /// グラデーション背景の上に浮かぶパネル
  static const double panel = 0.96;
}

/// その他の寸法（影の高さ・アイコン・文字・部品サイズ）
class AppSizes {
  AppSizes._();

  // ---- Elevation ----

  /// `ElevatedButtonTheme` の既定
  static const double elevationButton = 3;

  /// `CardTheme` の既定、およびアクションボタン
  static const double elevationCard = 4;

  /// スワイプカード本体
  static const double elevationSwipeCard = 5;

  // ---- Icon ----

  /// スワイプヒント
  static const double iconHint = 18;

  /// AppBar の「選び直す」
  static const double iconHomeButton = 19;

  /// 「はじめる」の矢印、「好き」通知のハート
  static const double iconInline = 20;

  /// AppBar のロゴ
  static const double iconAppBar = 21;

  /// 選択済みカードのチェック
  static const double iconCheck = 24;

  /// 円形アクションボタン
  static const double iconAction = 26;

  /// 開始画面のブランドロゴ
  static const double iconBrand = 30;

  /// スワイプ方向バッジ
  static const double iconSwipeBadge = 36;

  /// 読み込みエラーの雲アイコン
  static const double iconLoadError = 46;

  /// 画像読み込み失敗
  static const double iconImageError = 48;

  // ---- Font ----
  //
  // 本来は `TextTheme` のロール（titleLarge / bodyMedium など）を
  // 各 Text に割り当てるべきで、fontSize の直接指定自体が過渡的な状態。
  // ここでは値の散らばりを 1 箇所に集めるに留めている。

  /// 選択カードの説明文
  static const double font10 = 10;

  /// 各種ヒント文
  static const double font13 = 13;

  /// 種別チップ、`bodyMedium`
  static const double font14 = 14;

  /// タグライン、読み込み中の文言
  static const double font15 = 15;

  /// `bodyLarge`
  static const double font16 = 16;

  /// 「はじめる」
  static const double font17 = 17;

  /// 動物名、カードの説明、エラー見出し
  static const double font18 = 18;

  /// `titleLarge`、画面見出し
  static const double font22 = 22;

  /// アプリ名
  static const double font42 = 42;

  /// 動物の絵文字
  static const double font44 = 44;

  // ---- 部品サイズ ----

  /// 開始画面の横幅が狭いと判定する境界
  static const double compactWidthBreakpoint = 420;

  /// 開始画面のコンテンツ最大幅
  static const double contentMaxWidth = 560;

  /// 「はじめる」ボタンの高さ
  static const double startButtonHeight = 56;

  /// 円形アクションボタンの直径
  static const double actionButtonDiameter = 62;

  /// 読み込み中インジケータの直径
  static const double loadingIndicator = 42;

  /// 読み込み中インジケータの線の太さ
  static const double loadingIndicatorStroke = 3;

  /// 画像の上下に敷くスクリムの高さ
  static const double imageScrimHeight = 60;

  /// スワイプ方向バッジを出し始めるドラッグ量
  static const double swipeBadgeRevealDistance = 20;

  // ---- カードスタック（#6） ----
  //
  // `images.take(3)` を Stack で重ねて表示する際の、先頭より奥にある
  // カードの見た目調整。奥に行くほど小さく・下にずらして「束」に見せる。

  /// スタック 2 枚目（先頭の 1 つ奥）の縮小率
  static const double cardStackScaleSecond = 0.96;

  /// スタック 3 枚目（先頭の 2 つ奥）の縮小率
  static const double cardStackScaleThird = 0.92;

  /// スタック 2 枚目を下にずらす量
  static const double cardStackOffsetSecond = 10;

  /// スタック 3 枚目を下にずらす量
  static const double cardStackOffsetThird = 20;

  /// 画面に表示中のスタック（3 枚）よりさらに先の、明示的に
  /// `precacheImage` で先読みしておく枚数
  static const int cardStackPreloadAhead = 2;
}
