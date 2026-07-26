/// アプリ全体で使用する文字列定数
class AppStrings {
  AppStrings._();

  // App
  static const String appTitle = 'AnimalSwipe';
  static const String appName = 'Animal Swipe';

  // Start Screen
  static const String tagline = '気分のままに、かわいいをめくろう。';
  static const String selectAnimalPrompt = 'どの子に会いたい？';
  static const String selectAnimalHint = '複数選べます';
  static const String startButton = 'はじめる';
  static const String swipeHint = '左右にスワイプして楽しめます';

  // Animal Types
  static const String animalCat = 'ねこ';
  static const String animalDog = 'いぬ';
  static const String animalCatDescription = '自由気ままなねこたち';
  static const String animalDogDescription = '元気いっぱいないぬたち';
  static const String animalCatEmoji = '🐱';
  static const String animalDogEmoji = '🐶';

  // Swipe Screen
  static const String homeButton = '選び直す';
  static const String discoverTitle = '今日のかわいい';
  static const String discoverSubtitle = '右は好き、左は次へ';
  static const String loading = 'かわいい子を探しています…';
  static const String loadErrorTitle = 'うまく読み込めませんでした';
  static const String loadErrorMessage = '通信環境を確認して、もう一度お試しください。';
  static const String retry = 'もう一度試す';
  static const String skip = '次へ';
  static const String like = '好き';

  // Swipe Card
  static const String imageLoadError = '画像の読み込みに失敗しました';

  /// Hero アニメーションのタグ接頭辞（画像 ID を連結して使う）
  static const String animalImageHeroTagPrefix = 'animal_image_';

  // Snackbar Messages
  static const String liked = '「好き」を送りました';

  // Font Family
  static const String fontFamily = 'MPLUSRounded1c';
}
